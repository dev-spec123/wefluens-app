/**
 * Design system — ported 1:1 from the native Swift app's Theme.swift.
 * Light + dark palettes, brand colors, gradients, spacing tokens, and a
 * theme-mode provider (System / Light / Dark, persisted on-device).
 */
import AsyncStorage from '@react-native-async-storage/async-storage';
import React, { createContext, useContext, useEffect, useState } from 'react';
import { useColorScheme } from 'react-native';

export type Scheme = 'light' | 'dark';
export type ThemeMode = 'system' | 'light' | 'dark';

/** Brand colors — identical in light and dark mode. */
export const palette = {
  plum: '#3A1B4A',
  coral: '#FF4D6D',
  tangerine: '#FF9A5A',
  coralDark: '#FF6B82',
  danger: '#E5484D',
  white: '#FFFFFF',
};

/**
 * Gradient color stops (start top-leading → end bottom-trailing in the Swift app).
 * Use with expo-linear-gradient: <LinearGradient colors={gradients.sunset} start={{x:0,y:0}} end={{x:1,y:1}} />
 */
export const gradients = {
  sunset: ['#FF4D6D', '#FF9A5A'] as [string, string],
  sunsetDark: ['#FF6B82', '#FF9A5A'] as [string, string],
  dusk: ['#3A1B4A', '#FF4D6D'] as [string, string],
  warmGlow: ['rgba(255,154,90,0.9)', 'rgba(255,77,109,0.9)'] as [string, string],
};

const lightSurfaces = {
  paper: '#F7F3EE',
  card: '#FFFFFF',
  cardSubtle: '#FBF8F4',
  ink: '#1C141A',
  inkSecondary: '#8B8189',
  inkTertiary: '#B6ADB3',
  hairline: 'rgba(0,0,0,0.06)',
};

const darkSurfaces = {
  paper: '#0F0C0E',
  card: '#1C181B',
  cardSubtle: '#252023',
  ink: '#F0EBED',
  inkSecondary: '#9D95A0',
  inkTertiary: '#605A63',
  hairline: 'rgba(255,255,255,0.08)',
};

export type ThemeColors = typeof lightSurfaces & typeof palette & { scheme: Scheme };

/** Resolve the full color set for a given scheme. */
export function colorsFor(scheme: Scheme): ThemeColors {
  return { ...(scheme === 'dark' ? darkSurfaces : lightSurfaces), ...palette, scheme };
}

// ─────────────────────────── Theme mode provider ───────────────────────────

const THEME_KEY = 'wefluens.theme';

interface ThemeCtxValue {
  scheme: Scheme;
  mode: ThemeMode;
  setMode: (m: ThemeMode) => void;
}

const ThemeContext = createContext<ThemeCtxValue | undefined>(undefined);

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const system = (useColorScheme() ?? 'light') as Scheme;
  const [mode, setModeState] = useState<ThemeMode>('system');

  useEffect(() => {
    AsyncStorage.getItem(THEME_KEY).then((v) => {
      if (v === 'light' || v === 'dark' || v === 'system') setModeState(v);
    });
  }, []);

  const setMode = (m: ThemeMode) => {
    setModeState(m);
    AsyncStorage.setItem(THEME_KEY, m).catch(() => {});
  };

  const scheme: Scheme = mode === 'system' ? system : mode;
  return <ThemeContext.Provider value={{ scheme, mode, setMode }}>{children}</ThemeContext.Provider>;
}

/** Hook: the resolved theme colors for the active mode (System / Light / Dark). */
export function useTheme(): ThemeColors {
  const ctx = useContext(ThemeContext);
  const system = (useColorScheme() ?? 'light') as Scheme;
  return colorsFor(ctx ? ctx.scheme : system);
}

/** Hook: the current theme mode + a setter (for the Settings picker). */
export function useThemeMode(): { mode: ThemeMode; setMode: (m: ThemeMode) => void } {
  const ctx = useContext(ThemeContext);
  return { mode: ctx?.mode ?? 'system', setMode: ctx?.setMode ?? (() => {}) };
}

/** Corner radii used across the app. */
export const radius = { sm: 12, md: 14, lg: 20, card: 22, pill: 999 };

/** Spacing scale. */
export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 18, xxl: 24 };

/**
 * Deterministic two-color avatar gradient chosen by user id — mirrors
 * AppDataService.avatarPalette so a person keeps a consistent look across clients.
 */
const AVATAR_PALETTES: [string, string][] = [
  ['#FF4D6D', '#FF9A5A'],
  ['#7B2FF7', '#F107A3'],
  ['#2AF598', '#009EFD'],
  ['#FFB75E', '#ED8F03'],
  ['#6C5CE7', '#A29BFE'],
  ['#00C6FB', '#005BEA'],
  ['#F953C6', '#B91D73'],
  ['#11998E', '#38EF7D'],
];

/** Stable gradient for a user id (sums a few uuid bytes, same logic as Swift). */
export function avatarGradient(id: string): [string, string] {
  const hex = id.replace(/-/g, '');
  const byte = (i: number) => parseInt(hex.slice(i * 2, i * 2 + 2) || '0', 16) || 0;
  const sum = byte(0) + byte(5) + byte(7) + byte(15);
  return AVATAR_PALETTES[sum % AVATAR_PALETTES.length];
}

/** Two-letter initials from a display name (mirrors AppDataService.initials). */
export function initials(name: string): string {
  const parts = name.trim().split(/\s+/).filter(Boolean);
  const first = parts[0]?.[0] ?? '';
  const last = parts.length > 1 ? parts[parts.length - 1][0] : '';
  const result = (first + last).toUpperCase();
  return result || '?';
}
