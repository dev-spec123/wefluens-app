/**
 * Auth — Supabase email/password, session persistence, deep-link handling for
 * password recovery / email confirmation, and the must-change-password + admin
 * profile flags. Mirrors the Swift AuthManager.
 */
import * as Linking from 'expo-linking';
import React, { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react';
import type { Session } from '@supabase/supabase-js';

import { acceptTerms, getAccountFlags, syncProfile } from '@/lib/api';
import { clearMessageCache } from '@/lib/messageCache';
import { supabase } from '@/lib/supabase';
import type { UserProfile } from '@/lib/types';

const PENDING_TERMS_KEY = 'wefluens.pendingTermsAccept';
let pendingTermsAccept = false;

interface AuthContextValue {
  loading: boolean;
  session: Session | null;
  userId: string | null;
  email: string | null;
  profile: UserProfile | null;
  isAdmin: boolean;
  mustChangePassword: boolean;
  passwordRecoveryActive: boolean;
  signIn: (email: string, password: string) => Promise<void>;
  signUp: (email: string, password: string, agreedToTerms: boolean, inviteCode: string) => Promise<{ needsConfirmation: boolean }>;
  sendPasswordReset: (email: string) => Promise<void>;
  verifyCurrentPassword: (currentPassword: string) => Promise<boolean>;
  changePassword: (newPassword: string) => Promise<void>;
  finishRecovery: (newPassword: string) => Promise<void>;
  updateRecoveredPassword: (newPassword: string) => Promise<void>;
  dismissRecovery: () => Promise<void>;
  signOut: () => Promise<void>;
  refreshProfile: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue | undefined>(undefined);

/** Extract Supabase tokens from a deep-link URL fragment or query. */
function parseTokens(url: string): { access_token?: string; refresh_token?: string; type?: string } {
  const out: Record<string, string> = {};
  const frag = url.includes('#') ? url.split('#')[1] : url.split('?')[1];
  if (!frag) return out;
  for (const pair of frag.split('&')) {
    const [k, v] = pair.split('=');
    if (k && v) out[k] = decodeURIComponent(v);
  }
  return out;
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [loading, setLoading] = useState(true);
  const [session, setSession] = useState<Session | null>(null);
  const [profile, setProfile] = useState<UserProfile | null>(null);
  const [isAdmin, setIsAdmin] = useState(false);
  const [mustChangePassword, setMustChangePassword] = useState(false);
  const [passwordRecoveryActive, setPasswordRecoveryActive] = useState(false);
  const loadedFor = useRef<string | null>(null);

  const userId = session?.user.id ?? null;
  const email = session?.user.email ?? null;

  // Load profile + flags once per signed-in user.
  const hydrate = useCallback(async (uid: string, mail: string | null) => {
    if (loadedFor.current === uid) return;
    loadedFor.current = uid;
    const p = await syncProfile(uid, mail);
    setProfile(p);
    const flags = await getAccountFlags(uid);
    setIsAdmin(flags.isAdmin);
    setMustChangePassword(flags.mustChangePassword);
    if (pendingTermsAccept) {
      pendingTermsAccept = false;
      await acceptTerms(uid).catch(() => {});
    }
  }, []);

  useEffect(() => {
    (async () => {
      const { data } = await supabase.auth.getSession();
      setSession(data.session);
      setLoading(false);
    })();

    const { data: sub } = supabase.auth.onAuthStateChange((event, sess) => {
      setSession(sess);
      if (event === 'PASSWORD_RECOVERY') setPasswordRecoveryActive(true);
      if (event === 'SIGNED_OUT') {
        loadedFor.current = null;
        setProfile(null);
        setIsAdmin(false);
        setMustChangePassword(false);
      }
    });

    // Deep links (password reset / email confirmation).
    const handleUrl = async (url: string | null) => {
      if (!url) return;
      const { access_token, refresh_token, type } = parseTokens(url);
      if (access_token && refresh_token) {
        await supabase.auth.setSession({ access_token, refresh_token });
      }
      if (type === 'recovery' || url.includes('reset-password')) setPasswordRecoveryActive(true);
    };
    Linking.getInitialURL().then(handleUrl);
    const linkSub = Linking.addEventListener('url', (e) => handleUrl(e.url));

    return () => {
      sub.subscription.unsubscribe();
      linkSub.remove();
    };
  }, []);

  useEffect(() => {
    if (userId) void hydrate(userId, email);
  }, [userId, email, hydrate]);

  const signIn = useCallback(async (e: string, password: string) => {
    const { error } = await supabase.auth.signInWithPassword({ email: e.trim(), password });
    if (error) throw error;
  }, []);

  // Invite-only signup: creates the account via the signup-with-invite edge
  // function (validates the code + creates an email-confirmed user), then signs in.
  // Never calls the public auth.signUp (disabled once invite-only is enabled).
  const signUp = useCallback(async (e: string, password: string, agreedToTerms: boolean, inviteCode: string) => {
    pendingTermsAccept = agreedToTerms;
    const { data, error } = await supabase.functions.invoke('signup-with-invite', {
      body: { email: e.trim(), password, code: inviteCode.trim() },
    });
    if (error) throw error;
    if (!data?.ok) {
      const err = new Error(data?.error ?? 'SIGNUP_FAILED') as Error & { inviteError?: string };
      err.inviteError = data?.error ?? 'SIGNUP_FAILED';
      throw err;
    }
    await signIn(e.trim(), password);
    return { needsConfirmation: false };
  }, [signIn]);

  const sendPasswordReset = useCallback(async (e: string) => {
    const redirectTo = Linking.createURL('reset-password');
    const { error } = await supabase.auth.resetPasswordForEmail(e.trim(), { redirectTo });
    if (error) throw error;
  }, []);

  // Re-authenticate the signed-in user against their current password before a
  // voluntary change. Returns false on invalid credentials; rethrows anything
  // that isn't an auth failure (network, etc.).
  const verifyCurrentPassword = useCallback(async (currentPassword: string) => {
    if (!email) return false;
    const { error } = await supabase.auth.signInWithPassword({ email, password: currentPassword });
    if (!error) return true;
    const status = (error as { status?: number }).status;
    if (status === 400 || status === 401 || /invalid login credentials/i.test(error.message)) {
      return false;
    }
    throw error;
  }, [email]);

  const changePassword = useCallback(async (newPassword: string) => {
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    if (error) throw error;
    if (userId) await supabase.from('profiles').update({ must_change_password: false }).eq('id', userId);
    setMustChangePassword(false);
  }, [userId]);

  const finishRecovery = useCallback(async (newPassword: string) => {
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    if (error) throw error;
    setPasswordRecoveryActive(false);
    await supabase.auth.signOut();
  }, []);

  // Two-step recovery (mirrors Swift): update the password but KEEP the session so
  // a success screen can show, then sign out when the user taps "Back to sign in".
  const updateRecoveredPassword = useCallback(async (newPassword: string) => {
    const { error } = await supabase.auth.updateUser({ password: newPassword });
    if (error) throw error;
  }, []);

  const dismissRecovery = useCallback(async () => {
    setPasswordRecoveryActive(false);
    await supabase.auth.signOut();
  }, []);

  const signOut = useCallback(async () => {
    await clearMessageCache();
    await supabase.auth.signOut();
  }, []);

  const refreshProfile = useCallback(async () => {
    if (!userId) return;
    loadedFor.current = null;
    await hydrate(userId, email);
  }, [userId, email, hydrate]);

  const value = useMemo<AuthContextValue>(() => ({
    loading, session, userId, email, profile, isAdmin, mustChangePassword, passwordRecoveryActive,
    signIn, signUp, sendPasswordReset, verifyCurrentPassword, changePassword, finishRecovery, updateRecoveredPassword, dismissRecovery, signOut, refreshProfile,
  }), [loading, session, userId, email, profile, isAdmin, mustChangePassword, passwordRecoveryActive,
    signIn, signUp, sendPasswordReset, verifyCurrentPassword, changePassword, finishRecovery, updateRecoveredPassword, dismissRecovery, signOut, refreshProfile]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used within an AuthProvider');
  return ctx;
}

export { PENDING_TERMS_KEY };
