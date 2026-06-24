import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  ActivityIndicator, Pressable, StyleSheet, Text, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, TagChip } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import * as api from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { avatarGradient, gradients, radius, space, useTheme } from '@/lib/theme';

/**
 * Full-screen friend-request detail — mirrors the Swift FriendRequestDetailView:
 * a large 96pt avatar with shadow, name, @handle, a role chip, the request
 * message, and Accept / Decline actions that resolve to an inline result label
 * before auto-dismissing. The request is looked up live from AppData by id so it
 * disappears once resolved.
 */
export default function FriendRequestDetail() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { friendRequests, refreshContacts } = useAppData();
  const { id } = useLocalSearchParams<{ id: string }>();

  const request = useMemo(
    () => friendRequests.find((r) => r.id === id),
    [friendRequests, id],
  );

  const [processing, setProcessing] = useState(false);
  // 'accepted' | 'declined' | null — drives the inline result label.
  const [result, setResult] = useState<null | 'accepted' | 'declined'>(null);
  const [error, setError] = useState<string | null>(null);

  async function respond(accept: boolean) {
    if (processing || !request) return;
    setProcessing(true);
    setError(null);
    try {
      await api.respondFriendRequest(request.id, accept);
      await refreshContacts();
      setResult(accept ? 'accepted' : 'declined');
      // Brief pause so the result label is visible, then return to the list.
      setTimeout(() => router.back(), 1100);
    } catch {
      setError(t('friendRequestError'));
    } finally {
      setProcessing(false);
    }
  }

  // Request already resolved / not found — fall back gracefully.
  if (!request) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
        <Pressable onPress={() => router.back()} style={[styles.backBtn, { backgroundColor: c.card, borderColor: c.hairline }]}>
          <Ionicons name="chevron-back" size={20} color={c.ink} />
        </Pressable>
        <View style={styles.center}>
          <Ionicons name="checkmark-done-outline" size={44} color={c.inkTertiary} />
          <Text style={[styles.gone, { color: c.inkSecondary }]}>{t('friendRequestGone')}</Text>
        </View>
      </SafeAreaView>
    );
  }

  const colors = request.avatarColors ?? avatarGradient(request.id);

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <Pressable onPress={() => router.back()} style={[styles.backBtn, { backgroundColor: c.card, borderColor: c.hairline }]}>
        <Ionicons name="chevron-back" size={20} color={c.ink} />
      </Pressable>

      <View style={styles.center}>
        <View style={styles.avatarShadow}>
          <Avatar colors={colors} name={request.name} size={96} />
        </View>

        <View style={{ alignItems: 'center', gap: 6, marginTop: space.xl }}>
          <Text style={[styles.name, { color: c.ink }]} numberOfLines={1}>{request.name}</Text>
          {request.handle ? (
            <Text style={[styles.handle, { color: c.inkSecondary }]} numberOfLines={1}>{request.handle}</Text>
          ) : null}
        </View>

        {request.role ? <View style={{ marginTop: space.md }}><TagChip text={request.role} filled /></View> : null}

        {request.requestMessage ? (
          <Text style={[styles.message, { color: c.inkSecondary }]}>{request.requestMessage}</Text>
        ) : null}

        {result === 'accepted' ? (
          <View style={styles.resultRow}>
            <Ionicons name="checkmark-circle" size={20} color="#2AD17E" />
            <Text style={[styles.resultText, { color: '#2AD17E' }]}>{t('friendRequestAdded')}</Text>
          </View>
        ) : result === 'declined' ? (
          <View style={styles.resultRow}>
            <Ionicons name="close-circle" size={20} color={c.inkTertiary} />
            <Text style={[styles.resultText, { color: c.inkTertiary }]}>{t('friendRequestDeclined')}</Text>
          </View>
        ) : (
          <View style={{ alignItems: 'center', gap: 12, marginTop: space.xl }}>
            <View style={styles.actions}>
              <Pressable
                onPress={() => respond(false)}
                disabled={processing}
                style={[styles.declineBtn, { borderColor: c.hairline, backgroundColor: c.card, opacity: processing ? 0.6 : 1 }]}
              >
                <Text style={[styles.declineText, { color: c.inkSecondary }]}>{t('friendRequestDecline')}</Text>
              </Pressable>
              <Pressable onPress={() => respond(true)} disabled={processing} style={{ opacity: processing ? 0.6 : 1 }}>
                <LinearGradient
                  colors={gradients.sunset}
                  start={{ x: 0, y: 0 }}
                  end={{ x: 1, y: 1 }}
                  style={styles.acceptBtn}
                >
                  <Text style={styles.acceptText}>{t('friendRequestAccept')}</Text>
                </LinearGradient>
              </Pressable>
            </View>
            {processing ? <ActivityIndicator color={c.coral} /> : null}
            {error ? <Text style={[styles.error, { color: c.danger }]}>{error}</Text> : null}
          </View>
        )}
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  backBtn: {
    position: 'absolute', top: 56, left: 16, zIndex: 1,
    width: 40, height: 40, borderRadius: 20, borderWidth: 1,
    alignItems: 'center', justifyContent: 'center',
  },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 32 },
  avatarShadow: {
    borderRadius: 48,
    shadowColor: '#000', shadowOpacity: 0.12, shadowRadius: 20, shadowOffset: { width: 0, height: 10 },
    elevation: 6,
  },
  name: { fontSize: 24, fontWeight: '700' },
  handle: { fontSize: 15, fontWeight: '500' },
  message: { fontSize: 15, textAlign: 'center', lineHeight: 22, marginTop: space.xl },
  resultRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginTop: space.xl },
  resultText: { fontSize: 16, fontWeight: '600' },
  actions: { flexDirection: 'row', gap: 16 },
  declineBtn: {
    borderRadius: radius.pill, borderWidth: 1, width: 140, paddingVertical: 14, alignItems: 'center',
  },
  declineText: { fontSize: 16, fontWeight: '600' },
  acceptBtn: { borderRadius: radius.pill, width: 140, paddingVertical: 14, alignItems: 'center' },
  acceptText: { color: '#fff', fontSize: 16, fontWeight: '600' },
  error: { fontSize: 13, fontWeight: '500', textAlign: 'center', paddingHorizontal: 24 },
  gone: { fontSize: 15, fontWeight: '500', marginTop: 12 },
});
