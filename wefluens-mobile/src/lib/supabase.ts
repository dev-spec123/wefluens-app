/**
 * Supabase client — the SAME backend the native Swift app uses.
 * Reuses email/password auth with the session persisted in AsyncStorage.
 *
 * Credentials come from Expo public env vars (set them in .env.local):
 *   EXPO_PUBLIC_SUPABASE_URL=...
 *   EXPO_PUBLIC_SUPABASE_ANON_KEY=...
 * (Same variable names the Swift app used, so you can copy the values over.)
 */
import 'react-native-url-polyfill/auto';
import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient } from '@supabase/supabase-js';

// The project URL + anon key are PUBLIC (the anon key is meant to ship in the
// client and is already committed in eas.json). Hardcoding them as the fallback
// means the app always connects — even on OTA updates, which don't inline the
// build profile's env vars (that was the "placeholder.supabase.co" login bug).
// An env var, when present, still overrides.
const DEFAULT_SUPABASE_URL = 'https://zlyufsfbzssjseprkuvd.supabase.co';
const DEFAULT_SUPABASE_ANON_KEY =
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpseXVmc2ZienNzanNlcHJrdXZkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE3Mjg3MzAsImV4cCI6MjA5NzMwNDczMH0.H1wCxe01gaUJVLRCoPNAZgnHefUTbaOojRDknUe-9RM';

const supabaseUrl = process.env.EXPO_PUBLIC_SUPABASE_URL || DEFAULT_SUPABASE_URL;
const supabaseAnonKey = process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY || DEFAULT_SUPABASE_ANON_KEY;

export const supabase = createClient(
  supabaseUrl,
  supabaseAnonKey,
  {
    auth: {
      storage: AsyncStorage,
      autoRefreshToken: true,
      persistSession: true,
      // No URL-based session detection on native (we handle deep links ourselves).
      detectSessionInUrl: false,
    },
  },
);

/** Always configured now that real defaults are baked in. */
export const hasSupabaseConfig = true;
