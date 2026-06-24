/**
 * Voice messages — recorder button for the composer + playback bubble.
 *
 * Recording/playback use expo-audio (SDK 56): useAudioRecorder + RecordingPresets
 * to capture an .m4a clip, useAudioPlayer + useAudioPlayerStatus to play it back.
 * Native only — recording isn't available on react-native-web, so the mic button
 * renders disabled there and the playback bubble degrades to a plain link/label.
 */
import { Ionicons } from '@expo/vector-icons';
import { LinearGradient } from 'expo-linear-gradient';
import {
  AudioModule, RecordingPresets, setAudioModeAsync, useAudioPlayer,
  useAudioPlayerStatus, useAudioRecorder, useAudioRecorderState,
} from 'expo-audio';
import { useCallback, useEffect, useRef, useState } from 'react';
import { ActivityIndicator, Platform, Pressable, StyleSheet, Text, View } from 'react-native';

import * as api from '@/lib/api';
import { notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { gradients, radius, useTheme } from '@/lib/theme';

const isWeb = Platform.OS === 'web';

/** mm:ss from a seconds value (rounded). */
function formatTime(seconds: number): string {
  const s = Math.max(0, Math.floor(seconds || 0));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${r < 10 ? '0' : ''}${r}`;
}

// ─────────────────────────── Recorder button ───────────────────────────

/**
 * Hold-to-record microphone button for the chat composer. On release it stops,
 * hands the local clip uri to `onComplete` (which uploads + sends), and resets.
 * Hidden entirely on web, where recording isn't supported.
 */
export function VoiceRecordButton({
  onComplete, sending,
}: {
  onComplete: (uri: string) => Promise<void>;
  sending: boolean;
}) {
  const c = useTheme();
  const { t } = useI18n();
  const recorder = useAudioRecorder(RecordingPresets.HIGH_QUALITY);
  const state = useAudioRecorderState(recorder);
  const [busy, setBusy] = useState(false);
  const activeRef = useRef(false);

  // Release recording-mode audio session on unmount if still active.
  useEffect(() => {
    return () => {
      if (activeRef.current) {
        recorder.stop().catch(() => {});
        setAudioModeAsync({ allowsRecording: false }).catch(() => {});
      }
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (isWeb) {
    // Recording is unsupported on web — show a disabled mic so the bar matches.
    return (
      <View style={[styles.micBtn, { opacity: 0.4 }]} pointerEvents="none">
        <Ionicons name="mic-outline" size={24} color={c.inkSecondary} />
      </View>
    );
  }

  const startRecording = useCallback(async () => {
    if (busy || sending || activeRef.current) return;
    try {
      const { granted } = await AudioModule.requestRecordingPermissionsAsync();
      if (!granted) { notify(t('chatMicDenied')); return; }
      await setAudioModeAsync({ allowsRecording: true, playsInSilentMode: true });
      await recorder.prepareToRecordAsync();
      recorder.record();
      activeRef.current = true;
    } catch (e) {
      console.warn('startRecording failed', e);
      activeRef.current = false;
    }
  }, [busy, sending, recorder, t]);

  const stopRecording = useCallback(async () => {
    if (!activeRef.current) return;
    activeRef.current = false;
    setBusy(true);
    try {
      await recorder.stop();
      await setAudioModeAsync({ allowsRecording: false }).catch(() => {});
      const uri = recorder.uri;
      if (uri) await onComplete(uri);
    } catch (e) {
      console.warn('stopRecording failed', e);
    } finally {
      setBusy(false);
    }
  }, [recorder, onComplete]);

  const recording = state.isRecording;
  const disabled = sending || busy;

  return (
    <Pressable
      onPressIn={startRecording}
      onPressOut={stopRecording}
      disabled={disabled}
      hitSlop={8}
      style={[
        recording ? styles.micBtnRecording : styles.micBtn,
        recording && { backgroundColor: c.coral + '22' },
      ]}
    >
      {busy ? (
        <ActivityIndicator color={c.coral} />
      ) : recording ? (
        <View style={styles.recordingInline}>
          <Ionicons name="mic" size={20} color={c.coral} />
          <Text style={{ color: c.coral, fontSize: 13, fontWeight: '700', fontVariant: ['tabular-nums'] }}>
            {formatTime((state.durationMillis ?? 0) / 1000)}
          </Text>
        </View>
      ) : (
        <Ionicons name="mic-outline" size={24} color={c.inkSecondary} />
      )}
    </Pressable>
  );
}

// ─────────────────────────── Playback bubble ───────────────────────────

/**
 * A voice-message bubble: play/pause button + a static waveform + duration,
 * matching the text bubble look (coral gradient for mine, cardSubtle for theirs).
 * Loads the signed URL lazily and streams it via expo-audio's useAudioPlayer.
 */
export function AudioBubble({
  path, isMe, onLongPress, onPress, selectMode,
}: {
  path: string;
  isMe: boolean;
  onLongPress?: () => void;
  onPress?: () => void;
  selectMode?: boolean;
}) {
  const c = useTheme();
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let alive = true;
    setFailed(false);
    api.signedMediaUrl(path)
      .then((u) => { if (alive) setUrl(u); })
      .catch(() => { if (alive) setFailed(true); });
    return () => { alive = false; };
  }, [path]);

  const player = useAudioPlayer(url ?? undefined);
  const status = useAudioPlayerStatus(player);

  // Loop back to the start once playback finishes so it can be replayed.
  useEffect(() => {
    if (status.didJustFinish) {
      player.pause();
      player.seekTo(0);
    }
  }, [status.didJustFinish, player]);

  const toggle = useCallback(() => {
    if (isWeb || !url) return;
    if (status.playing) player.pause();
    else {
      setAudioModeAsync({ allowsRecording: false, playsInSilentMode: true }).catch(() => {});
      player.play();
    }
  }, [isWeb, url, status.playing, player]);

  const tint = isMe ? '#fff' : c.coral;
  const seconds = status.isLoaded
    ? (status.playing || status.currentTime > 0 ? status.currentTime : status.duration)
    : 0;

  // Static waveform bars — purely decorative, deterministic per render.
  const bars = [10, 16, 8, 20, 12, 22, 14, 9, 18, 11, 16, 7];

  const handlePress = () => {
    if (selectMode && onPress) { onPress(); return; }
    toggle();
  };

  const inner = (
    <Pressable
      onPress={handlePress}
      onLongPress={onLongPress}
      delayLongPress={350}
      style={styles.audioRow}
    >
      {!url && !failed ? (
        <ActivityIndicator color={tint} />
      ) : (
        <Ionicons
          name={failed ? 'alert-circle-outline' : status.playing ? 'pause' : 'play'}
          size={22}
          color={tint}
        />
      )}
      <View style={styles.waveform}>
        {bars.map((h, i) => (
          <View
            key={i}
            style={{
              width: 3, height: h, borderRadius: 2,
              backgroundColor: isMe ? 'rgba(255,255,255,0.7)' : c.inkTertiary,
            }}
          />
        ))}
      </View>
      <Text style={{ color: tint, fontSize: 12.5, fontWeight: '600', minWidth: 36, textAlign: 'right', fontVariant: ['tabular-nums'] }}>
        {formatTime(seconds)}
      </Text>
    </Pressable>
  );

  if (isMe) {
    return (
      <View style={styles.mineWrap}>
        <LinearGradient colors={gradients.sunset} start={{ x: 0, y: 0 }} end={{ x: 1, y: 1 }} style={styles.audioBubble}>
          {inner}
        </LinearGradient>
      </View>
    );
  }
  return (
    <View style={[styles.theirsWrap, { backgroundColor: c.cardSubtle }]}>
      <View style={styles.audioBubble}>{inner}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  micBtn: { width: 36, height: 36, alignItems: 'center', justifyContent: 'center' },
  micBtnRecording: {
    height: 36, minWidth: 72, paddingHorizontal: 12, borderRadius: radius.pill,
    alignItems: 'center', justifyContent: 'center',
  },
  recordingInline: { flexDirection: 'row', alignItems: 'center', gap: 7 },
  mineWrap: { borderRadius: 20, overflow: 'hidden' },
  theirsWrap: { borderRadius: 20, overflow: 'hidden' },
  audioBubble: { paddingHorizontal: 12, paddingVertical: 10 },
  audioRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  waveform: { flexDirection: 'row', alignItems: 'center', gap: 2, height: 24 },
});
