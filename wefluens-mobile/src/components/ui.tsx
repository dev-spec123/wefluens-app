/**
 * Shared UI building blocks — Avatar, gradient button, card, nav bar, chips,
 * fields. Ported from the Swift Components.swift, built on the theme tokens.
 */
import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import { LinearGradient } from 'expo-linear-gradient';
import React from 'react';
import {
  ActivityIndicator, Pressable, StyleProp, StyleSheet, Text, TextInput, TextInputProps,
  TextStyle, View, ViewStyle,
} from 'react-native';
import { gradients, initials as toInitials, radius, useTheme } from '@/lib/theme';

// ─────────────────────────── Avatar ───────────────────────────

export function Avatar({
  colors, name, imageUrl, size = 52, online = false, symbol,
}: {
  colors: [string, string];
  name?: string;
  imageUrl?: string | null;
  size?: number;
  online?: boolean;
  symbol?: keyof typeof Ionicons.glyphMap;
}) {
  const c = useTheme();
  const ring = size * 0.28;
  return (
    <View style={{ width: size, height: size }}>
      {imageUrl ? (
        <Image source={{ uri: imageUrl }} style={{ width: size, height: size, borderRadius: size / 2 }} contentFit="cover" />
      ) : (
        <LinearGradient
          colors={colors}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={{ width: size, height: size, borderRadius: size / 2, alignItems: 'center', justifyContent: 'center' }}
        >
          {symbol ? (
            <Ionicons name={symbol} size={size * 0.5} color="#fff" />
          ) : (
            <Text style={{ color: '#fff', fontSize: size * 0.38, fontWeight: '700' }}>
              {name ? toInitials(name) : '?'}
            </Text>
          )}
        </LinearGradient>
      )}
      {online && (
        <View
          style={{
            position: 'absolute', right: 0, bottom: 0, width: ring, height: ring, borderRadius: ring / 2,
            backgroundColor: '#2AD17E', borderWidth: 2, borderColor: c.paper,
          }}
        />
      )}
    </View>
  );
}

// ─────────────────────────── Buttons ───────────────────────────

export function GradientButton({
  title, onPress, loading, disabled, style,
}: {
  title: string; onPress: () => void; loading?: boolean; disabled?: boolean; style?: StyleProp<ViewStyle>;
}) {
  const c = useTheme();
  const off = disabled || loading;
  return (
    <Pressable onPress={onPress} disabled={off} style={style}>
      <LinearGradient
        colors={off ? [c.inkTertiary, c.inkTertiary] : gradients.sunset}
        start={{ x: 0, y: 0 }}
        end={{ x: 1, y: 1 }}
        style={styles.gradientBtn}
      >
        {loading ? <ActivityIndicator color="#fff" /> : <Text style={styles.gradientBtnText}>{title}</Text>}
      </LinearGradient>
    </Pressable>
  );
}

export function SecondaryButton({
  title, onPress, color, style,
}: {
  title: string; onPress: () => void; color?: string; style?: StyleProp<ViewStyle>;
}) {
  const c = useTheme();
  const tint = color ?? c.coral;
  return (
    <Pressable onPress={onPress} style={[styles.secondaryBtn, { backgroundColor: tint + '1F' }, style]}>
      <Text style={[styles.secondaryBtnText, { color: tint }]}>{title}</Text>
    </Pressable>
  );
}

// ─────────────────────────── Card ───────────────────────────

export function Card({ children, style }: { children: React.ReactNode; style?: StyleProp<ViewStyle> }) {
  const c = useTheme();
  return (
    <View style={[styles.card, { backgroundColor: c.card, borderColor: c.hairline }, style]}>{children}</View>
  );
}

// ─────────────────────────── Nav bar ───────────────────────────

export function NavBar({
  title, onBack, right, subtitle, backIcon = 'chevron-back', onTitlePress,
}: {
  title: string; onBack?: () => void; right?: React.ReactNode; subtitle?: string;
  backIcon?: React.ComponentProps<typeof Ionicons>['name'];
  onTitlePress?: () => void;
}) {
  const c = useTheme();
  const titleBlock = (
    <>
      <Text style={[styles.navTitle, { color: c.ink }]} numberOfLines={1}>{title}</Text>
      {subtitle ? <Text style={[styles.navSubtitle, { color: c.inkSecondary }]} numberOfLines={1}>{subtitle}</Text> : null}
    </>
  );
  return (
    <View style={[styles.navbar, { backgroundColor: c.paper }]}>
      {onBack ? (
        <Pressable onPress={onBack} style={[styles.iconBtn, { backgroundColor: c.card, borderColor: c.hairline }]}>
          <Ionicons name={backIcon} size={20} color={c.ink} />
        </Pressable>
      ) : (
        <View style={{ width: 40 }} />
      )}
      {onTitlePress ? (
        <Pressable onPress={onTitlePress} style={{ flex: 1, alignItems: 'center' }}>
          {titleBlock}
        </Pressable>
      ) : (
        <View style={{ flex: 1, alignItems: 'center' }}>
          {titleBlock}
        </View>
      )}
      <View style={{ minWidth: 40, alignItems: 'flex-end' }}>{right ?? <View style={{ width: 40 }} />}</View>
    </View>
  );
}

export function RoundIconButton({
  icon, onPress, color,
}: { icon: keyof typeof Ionicons.glyphMap; onPress: () => void; color?: string }) {
  const c = useTheme();
  return (
    <Pressable onPress={onPress} style={[styles.iconBtn, { backgroundColor: c.card, borderColor: c.hairline }]}>
      <Ionicons name={icon} size={18} color={color ?? c.coral} />
    </Pressable>
  );
}

// ─────────────────────────── Chips + fields ───────────────────────────

export function TagChip({ text, filled }: { text: string; filled?: boolean }) {
  const c = useTheme();
  return (
    <View style={[styles.chip, { backgroundColor: filled ? c.coral : c.cardSubtle }]}>
      <Text style={{ color: filled ? '#fff' : c.inkSecondary, fontSize: 12, fontWeight: '600' }}>{text}</Text>
    </View>
  );
}

export function Field(props: TextInputProps & { icon?: keyof typeof Ionicons.glyphMap }) {
  const c = useTheme();
  const { icon, style, ...rest } = props;
  return (
    <View style={[styles.field, { backgroundColor: c.card, borderColor: c.hairline }]}>
      {icon ? <Ionicons name={icon} size={16} color={c.inkSecondary} style={{ marginRight: 8 }} /> : null}
      <TextInput
        placeholderTextColor={c.inkTertiary}
        style={[{ flex: 1, fontSize: 16, color: c.ink }, style as StyleProp<TextStyle>]}
        {...rest}
      />
    </View>
  );
}

// ─────────────────────────── Misc ───────────────────────────

export function EmptyState({ icon, title, subtitle }: { icon: keyof typeof Ionicons.glyphMap; title: string; subtitle?: string }) {
  const c = useTheme();
  return (
    <View style={styles.empty}>
      <Ionicons name={icon} size={44} color={c.inkTertiary} />
      <Text style={{ color: c.ink, fontSize: 17, fontWeight: '600', marginTop: 12 }}>{title}</Text>
      {subtitle ? (
        <Text style={{ color: c.inkSecondary, fontSize: 14, textAlign: 'center', marginTop: 6, paddingHorizontal: 40 }}>{subtitle}</Text>
      ) : null}
    </View>
  );
}

export function Divider({ inset = 0 }: { inset?: number }) {
  const c = useTheme();
  return <View style={{ height: StyleSheet.hairlineWidth, backgroundColor: c.hairline, marginLeft: inset }} />;
}

const styles = StyleSheet.create({
  gradientBtn: { borderRadius: radius.md, paddingVertical: 15, paddingHorizontal: 28, alignItems: 'center', justifyContent: 'center' },
  gradientBtnText: { color: '#fff', fontSize: 17, fontWeight: '600' },
  secondaryBtn: { borderRadius: radius.pill, paddingVertical: 8, paddingHorizontal: 14, alignItems: 'center' },
  secondaryBtnText: { fontSize: 14, fontWeight: '600' },
  card: { borderRadius: radius.card, borderWidth: 1 },
  navbar: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 16, paddingBottom: 12, gap: 12 },
  iconBtn: { width: 40, height: 40, borderRadius: 20, borderWidth: 1, alignItems: 'center', justifyContent: 'center' },
  navTitle: { fontSize: 16, fontWeight: '600' },
  navSubtitle: { fontSize: 12, fontWeight: '500', marginTop: 1 },
  chip: { borderRadius: radius.pill, paddingHorizontal: 12, paddingVertical: 6, alignSelf: 'flex-start' },
  field: { flexDirection: 'row', alignItems: 'center', borderRadius: radius.md, borderWidth: 1, paddingHorizontal: 14, paddingVertical: 12 },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
});
