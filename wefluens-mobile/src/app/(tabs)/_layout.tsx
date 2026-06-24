import { Ionicons } from '@expo/vector-icons';
import { Tabs } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { useAppData } from '@/context/AppDataContext';
import { useI18n } from '@/lib/i18n';
import { useTheme } from '@/lib/theme';

type TabBarProps = {
  state: { index: number; routes: { key: string; name: string }[] };
  navigation: {
    emit: (e: { type: 'tabPress'; target: string; canPreventDefault: boolean }) => { defaultPrevented: boolean };
    navigate: (name: string) => void;
  };
};

/** Floating pill tab bar with a sliding selected-capsule (the iOS-style feel). */
function FloatingTabBar({ state, navigation }: TabBarProps) {
  const c = useTheme();
  const { t } = useI18n();
  const { unreadTotal } = useAppData();
  const insets = useSafeAreaInsets();
  const [barW, setBarW] = useState(0);

  const TABS = [
    { name: 'index', label: t('tabChats'), icon: 'chatbubbles' as const, badge: unreadTotal },
    { name: 'contacts', label: t('tabContacts'), icon: 'people' as const, badge: 0 },
    { name: 'discover', label: t('tabDiscover'), icon: 'sparkles' as const, badge: 0 },
    { name: 'me', label: t('tabMe'), icon: 'person-circle' as const, badge: 0 },
  ];

  const tabW = barW > 0 ? barW / TABS.length : 0;
  const tx = useSharedValue(0);
  useEffect(() => {
    if (tabW > 0) tx.value = withTiming(state.index * tabW, { duration: 240 });
  }, [state.index, tabW, tx]);
  const capsuleStyle = useAnimatedStyle(() => ({ transform: [{ translateX: tx.value }] }));

  return (
    <View style={[styles.wrap, { backgroundColor: c.paper, paddingBottom: Math.max(insets.bottom, 8) }]}>
      <View
        style={[styles.bar, { backgroundColor: c.card, borderColor: c.hairline }]}
        onLayout={(e) => setBarW(e.nativeEvent.layout.width)}
      >
        {tabW > 0 ? (
          <Animated.View
            style={[styles.capsule, { width: tabW - 12, backgroundColor: c.coral + '14' }, capsuleStyle]}
          />
        ) : null}

        {TABS.map((tab, i) => {
          const focused = state.index === i;
          const color = focused ? c.coral : c.inkSecondary;
          const route = state.routes[i];
          return (
            <Pressable
              key={tab.name}
              style={styles.tab}
              onPress={() => {
                const event = navigation.emit({ type: 'tabPress', target: route.key, canPreventDefault: true });
                if (!focused && !event.defaultPrevented) navigation.navigate(route.name);
              }}
            >
              <View>
                <Ionicons name={tab.icon} size={23} color={color} />
                {tab.badge > 0 ? (
                  <View style={[styles.badge, { backgroundColor: c.danger }]}>
                    <Text style={styles.badgeText}>{tab.badge > 99 ? '99+' : tab.badge}</Text>
                  </View>
                ) : null}
              </View>
              <Text style={[styles.label, { color, fontWeight: focused ? '700' : '500' }]} numberOfLines={1}>
                {tab.label}
              </Text>
            </Pressable>
          );
        })}
      </View>
    </View>
  );
}

export default function TabsLayout() {
  return (
    <Tabs
      tabBar={(props) => <FloatingTabBar {...(props as unknown as TabBarProps)} />}
      screenOptions={{ headerShown: false }}
    >
      <Tabs.Screen name="index" />
      <Tabs.Screen name="contacts" />
      <Tabs.Screen name="discover" />
      <Tabs.Screen name="me" />
    </Tabs>
  );
}

const styles = StyleSheet.create({
  wrap: { paddingHorizontal: 16, paddingTop: 6 },
  bar: {
    flexDirection: 'row', alignItems: 'center', borderRadius: 26, borderWidth: 1, paddingVertical: 8,
    shadowColor: '#000', shadowOpacity: 0.1, shadowRadius: 14, shadowOffset: { width: 0, height: 6 }, elevation: 8,
  },
  capsule: { position: 'absolute', top: 6, bottom: 6, left: 6, borderRadius: 20 },
  tab: { flex: 1, alignItems: 'center', justifyContent: 'center', paddingVertical: 4, gap: 2 },
  label: { fontSize: 11, marginTop: 2 },
  badge: {
    position: 'absolute', top: -5, right: -9, minWidth: 16, height: 16, borderRadius: 8,
    paddingHorizontal: 4, alignItems: 'center', justifyContent: 'center',
  },
  badgeText: { color: '#fff', fontSize: 10, fontWeight: '700' },
});
