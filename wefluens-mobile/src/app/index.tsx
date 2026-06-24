import { ActivityIndicator, View } from 'react-native';
import { useTheme } from '@/lib/theme';

export default function Index() {
  const c = useTheme();
  return (
    <View style={{ flex: 1, backgroundColor: c.paper, alignItems: 'center', justifyContent: 'center' }}>
      <ActivityIndicator color={c.coral} size="large" />
    </View>
  );
}
