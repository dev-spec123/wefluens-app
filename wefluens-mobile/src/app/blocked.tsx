import { useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Alert, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, Card, Divider, EmptyState, NavBar, SecondaryButton } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import { useAuth } from '@/context/AuthContext';
import * as api from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { useTheme } from '@/lib/theme';
import type { Contact } from '@/lib/types';

export default function Blocked() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { userId } = useAuth();
  const { unblock } = useAppData();

  const [blocked, setBlocked] = useState<Contact[]>([]);
  const [loading, setLoading] = useState(true);
  const [unblocking, setUnblocking] = useState<Set<string>>(new Set());

  useEffect(() => {
    let active = true;
    (async () => {
      if (!userId) {
        if (active) setLoading(false);
        return;
      }
      setLoading(true);
      try {
        const list = await api.loadBlockedContacts(userId);
        if (active) setBlocked(list);
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => {
      active = false;
    };
  }, [userId]);

  async function onUnblock(contact: Contact) {
    if (unblocking.has(contact.id)) return;
    setUnblocking((prev) => new Set(prev).add(contact.id));
    try {
      await unblock(contact.id);
      setBlocked((prev) => prev.filter((b) => b.id !== contact.id));
    } catch {
      Alert.alert(t('blockError'));
    } finally {
      setUnblocking((prev) => {
        const next = new Set(prev);
        next.delete(contact.id);
        return next;
      });
    }
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('privacyBlockedAccounts')} onBack={() => router.back()} />

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator color={c.coral} />
        </View>
      ) : blocked.length === 0 ? (
        <EmptyState
          icon="shield-checkmark"
          title={t('blockedEmptyTitle')}
          subtitle={t('blockedEmptySub')}
        />
      ) : (
        <ScrollView contentContainerStyle={{ paddingHorizontal: 18, paddingTop: 14, paddingBottom: 30 }}>
          <Card>
            {blocked.map((contact, i) => (
              <View key={contact.id}>
                <View style={styles.row}>
                  <Avatar
                    colors={contact.avatarColors}
                    name={contact.name}
                    imageUrl={contact.avatarUrl}
                    size={44}
                  />
                  <View style={{ flex: 1, marginLeft: 12 }}>
                    <Text style={[styles.name, { color: c.ink }]} numberOfLines={1}>
                      {contact.name}
                    </Text>
                    {contact.handle ? (
                      <Text style={[styles.handle, { color: c.inkSecondary }]} numberOfLines={1}>
                        {contact.handle}
                      </Text>
                    ) : null}
                  </View>
                  {unblocking.has(contact.id) ? (
                    <ActivityIndicator color={c.coral} style={{ paddingHorizontal: 14 }} />
                  ) : (
                    <SecondaryButton title={t('unblockAction')} onPress={() => onUnblock(contact)} />
                  )}
                </View>
                {i < blocked.length - 1 && <Divider inset={70} />}
              </View>
            ))}
          </Card>
        </ScrollView>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  row: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 10 },
  name: { fontSize: 15, fontWeight: '600' },
  handle: { fontSize: 13, marginTop: 2 },
});
