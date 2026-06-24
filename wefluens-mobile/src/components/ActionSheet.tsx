/**
 * Cross-platform bottom action sheet. Works on web (where react-native's
 * Alert action sheets are no-ops) and native. Used for row/message menus.
 */
import { Ionicons } from '@expo/vector-icons';
import { Modal, Pressable, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { radius, useTheme } from '@/lib/theme';

export interface SheetAction {
  label: string;
  icon?: keyof typeof Ionicons.glyphMap;
  destructive?: boolean;
  onPress: () => void;
}

export function ActionSheet({
  visible, title, actions, cancelLabel, onClose,
}: {
  visible: boolean;
  title?: string;
  actions: SheetAction[];
  cancelLabel: string;
  onClose: () => void;
}) {
  const c = useTheme();
  return (
    <Modal visible={visible} transparent animationType="fade" onRequestClose={onClose}>
      <Pressable style={styles.scrim} onPress={onClose}>
        {/* Inner press swallows taps so they don't close the sheet. */}
        <Pressable onPress={() => {}}>
          <SafeAreaView edges={['bottom']}>
            <View style={[styles.group, { backgroundColor: c.card, borderColor: c.hairline }]}>
              {title ? (
                <View style={[styles.titleRow, { borderColor: c.hairline }]}>
                  <Text style={{ color: c.inkSecondary, fontSize: 13, textAlign: 'center' }}>{title}</Text>
                </View>
              ) : null}
              {actions.map((a, i) => (
                <Pressable
                  key={i}
                  onPress={() => { onClose(); a.onPress(); }}
                  style={[styles.action, { borderColor: c.hairline, borderTopWidth: i > 0 || title ? StyleSheet.hairlineWidth : 0 }]}
                >
                  {a.icon ? <Ionicons name={a.icon} size={20} color={a.destructive ? c.danger : c.coral} /> : null}
                  <Text style={{ fontSize: 16, color: a.destructive ? c.danger : c.ink, fontWeight: '500' }}>{a.label}</Text>
                </Pressable>
              ))}
            </View>
            <Pressable onPress={onClose} style={[styles.cancel, { backgroundColor: c.card }]}>
              <Text style={{ fontSize: 16, color: c.coral, fontWeight: '700' }}>{cancelLabel}</Text>
            </Pressable>
          </SafeAreaView>
        </Pressable>
      </Pressable>
    </Modal>
  );
}

const styles = StyleSheet.create({
  scrim: { flex: 1, backgroundColor: 'rgba(0,0,0,0.4)', justifyContent: 'flex-end' },
  group: { marginHorizontal: 10, marginBottom: 8, borderRadius: 16, borderWidth: 1, overflow: 'hidden' },
  titleRow: { paddingVertical: 12, paddingHorizontal: 14, borderBottomWidth: StyleSheet.hairlineWidth },
  action: { flexDirection: 'row', alignItems: 'center', gap: 12, paddingVertical: 16, paddingHorizontal: 18 },
  cancel: { marginHorizontal: 10, marginBottom: 6, borderRadius: 16, paddingVertical: 16, alignItems: 'center' },
});
