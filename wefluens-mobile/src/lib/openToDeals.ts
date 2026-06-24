/**
 * "Open to new deals" availability flag, stored on-device. The Swift app keeps
 * this as ephemeral view state; we persist it so it survives app restarts.
 * (There is no backend column for it yet.)
 */
import AsyncStorage from '@react-native-async-storage/async-storage';

const KEY = 'wefluens.openToDeals';

export async function getOpenToDeals(): Promise<boolean> {
  try {
    const raw = await AsyncStorage.getItem(KEY);
    return raw == null ? true : raw === '1'; // default on
  } catch {
    return true;
  }
}

export async function setOpenToDeals(value: boolean): Promise<void> {
  await AsyncStorage.setItem(KEY, value ? '1' : '0').catch(() => {});
}
