import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
// Use the legacy file-system download (stable, reliable across OEMs incl. MIUI).
import * as FileSystem from 'expo-file-system/legacy';
// The default expo-media-library save/permission methods are deprecated in SDK 56
// and THROW at runtime — the /legacy entrypoint keeps the working implementations.
import * as MediaLibrary from 'expo-media-library/legacy';
import { useState } from 'react';
import {
  ActivityIndicator, Modal, Platform, Pressable, StyleSheet, View, useWindowDimensions,
} from 'react-native';
import { Gesture, GestureDetector, GestureHandlerRootView } from 'react-native-gesture-handler';
import Animated, { useAnimatedStyle, useSharedValue, withTiming } from 'react-native-reanimated';
import { SafeAreaView } from 'react-native-safe-area-context';

import { notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';

/**
 * Fullscreen image viewer with pinch-to-zoom, double-tap zoom, pan, and
 * save-to-gallery. Used from chat image bubbles (1:1 and group).
 */
export function ImageViewer({
  visible, uri, onClose, cacheKey,
}: {
  visible: boolean;
  uri: string | null;
  onClose: () => void;
  /** Stable storage path — keeps the fullscreen image served from the same
   *  on-device cache as the thumbnail (no re-download). */
  cacheKey?: string | null;
}) {
  const { t } = useI18n();
  const { width, height } = useWindowDimensions();
  const [saving, setSaving] = useState(false);

  const scale = useSharedValue(1);
  const savedScale = useSharedValue(1);
  const tx = useSharedValue(0);
  const ty = useSharedValue(0);
  const savedTx = useSharedValue(0);
  const savedTy = useSharedValue(0);

  function resetZoom() {
    scale.value = withTiming(1);
    savedScale.value = 1;
    tx.value = withTiming(0);
    ty.value = withTiming(0);
    savedTx.value = 0;
    savedTy.value = 0;
  }

  const pinch = Gesture.Pinch()
    .onUpdate((e) => {
      scale.value = Math.max(1, Math.min(savedScale.value * e.scale, 5));
    })
    .onEnd(() => {
      savedScale.value = scale.value;
      if (scale.value <= 1) {
        tx.value = withTiming(0);
        ty.value = withTiming(0);
        savedTx.value = 0;
        savedTy.value = 0;
      }
    });

  const pan = Gesture.Pan()
    .onUpdate((e) => {
      if (scale.value > 1) {
        tx.value = savedTx.value + e.translationX;
        ty.value = savedTy.value + e.translationY;
      }
    })
    .onEnd(() => {
      savedTx.value = tx.value;
      savedTy.value = ty.value;
    });

  const doubleTap = Gesture.Tap()
    .numberOfTaps(2)
    .onEnd(() => {
      if (scale.value > 1) {
        scale.value = withTiming(1);
        savedScale.value = 1;
        tx.value = withTiming(0);
        ty.value = withTiming(0);
        savedTx.value = 0;
        savedTy.value = 0;
      } else {
        scale.value = withTiming(2.5);
        savedScale.value = 2.5;
      }
    });

  const composed = Gesture.Race(doubleTap, Gesture.Simultaneous(pinch, pan));

  const animStyle = useAnimatedStyle(() => ({
    transform: [
      { translateX: tx.value },
      { translateY: ty.value },
      { scale: scale.value },
    ],
  }));

  async function save() {
    if (!uri || saving) return;
    if (Platform.OS === 'web') {
      if (typeof window !== 'undefined') window.open(uri, '_blank');
      return;
    }
    setSaving(true);
    try {
      const perm = await MediaLibrary.requestPermissionsAsync();
      if (!perm.granted) {
        notify(t('chatSaveDenied'));
        return;
      }
      const fileUri = `${FileSystem.cacheDirectory}wefluens-${Date.now()}.jpg`;
      const { uri: localUri } = await FileSystem.downloadAsync(uri, fileUri);
      await MediaLibrary.saveToLibraryAsync(localUri);
      notify(t('chatImageSaved'));
    } catch (e) {
      console.warn('save image failed', e);
      notify(t('chatSaveFailed'));
    } finally {
      setSaving(false);
    }
  }

  function handleClose() {
    resetZoom();
    onClose();
  }

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={handleClose}
      statusBarTranslucent
    >
      <GestureHandlerRootView style={{ flex: 1 }}>
        <View style={styles.backdrop}>
          {uri ? (
            <GestureDetector gesture={composed}>
              <Animated.View style={[StyleSheet.absoluteFill, styles.center, animStyle]}>
                <Image
                  source={{ uri, cacheKey: cacheKey ?? undefined }}
                  cachePolicy="memory-disk"
                  style={{ width, height: height * 0.86 }}
                  contentFit="contain"
                />
              </Animated.View>
            </GestureDetector>
          ) : null}

          <SafeAreaView style={styles.controls} edges={['top']} pointerEvents="box-none">
            <Pressable onPress={handleClose} hitSlop={12} style={styles.ctrlBtn}>
              <Ionicons name="close" size={26} color="#fff" />
            </Pressable>
            <Pressable onPress={save} hitSlop={12} style={styles.ctrlBtn} disabled={saving}>
              {saving ? (
                <ActivityIndicator color="#fff" />
              ) : (
                <Ionicons name="download-outline" size={24} color="#fff" />
              )}
            </Pressable>
          </SafeAreaView>
        </View>
      </GestureHandlerRootView>
    </Modal>
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: 'rgba(0,0,0,0.96)' },
  center: { alignItems: 'center', justifyContent: 'center' },
  controls: {
    position: 'absolute', top: 0, left: 0, right: 0, zIndex: 10,
    flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 12, paddingTop: 6,
  },
  ctrlBtn: {
    width: 44, height: 44, borderRadius: 22, margin: 6,
    alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(0,0,0,0.4)',
  },
});
