/**
 * Campaign applications (申请) — stored on-device so an "Applied" state survives
 * leaving and re-opening the campaign. Local-only, mirrors favorites.ts in style;
 * applying/withdrawing is reversible. (The campaigns themselves are demo content,
 * so there's no server endpoint to apply against yet.)
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

const KEY = 'wefluens.appliedCampaigns';

export async function getAppliedCampaigns(): Promise<string[]> {
  try {
    const raw = await AsyncStorage.getItem(KEY);
    return raw ? (JSON.parse(raw) as string[]) : [];
  } catch {
    return [];
  }
}

export async function isCampaignApplied(id: string): Promise<boolean> {
  return (await getAppliedCampaigns()).includes(id);
}

/** Apply to (add) or withdraw from (remove) a campaign. */
export async function setCampaignApplied(id: string, applied: boolean): Promise<void> {
  const ids = await getAppliedCampaigns();
  const next = applied
    ? Array.from(new Set([id, ...ids]))
    : ids.filter((x) => x !== id);
  await AsyncStorage.setItem(KEY, JSON.stringify(next)).catch(() => {});
}
