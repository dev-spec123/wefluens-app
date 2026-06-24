import { StatusBar } from 'expo-status-bar';
import { Stack, useRouter, useSegments } from 'expo-router';
import React, { useEffect } from 'react';
import { ActivityIndicator, View } from 'react-native';
import { GestureHandlerRootView } from 'react-native-gesture-handler';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { AppDataProvider } from '@/context/AppDataContext';
import { AuthProvider, useAuth } from '@/context/AuthContext';
import { LanguageProvider } from '@/lib/i18n';
import { setupNotificationHandler } from '@/lib/pushService';
import { ThemeProvider, useTheme } from '@/lib/theme';

function Gate() {
  const { loading, session, mustChangePassword, passwordRecoveryActive } = useAuth();
  const segments = useSegments();
  const router = useRouter();
  const c = useTheme();

  // Surface foreground notifications as a banner (app-wide, once).
  useEffect(() => { setupNotificationHandler(); }, []);

  useEffect(() => {
    if (loading) return;
    const top = segments[0] as string | undefined;
    if (passwordRecoveryActive) {
      if (top !== 'set-password') router.replace('/set-password');
      return;
    }
    if (!session) {
      // Allow the public legal pages (Terms / Guidelines) without a session —
      // they're linked from the sign-up screen.
      if (top !== '(auth)' && top !== 'legal') router.replace('/(auth)/sign-in');
      return;
    }
    if (mustChangePassword) {
      if (top !== 'force-password') router.replace('/force-password');
      return;
    }
    if (top === '(auth)' || top === undefined) router.replace('/(tabs)');
  }, [loading, session, mustChangePassword, passwordRecoveryActive, segments, router]);

  if (loading) {
    return (
      <View style={{ flex: 1, backgroundColor: c.paper, alignItems: 'center', justifyContent: 'center' }}>
        <ActivityIndicator color={c.coral} size="large" />
      </View>
    );
  }

  return (
    <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: c.paper } }}>
      <Stack.Screen name="report" options={{ presentation: 'modal' }} />
      <Stack.Screen name="legal" options={{ presentation: 'modal' }} />
    </Stack>
  );
}

export default function RootLayout() {
  return (
    <GestureHandlerRootView style={{ flex: 1 }}>
      <SafeAreaProvider>
        <ThemeProvider>
          <LanguageProvider>
            <AuthProvider>
              <AppDataProvider>
                <StatusBar style="auto" />
                <Gate />
              </AppDataProvider>
            </AuthProvider>
          </LanguageProvider>
        </ThemeProvider>
      </SafeAreaProvider>
    </GestureHandlerRootView>
  );
}
