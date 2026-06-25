/**
 * Campaign applications (申请) — the SERVER is the source of truth now (the
 * apply_to_campaign / withdraw_from_campaign / list_my_applications RPCs). This
 * module keeps a thin on-device mirror in AsyncStorage so the "Applied" state
 * shows instantly while a screen waits on the network; it is seeded from the
 * server via `seedAppliedCampaigns`, and apply/withdraw write through both the
 * RPC and the local cache.
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

import { applyToCampaign, withdrawFromCampaign } from './api';

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

/** Overwrite the local cache with the server's authoritative applied-id list. */
export async function seedAppliedCampaigns(ids: string[]): Promise<void> {
  await AsyncStorage.setItem(KEY, JSON.stringify(Array.from(new Set(ids)))).catch(() => {});
}

/** Update only the local cache (no network). Used for optimistic UI. */
export async function setLocalCampaignApplied(id: string, applied: boolean): Promise<void> {
  const ids = await getAppliedCampaigns();
  const next = applied
    ? Array.from(new Set([id, ...ids]))
    : ids.filter((x) => x !== id);
  await AsyncStorage.setItem(KEY, JSON.stringify(next)).catch(() => {});
}

/**
 * Apply to (true) or withdraw from (false) a campaign. Writes through to the
 * server RPC first (so the server stays the source of truth), then mirrors the
 * result into the local cache. Throws if the server call fails.
 */
export async function setCampaignApplied(id: string, applied: boolean): Promise<void> {
  if (applied) await applyToCampaign(id);
  else await withdrawFromCampaign(id);
  await setLocalCampaignApplied(id, applied);
}
