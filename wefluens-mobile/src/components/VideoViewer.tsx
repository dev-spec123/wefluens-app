import { Ionicons } from '@expo/vector-icons';
// Default media-library save/permission methods are deprecated (throw) in SDK 56.
import * as MediaLibrary from 'expo-media-library/legacy';
import { useVideoPlayer, VideoView } from 'expo-video';
import { useEffect, useState } from 'react';
import {
  ActivityIndicator, Modal, Platform, Pressable, StyleSheet, Text, View, useWindowDimensions,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import * as api from '@/lib/api';
import { notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';

/**
 * Fullscreen video player (native controls) with a save-to-gallery button.
 * Takes a storage `path`: the file is downloaded to an on-device cache ONCE and
 * played from the local copy thereafter, so re-watching costs no bandwidth.
 */
export function VideoViewer({
  visible, path, uri, onClose,
}: {
  visible: boolean;
  path: string | null;
  /** A ready uri to play directly (favorites pass their permanent local copy, so
   *  playback works even after the server media is expired). Overrides `path`. */
  uri?: string | null;
  onClose: () => void;
}) {
  const { t } = useI18n();
  const [localUri, setLocalUri] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);
  const [saving, setSaving] = useState(false);

  // Resolve (and cache) the local file when opened; clear when closed.
  useEffect(() => {
    let active = true;
    setFailed(false);
    if (visible && uri) {
      setLocalUri(uri);
    } else if (visible && path) {
      setLocalUri(null);
      api.cachedMediaUri(path, 'mp4')
        .then((u) => { if (active) setLocalUri(u); })
        .catch(() => { if (active) setFailed(true); });
    } else {
      setLocalUri(null);
    }
    return () => { active = false; };
  }, [visible, path, uri]);

  async function save() {
    if (!localUri || saving) return;
    if (Platform.OS === 'web') {
      if (typeof window !== 'undefined') window.open(localUri, '_blank');
      return;
    }
    setSaving(true);
    try {
      const perm = await MediaLibrary.requestPermissionsAsync();
      if (!perm.granted) {
        notify(t('chatSaveDenied'));
        return;
      }
      // localUri is already the cached file on disk — save it straight away.
      await MediaLibrary.saveToLibraryAsync(localUri);
      notify(t('chatVideoSaved'));
    } catch (e) {
      console.warn('save video failed', e);
      notify(t('chatSaveFailed'));
    } finally {
      setSaving(false);
    }
  }

  return (
    <Modal
      visible={visible}
      transparent
      animationType="fade"
      onRequestClose={onClose}
      statusBarTranslucent
    >
      <View style={styles.backdrop}>
        {visible && localUri ? (
          <Player uri={localUri} />
        ) : visible && failed ? (
          <Text style={{ color: 'rgba(255,255,255,0.85)', fontSize: 15, paddingHorizontal: 32, textAlign: 'center' }}>
            {t('chatVideoExpired')}
          </Text>
        ) : visible ? (
          <ActivityIndicator color="#fff" size="large" />
        ) : null}

        <SafeAreaView style={styles.controls} edges={['top']} pointerEvents="box-none">
          <Pressable onPress={onClose} hitSlop={12} style={styles.ctrlBtn}>
            <Ionicons name="close" size={26} color="#fff" />
          </Pressable>
          <Pressable onPress={save} hitSlop={12} style={styles.ctrlBtn} disabled={saving || !localUri}>
            {saving ? (
              <ActivityIndicator color="#fff" />
            ) : (
              <Ionicons name="download-outline" size={24} color="#fff" />
            )}
          </Pressable>
        </SafeAreaView>
      </View>
    </Modal>
  );
}

function Player({ uri }: { uri: string }) {
  const { width, height } = useWindowDimensions();
  const player = useVideoPlayer(uri, (p) => {
    p.loop = false;
    p.play();
  });
  return (
    <VideoView
      player={player}
      style={{ width, height: height * 0.8 }}
      contentFit="contain"
      nativeControls
    />
  );
}

const styles = StyleSheet.create({
  backdrop: { flex: 1, backgroundColor: '#000', alignItems: 'center', justifyContent: 'center' },
  controls: {
    position: 'absolute', top: 0, left: 0, right: 0, zIndex: 10,
    flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 12, paddingTop: 6,
  },
  ctrlBtn: {
    width: 44, height: 44, borderRadius: 22, margin: 6,
    alignItems: 'center', justifyContent: 'center', backgroundColor: 'rgba(0,0,0,0.4)',
  },
});
