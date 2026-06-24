/**
 * Document/file message bubble — icon + filename + size. Tapping opens the file
 * via a 1-hour signed URL in the system handler (browser/Quick Look). Shared by
 * the 1:1 and group chats.
 */
import { Ionicons } from '@expo/vector-icons';
import * as Linking from 'expo-linking';
import { useState } from 'react';
import { ActivityIndicator, Pressable, StyleSheet, Text, View } from 'react-native';

import * as api from '@/lib/api';
import { notify } from '@/lib/dialog';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';
import type { ChatMessage, GroupMessage } from '@/lib/types';

function humanSize(bytes: number | null): string {
  if (!bytes || bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  let n = bytes;
  let i = 0;
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i += 1; }
  return `${n.toFixed(n >= 10 || i === 0 ? 0 : 1)} ${units[i]}`;
}

/** Lowercase file extension (no dot) from a file name, or '' when absent. */
function fileExtension(name: string): string {
  const dot = name.lastIndexOf('.');
  return dot >= 0 ? name.slice(dot + 1).toLowerCase() : '';
}

/** Type-specific icon by extension — mirrors the Swift ChatFileBubble symbols. */
function iconForExt(ext: string): keyof typeof Ionicons.glyphMap {
  switch (ext) {
    case 'pdf': return 'document-text';
    case 'doc': case 'docx': case 'pages': return 'document';
    case 'xls': case 'xlsx': case 'csv': case 'numbers': return 'grid';
    case 'ppt': case 'pptx': case 'key': return 'easel';
    case 'zip': case 'rar': case '7z': return 'archive';
    case 'txt': case 'rtf': return 'document-outline';
    default: return 'document';
  }
}

/** Type-specific accent color by extension — mirrors the Swift ChatFileBubble palette. */
function colorForExt(ext: string): string {
  switch (ext) {
    case 'pdf': return '#FF5A5F';
    case 'doc': case 'docx': case 'pages': return '#2B7CD3';
    case 'xls': case 'xlsx': case 'csv': case 'numbers': return '#1FA463';
    case 'ppt': case 'pptx': case 'key': return '#E8703A';
    case 'zip': case 'rar': case '7z': return '#9B7BD4';
    default: return '#8A8A8E';
  }
}

export function FileBubble({
  message, isMe, onLongPress, onPress, selectMode,
}: {
  message: ChatMessage | GroupMessage;
  isMe: boolean;
  onLongPress?: () => void;
  onPress?: () => void;
  selectMode?: boolean;
}) {
  const c = useTheme();
  const { t } = useI18n();
  const [loading, setLoading] = useState(false);

  async function open() {
    if (!message.imagePath || loading) return;
    setLoading(true);
    try {
      const url = await api.signedMediaUrl(message.imagePath);
      // The server file may have been auto-expired/cleaned — confirm it's still there.
      const res = await fetch(url, { method: 'HEAD' }).catch(() => null);
      if (res && (res.status === 404 || res.status === 400)) {
        notify(t('chatFileExpired'));
        return;
      }
      await Linking.openURL(url);
    } catch {
      // signedMediaUrl throws when the object no longer exists.
      notify(t('chatFileExpired'));
    } finally {
      setLoading(false);
    }
  }

  const name = message.fileName ?? 'File';
  const size = humanSize(message.fileSize ?? null);
  const ext = fileExtension(name);
  const typeIcon = iconForExt(ext);
  const typeColor = colorForExt(ext);

  return (
    <Pressable
      onPress={selectMode ? onPress : open}
      onLongPress={onLongPress}
      delayLongPress={350}
      style={[styles.wrap, { backgroundColor: isMe ? c.coral : c.cardSubtle, borderColor: c.hairline }]}
    >
      {/* White tile holds a type-specific icon (PDF red, Word blue, Excel green…). */}
      <View style={[styles.iconBox, { backgroundColor: '#fff' }]}>
        {loading ? (
          <ActivityIndicator color={typeColor} />
        ) : (
          <Ionicons name={typeIcon} size={22} color={typeColor} />
        )}
      </View>
      <View style={{ flexShrink: 1 }}>
        <Text style={[styles.name, { color: isMe ? '#fff' : c.ink }]} numberOfLines={2}>{name}</Text>
        {size ? (
          <Text style={[styles.size, { color: isMe ? 'rgba(255,255,255,0.8)' : c.inkSecondary }]}>{size}</Text>
        ) : null}
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  wrap: {
    flexDirection: 'row', alignItems: 'center', gap: 10, maxWidth: 250, minWidth: 150,
    paddingHorizontal: 12, paddingVertical: 10, borderRadius: radius.lg, borderWidth: 1,
  },
  iconBox: { width: 40, height: 40, borderRadius: radius.sm, alignItems: 'center', justifyContent: 'center' },
  name: { fontSize: 14, fontWeight: '600' },
  size: { fontSize: 12, marginTop: 2 },
});
