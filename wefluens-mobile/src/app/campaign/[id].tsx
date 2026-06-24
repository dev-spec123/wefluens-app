import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import { useLocalSearchParams, useRouter } from 'expo-router';
import { useEffect, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Card, EmptyState, GradientButton, TagChip } from '@/components/ui';
import { useAppData } from '@/context/AppDataContext';
import { isCampaignApplied, setCampaignApplied } from '@/lib/campaignApplications';
import { confirmAsync } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';
import type { Campaign } from '@/lib/types';

const DELIVERABLES = [
  '2x Instagram Reels',
  '3x Story frames with link',
  '1x Usage rights for 30 days',
];

export default function CampaignDetail() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();
  const { campaigns } = useAppData();
  const { id } = useLocalSearchParams<{ id: string }>();

  const campaign: Campaign | undefined = campaigns.find((x) => x.id === id);

  const [applied, setApplied] = useState(false);

  // Restore the persisted "applied" state for this campaign.
  useEffect(() => {
    let active = true;
    if (id) isCampaignApplied(id).then((v) => { if (active) setApplied(v); }).catch(() => {});
    return () => { active = false; };
  }, [id]);

  if (!campaign) {
    return (
      <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
        <Pressable onPress={() => router.back()} style={[styles.backBtn, { top: 8, left: 18, backgroundColor: 'rgba(0,0,0,0.25)' }]}>
          <Ionicons name="chevron-back" size={20} color="#fff" />
        </Pressable>
        <EmptyState icon="briefcase-outline" title="Campaign not found" />
      </SafeAreaView>
    );
  }

  function apply() {
    setApplied(true);
    if (id) void setCampaignApplied(id, true);
  }

  async function cancelApplication() {
    const ok = await confirmAsync(t('campaignCancelApplication'), t('campaignCancelConfirm'), {
      confirmLabel: t('campaignCancelApplication'), cancelLabel: t('authCancel'), destructive: true,
    });
    if (!ok) return;
    setApplied(false);
    if (id) void setCampaignApplied(id, false);
  }

  return (
    <View style={{ flex: 1, backgroundColor: c.paper }}>
      <ScrollView contentContainerStyle={{ paddingBottom: 40 }} showsVerticalScrollIndicator={false}>
        {/* Hero */}
        <LinearGradient
          colors={campaign.colors}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
          style={styles.hero}
        >
          <Ionicons name={iconFor(campaign.symbol)} size={120} color="rgba(255,255,255,0.15)" style={styles.heroIcon} />
          <SafeAreaView edges={['top']} style={styles.heroContent}>
            <View>
              <Text style={styles.heroBrand}>{campaign.brand.toUpperCase()}</Text>
              <Text style={styles.heroTitle}>{campaign.title}</Text>
            </View>
          </SafeAreaView>
        </LinearGradient>

        {/* Quick stats */}
        <View style={styles.statsRow}>
          <Stat icon="cash-outline" value={campaign.budget} label={t('campaignDetailBudget')} />
          <Stat icon="calendar-outline" value={campaign.deadline} label={t('campaignDetailDeadline')} />
          <Stat icon="people-outline" value={String(campaign.spotsLeft)} label={t('campaignDetailSpots')} />
        </View>

        {/* About */}
        <Card style={styles.sectionCard}>
          <Text style={[styles.sectionTitle, { color: c.ink }]}>{t('campaignDetailAbout')}</Text>
          <Text style={[styles.aboutText, { color: c.inkSecondary }]}>
            {`${campaign.brand} is looking for authentic creators to bring ${campaign.title} to life. We're seeking on-brand storytelling that resonates with engaged audiences and drives measurable impact across social.`}
          </Text>
          <View style={styles.tagsRow}>
            {campaign.tags.map((tag) => (
              <TagChip key={tag} text={tag} />
            ))}
          </View>
        </Card>

        {/* Deliverables */}
        <Card style={styles.sectionCard}>
          <Text style={[styles.sectionTitle, { color: c.ink }]}>Deliverables</Text>
          {DELIVERABLES.map((d) => (
            <View key={d} style={styles.deliverableRow}>
              <Ionicons name="checkmark-circle" size={18} color={c.coral} />
              <Text style={[styles.deliverableText, { color: c.ink }]}>{d}</Text>
            </View>
          ))}
        </Card>
      </ScrollView>

      {/* Apply bar */}
      <SafeAreaView edges={['bottom']} style={[styles.applyBar, { backgroundColor: c.card, borderTopColor: c.hairline }]}>
        <View style={styles.applyBarInner}>
          <View style={{ flex: 1 }}>
            <Text style={[styles.payoutValue, { color: c.ink }]}>{campaign.budget}</Text>
            <Text style={[styles.payoutLabel, { color: c.inkSecondary }]}>Estimated payout</Text>
          </View>
          {applied ? (
            <Pressable
              onPress={cancelApplication}
              style={[styles.appliedBtn, { borderColor: c.coral, backgroundColor: c.coral + '14' }]}
            >
              <Ionicons name="checkmark-circle" size={18} color={c.coral} />
              <Text style={[styles.appliedText, { color: c.coral }]} numberOfLines={1}>
                {t('campaignDetailApplied')}
              </Text>
            </Pressable>
          ) : (
            <GradientButton
              title={t('campaignDetailApply')}
              onPress={apply}
              style={styles.applyButton}
            />
          )}
        </View>
      </SafeAreaView>

      {/* Back button */}
      <SafeAreaView edges={['top']} style={styles.backWrap} pointerEvents="box-none">
        <Pressable onPress={() => router.back()} style={[styles.backBtn, { backgroundColor: 'rgba(0,0,0,0.25)' }]}>
          <Ionicons name="chevron-back" size={20} color="#fff" />
        </Pressable>
      </SafeAreaView>
    </View>
  );
}

function Stat({ icon, value, label }: { icon: keyof typeof Ionicons.glyphMap; value: string; label: string }) {
  const c = useTheme();
  return (
    <View style={[styles.statCard, { backgroundColor: c.card, borderColor: c.hairline }]}>
      <Ionicons name={icon} size={18} color={c.coral} />
      <Text style={[styles.statValue, { color: c.ink }]} numberOfLines={1} adjustsFontSizeToFit minimumFontScale={0.7}>
        {value}
      </Text>
      <Text style={[styles.statLabel, { color: c.inkSecondary }]} numberOfLines={1}>{label}</Text>
    </View>
  );
}

/** Map an SF Symbol-ish name from the backend to an Ionicons glyph. */
function iconFor(symbol: string): keyof typeof Ionicons.glyphMap {
  const map: Record<string, keyof typeof Ionicons.glyphMap> = {
    'megaphone.fill': 'megaphone',
    megaphone: 'megaphone',
    sparkles: 'sparkles',
    'flame.fill': 'flame',
    flame: 'flame',
    'cart.fill': 'cart',
    cart: 'cart',
    'bag.fill': 'bag',
    bag: 'bag',
    'star.fill': 'star',
    star: 'star',
    'camera.fill': 'camera',
    camera: 'camera',
    'gift.fill': 'gift',
    gift: 'gift',
  };
  return map[symbol] ?? 'briefcase';
}

const styles = StyleSheet.create({
  hero: { height: 260, justifyContent: 'flex-end', overflow: 'hidden' },
  heroIcon: { position: 'absolute', right: -10, top: 40 },
  heroContent: { width: '100%' },
  heroBrand: { color: 'rgba(255,255,255,0.85)', fontSize: 13, fontWeight: '700', letterSpacing: 2, marginHorizontal: 22 },
  heroTitle: { color: '#fff', fontSize: 28, fontWeight: '700', marginTop: 8, marginHorizontal: 22, marginBottom: 22 },
  statsRow: { flexDirection: 'row', gap: 12, paddingHorizontal: 18, marginTop: 20 },
  statCard: {
    flex: 1, alignItems: 'center', gap: 6, paddingVertical: 16, paddingHorizontal: 6,
    borderRadius: 18, borderWidth: 1,
  },
  statValue: { fontSize: 15, fontWeight: '700' },
  statLabel: { fontSize: 11, fontWeight: '500' },
  sectionCard: { marginHorizontal: 18, marginTop: 20, padding: 18 },
  sectionTitle: { fontSize: 17, fontWeight: '700', marginBottom: 12 },
  aboutText: { fontSize: 14, lineHeight: 22 },
  tagsRow: { flexDirection: 'row', flexWrap: 'wrap', gap: 8, marginTop: 16 },
  deliverableRow: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 7 },
  deliverableText: { fontSize: 14, fontWeight: '500', flex: 1 },
  applyBar: { borderTopWidth: StyleSheet.hairlineWidth },
  applyBarInner: { flexDirection: 'row', alignItems: 'center', gap: 14, paddingHorizontal: 20, paddingVertical: 14 },
  payoutValue: { fontSize: 18, fontWeight: '700' },
  payoutLabel: { fontSize: 12, fontWeight: '500', marginTop: 2 },
  applyButton: { borderRadius: radius.pill, overflow: 'hidden' },
  appliedBtn: {
    flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 7,
    borderRadius: radius.pill, borderWidth: 1.5, paddingHorizontal: 22, paddingVertical: 13,
  },
  appliedText: { fontSize: 15, fontWeight: '700' },
  backWrap: { position: 'absolute', top: 0, left: 0, right: 0 },
  backBtn: { width: 40, height: 40, borderRadius: 20, alignItems: 'center', justifyContent: 'center', marginLeft: 18, marginTop: 8 },
});
