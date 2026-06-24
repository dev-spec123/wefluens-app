import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useRouter } from 'expo-router';
import { useMemo, useState } from 'react';
import {
  Alert, FlatList, Pressable, StyleSheet, Text, View,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Avatar, EmptyState, Field, GradientButton, NavBar } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import * as api from '@/lib/api';
import { useI18n } from '@/lib/i18n';
import { gradients, useTheme } from '@/lib/theme';
import type { Contact } from '@/lib/types';

export default function CreateGroup() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { contacts } = useAppData();

  const [groupName, setGroupName] = useState('');
  const [search, setSearch] = useState('');
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [creating, setCreating] = useState(false);

  const filtered = useMemo<Contact[]>(() => {
    const q = search.trim().toLowerCase();
    if (!q) return contacts;
    return contacts.filter(
      (c2) =>
        c2.name.toLowerCase().includes(q) ||
        c2.handle.toLowerCase().includes(q) ||
        c2.role.toLowerCase().includes(q),
    );
  }, [contacts, search]);

  function toggle(id: string) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  async function create() {
    if (selectedIds.size < 1 || creating) return;
    const ids = Array.from(selectedIds);
    const trimmed = groupName.trim();
    const finalName =
      trimmed.length > 0
        ? trimmed
        : (() => {
            const names = contacts.filter((c2) => selectedIds.has(c2.id)).map((c2) => c2.name);
            const joined = names.slice(0, 4).join(', ');
            return names.length > 4 ? joined + '…' : joined;
          })();

    setCreating(true);
    try {
      const groupId = await api.createGroup(finalName, ids);
      router.replace({
        pathname: '/group/[groupId]',
        params: {
          groupId,
          title: finalName || 'Group',
          memberCount: String(ids.length + 1),
        },
      });
    } catch {
      Alert.alert(t('createGroupError'));
      setCreating(false);
    }
  }

  const selectedCount = selectedIds.size;
  const subtitle = selectedCount > 0 ? `${selectedCount} ${t('createGroupSelected')}` : undefined;

  function renderRow({ item, index }: { item: Contact; index: number }) {
    const isSelected = selectedIds.has(item.id);
    return (
      <View>
        <Pressable
          onPress={() => toggle(item.id)}
          style={({ pressed }) => [styles.row, pressed && { opacity: 0.7 }]}
        >
          <Avatar
            colors={item.avatarColors}
            name={item.name}
            imageUrl={item.avatarUrl}
            size={48}
            online={item.isOnline}
          />
          <View style={{ flex: 1 }}>
            <Text style={[styles.rowName, { color: c.ink }]} numberOfLines={1}>
              {item.name}
            </Text>
            {item.role ? (
              <Text style={[styles.rowRole, { color: c.inkSecondary }]} numberOfLines={1}>
                {item.role}
              </Text>
            ) : null}
          </View>
          <View
            style={[
              styles.checkOuter,
              {
                borderColor: isSelected ? c.coral : c.hairline,
                backgroundColor: isSelected ? c.coral : 'transparent',
              },
            ]}
          >
            {isSelected ? <Ionicons name="checkmark" size={13} color="#fff" /> : null}
          </View>
        </Pressable>
        {index < filtered.length - 1 ? (
          <View style={[styles.divider, { backgroundColor: c.hairline }]} />
        ) : null}
      </View>
    );
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('createGroupTitle')} subtitle={subtitle} onBack={() => router.back()} />

      {contacts.length === 0 ? (
        <EmptyState icon="people-outline" title={t('createGroupNoFriends')} />
      ) : (
        <>
          <FlatList
            data={filtered}
            keyExtractor={(item) => item.id}
            renderItem={renderRow}
            keyboardShouldPersistTaps="handled"
            ListHeaderComponent={
              <View style={styles.header}>
                <View style={styles.nameRow}>
                  <LinearGradient
                    colors={gradients.sunset}
                    start={{ x: 0, y: 0 }}
                    end={{ x: 1, y: 1 }}
                    style={styles.nameIcon}
                  >
                    <Ionicons name="people" size={18} color="#fff" />
                  </LinearGradient>
                  <View style={{ flex: 1 }}>
                    <Field
                      placeholder={t('createGroupNamePlaceholder')}
                      value={groupName}
                      onChangeText={setGroupName}
                      returnKeyType="done"
                    />
                  </View>
                </View>
                <View style={{ marginTop: 12 }}>
                  <Field
                    icon="search"
                    placeholder={t('createGroupSearch')}
                    value={search}
                    onChangeText={setSearch}
                    autoCapitalize="none"
                    autoCorrect={false}
                  />
                </View>
              </View>
            }
            contentContainerStyle={{ paddingBottom: 24 }}
          />
          <View style={[styles.footer, { borderTopColor: c.hairline, backgroundColor: c.paper }]}>
            <GradientButton
              title={t('createGroupCreate')}
              onPress={create}
              loading={creating}
              disabled={selectedCount < 1}
            />
          </View>
        </>
      )}
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  header: { paddingHorizontal: 16, paddingTop: 14, paddingBottom: 6 },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: 12 },
  nameIcon: {
    width: 38, height: 38, borderRadius: 11, alignItems: 'center', justifyContent: 'center',
  },
  row: {
    flexDirection: 'row', alignItems: 'center', gap: 14,
    paddingHorizontal: 16, paddingVertical: 10,
  },
  rowName: { fontSize: 16, fontWeight: '600' },
  rowRole: { fontSize: 13, marginTop: 3 },
  checkOuter: {
    width: 24, height: 24, borderRadius: 12, borderWidth: 2,
    alignItems: 'center', justifyContent: 'center',
  },
  divider: { height: StyleSheet.hairlineWidth, marginLeft: 76 },
  footer: { paddingHorizontal: 16, paddingTop: 12, paddingBottom: 8, borderTopWidth: StyleSheet.hairlineWidth },
});
