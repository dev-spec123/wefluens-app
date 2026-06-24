/**
 * Favorites (收藏) — locally saved messages. Media favorites keep a permanent
 * on-device copy (see lib/favorites.ts), so images/videos/files open even after
 * the server media is auto-expired. Text shows a preview; tap a media row to
 * view/play/open it; tap the trash icon to remove.
 */
import { Ionicons } from '@expo/vector-icons';
import { Image } from 'expo-image';
import * as Linking from 'expo-linking';
import { useRouter } from 'expo-router';
import * as Sharing from 'expo-sharing';
import { useEffect, useState } from 'react';
import { ActivityIndicator, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ImageViewer } from '@/components/ImageViewer';
import { VideoViewer } from '@/components/VideoViewer';
import { AudioBubble } from '@/components/Voice';
import { Card, Divider, EmptyState, NavBar } from '@/components/ui';
import * as api from '@/lib/api';
import { notify } from '@/lib/dialog';
import { type FavItem, getFavorites, removeFavorite } from '@/lib/favorites';
import { useI18n } from '@/lib/i18n';
import { radius, useTheme } from '@/lib/theme';

function formatTime(ms: number): string {
  try {
    return new Date(ms).toLocaleString();
  } catch {
    return '';
  }
}

export default function Favorites() {
  const c = useTheme();
  const { t } = useI18n();
  const router = useRouter();

  const [items, setItems] = useState<FavItem[]>([]);
  const [loading, setLoading] = useState(true);
  const [viewerUri, setViewerUri] = useState<string | null>(null);
  const [viewerKey, setViewerKey] = useState<string | null>(null);
  const [video, setVideo] = useState<{ uri: string | null; path: string | null } | null>(null);

  useEffect(() => {
    let active = true;
    (async () => {
      try {
        const list = await getFavorites();
        if (active) setItems(list);
      } finally {
        if (active) setLoading(false);
      }
    })();
    return () => { active = false; };
  }, []);

  async function onRemove(id: string) {
    setItems((prev) => prev.filter((f) => f.id !== id));
    await removeFavorite(id);
  }

  // Open a file favorite: prefer the permanent local copy (works after expiry)
  // via the system share/open sheet; fall back to a signed URL when present.
  async function openFile(item: FavItem) {
    try {
      if (item.localUri && (await Sharing.isAvailableAsync())) {
        await Sharing.shareAsync(item.localUri, item.fileMime ? { mimeType: item.fileMime } : undefined);
        return;
      }
      if (item.imagePath) {
        const url = await api.signedMediaUrl(item.imagePath);
        await Linking.openURL(url);
      }
    } catch {
      notify(t('chatFileExpired'));
    }
  }

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('favoritesTitle')} onBack={() => router.back()} />

      {loading ? (
        <View style={styles.center}>
          <ActivityIndicator color={c.coral} />
        </View>
      ) : items.length === 0 ? (
        <EmptyState icon="bookmark-outline" title={t('favoritesEmpty')} />
      ) : (
        <ScrollView contentContainerStyle={{ paddingHorizontal: 18, paddingTop: 14, paddingBottom: 30 }}>
          <Card>
            {items.map((item, i) => (
              <View key={item.id}>
                <FavRow
                  item={item}
                  onRemove={onRemove}
                  onOpenImage={(u, k) => { setViewerUri(u); setViewerKey(k); }}
                  onOpenVideo={(it) => setVideo({ uri: it.localUri ?? null, path: it.imagePath ?? null })}
                  onOpenFile={openFile}
                />
                {i < items.length - 1 && <Divider inset={14} />}
              </View>
            ))}
          </Card>
        </ScrollView>
      )}

      <ImageViewer
        visible={!!viewerUri}
        uri={viewerUri}
        cacheKey={viewerKey}
        onClose={() => { setViewerUri(null); setViewerKey(null); }}
      />
      <VideoViewer
        visible={!!video}
        uri={video?.uri ?? null}
        path={video?.path ?? null}
        onClose={() => setVideo(null)}
      />
    </SafeAreaView>
  );
}

function FavRow({
  item, onRemove, onOpenImage, onOpenVideo, onOpenFile,
}: {
  item: FavItem;
  onRemove: (id: string) => void;
  onOpenImage: (uri: string, cacheKey: string) => void;
  onOpenVideo: (item: FavItem) => void;
  onOpenFile: (item: FavItem) => void;
}) {
  const c = useTheme();
  const { t } = useI18n();
  const [url, setUrl] = useState<string | null>(null);

  // Only fetch a signed URL for image thumbnails that have no permanent local copy.
  useEffect(() => {
    let active = true;
    if (item.kind === 'image' && !item.localUri && item.imagePath) {
      api.signedMediaUrl(item.imagePath).then((u) => { if (active) setUrl(u); }).catch(() => {});
    }
    return () => { active = false; };
  }, [item.kind, item.imagePath, item.localUri]);

  // Two lines so the time is never truncated behind a long source (group name)
  // or squeezed out by a wide voice bubble.
  const meta = (
    <View style={{ marginTop: 5 }}>
      <Text style={{ color: c.inkSecondary, fontSize: 12 }} numberOfLines={1}>{item.source}</Text>
      <Text style={{ color: c.inkTertiary, fontSize: 11, marginTop: 1 }} numberOfLines={1}>
        {formatTime(item.at)}
      </Text>
    </View>
  );

  const del = (
    <Pressable
      onPress={() => onRemove(item.id)}
      hitSlop={8}
      style={[styles.deleteBtn, { backgroundColor: c.danger + '14' }]}
    >
      <Ionicons name="trash-outline" size={18} color={c.danger} />
    </Pressable>
  );

  // Voice — a playable bubble (tap to play).
  if (item.kind === 'audio' && item.imagePath) {
    return (
      <View style={styles.row}>
        <AudioBubble path={item.imagePath} isMe={false} />
        <View style={{ flex: 1, marginHorizontal: 12, justifyContent: 'center' }}>{meta}</View>
        {del}
      </View>
    );
  }

  // Image — whole row opens the fullscreen viewer (uses the local copy if present).
  if (item.kind === 'image' && (item.localUri || item.imagePath)) {
    const imgUri = item.localUri ?? url;
    return (
      <Pressable
        onPress={() => imgUri && onOpenImage(imgUri, item.imagePath ?? '')}
        style={({ pressed }) => [styles.row, { backgroundColor: pressed ? c.cardSubtle : 'transparent' }]}
      >
        <View style={[styles.thumb, { backgroundColor: c.cardSubtle, borderColor: c.hairline }]}>
          {imgUri ? (
            <Image
              source={{ uri: imgUri, cacheKey: item.imagePath ?? undefined }}
              cachePolicy="memory-disk"
              style={styles.thumbImg}
              contentFit="cover"
            />
          ) : (
            <ActivityIndicator color={c.coral} />
          )}
        </View>
        <View style={{ flex: 1, marginRight: 12 }}>
          <Text style={[styles.text, { color: c.ink }]}>{t('chatImagePreview')}</Text>
          {meta}
        </View>
        {del}
      </Pressable>
    );
  }

  // Video — tap to play (from the permanent local copy).
  if (item.kind === 'video' && (item.localUri || item.imagePath)) {
    return (
      <Pressable
        onPress={() => onOpenVideo(item)}
        style={({ pressed }) => [styles.row, { backgroundColor: pressed ? c.cardSubtle : 'transparent' }]}
      >
        <View style={[styles.thumb, { backgroundColor: '#000', borderColor: c.hairline }]}>
          <Ionicons name="play-circle" size={30} color="#fff" />
        </View>
        <View style={{ flex: 1, marginRight: 12 }}>
          <Text style={[styles.text, { color: c.ink }]}>{t('chatVideoPreview')}</Text>
          {meta}
        </View>
        {del}
      </Pressable>
    );
  }

  // File — tap to open (local copy via the share/open sheet).
  if (item.kind === 'file' && (item.localUri || item.imagePath)) {
    return (
      <Pressable
        onPress={() => onOpenFile(item)}
        style={({ pressed }) => [styles.row, { backgroundColor: pressed ? c.cardSubtle : 'transparent' }]}
      >
        <View style={[styles.thumb, { backgroundColor: c.cardSubtle, borderColor: c.hairline }]}>
          <Ionicons name="document" size={22} color={c.coral} />
        </View>
        <View style={{ flex: 1, marginRight: 12 }}>
          <Text style={[styles.text, { color: c.ink }]} numberOfLines={1}>
            {item.fileName || t('chatFilePreview')}
          </Text>
          {meta}
        </View>
        {del}
      </Pressable>
    );
  }

  // Text.
  return (
    <View style={styles.row}>
      <View style={{ flex: 1, marginRight: 12 }}>
        <Text style={[styles.text, { color: c.ink }]} numberOfLines={3}>{item.text}</Text>
        {meta}
      </View>
      {del}
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, alignItems: 'center', justifyContent: 'center' },
  row: { flexDirection: 'row', alignItems: 'center', paddingHorizontal: 14, paddingVertical: 12 },
  text: { fontSize: 15, fontWeight: '500', lineHeight: 20 },
  meta: { fontSize: 12, marginTop: 5 },
  thumb: {
    width: 52, height: 52, borderRadius: radius.sm, borderWidth: 1, marginRight: 12,
    alignItems: 'center', justifyContent: 'center', overflow: 'hidden',
  },
  thumbImg: { width: 52, height: 52 },
  deleteBtn: { width: 36, height: 36, borderRadius: radius.sm, alignItems: 'center', justifyContent: 'center' },
});
