/**
 * Help & FAQ — static curated Q&A screen, pushed from Me → Help & FAQ.
 * Mirrors the Swift FAQView (8 entries). For anything not answered here, the
 * user taps Contact Support (the separate row on the Me tab).
 */
import { useRouter } from 'expo-router';
import { ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { NavBar } from '@/components/ui';
import { useI18n, type Lang } from '@/lib/i18n';
import { useTheme } from '@/lib/theme';

type QA = { q: string; a: string };

const FAQ: Record<Lang, QA[]> = {
  en: [
    {
      q: 'How do I add a friend?',
      a: 'Open the Contacts tab and tap Add Friend, then search by email, @handle, or name and send a request. You can also browse the Top Talent directory and add creators from there. The other person has to accept before you become contacts.',
    },
    {
      q: "What's the difference between Brands and Campaigns?",
      a: "A brand is a company; a campaign is a single paid collaboration that a brand is hiring for. In Discover, tapping a brand filters the campaign list to that brand. The Brands directory in Contacts lets you browse brands and see each one's open campaigns.",
    },
    {
      q: 'How do favorites work?',
      a: "Long-press any message and choose Favorite to save it. Your favorites sync to your account, so they're available on any device you sign in to. Find them under Me → Favorites.",
    },
    {
      q: 'Will I get notifications?',
      a: 'You can turn Push Notifications on under Me → Preferences. When enabled, the app asks for permission to send you alerts about new messages and friend requests.',
    },
    {
      q: "Who can see when I'm active?",
      a: "Control this with the Activity Status switch in Privacy & Security. Turn it off and others won't see your online indicator. Data Sharing, in the same place, controls whether you appear in the Top Talent directory.",
    },
    {
      q: 'How do I report or block someone?',
      a: 'Tap Report on any message, chat, or profile to flag it for our safety team — reports are reviewed within 24 hours. You can also Block a user so they can no longer contact you. Manage blocked users in Privacy & Security.',
    },
    {
      q: 'How do I change my password or delete my account?',
      a: 'Both are in Me → Privacy & Security. Change Password lets you set a new one anytime; Delete Account permanently removes your profile and data.',
    },
    {
      q: 'Still need help?',
      a: "Tap Contact Support from the Me tab to send us a message — we'll get back to you by email.",
    },
  ],
  zh: [
    {
      q: '如何添加好友？',
      a: '打开「通讯录」标签页，点击「添加好友」，然后通过邮箱、@用户名或姓名搜索并发送好友申请。你也可以在「顶尖达人」目录里浏览并添加创作者。对方接受后，你们才会成为好友。',
    },
    {
      q: '品牌和活动有什么区别？',
      a: '品牌是一家公司；活动是某个品牌正在招募的一次付费合作。在「发现」中点击某个品牌，活动列表会筛选为该品牌的活动。「通讯录」里的品牌目录可让你浏览品牌并查看各自开放的活动。',
    },
    {
      q: '收藏是怎么用的？',
      a: '长按任意消息并选择「收藏」即可保存。你的收藏会同步到账号，因此在你登录的任何设备上都能查看。可在「我 → 收藏」中找到它们。',
    },
    {
      q: '我会收到通知吗？',
      a: '你可以在「我 → 偏好设置」中打开「推送通知」。开启后，应用会请求权限，向你推送新消息和好友申请的提醒。',
    },
    {
      q: '谁能看到我的在线状态？',
      a: '通过「隐私与安全」里的「活动状态」开关控制。关闭后，他人将看不到你的在线标识。同一页面的「数据共享」则控制你是否出现在「顶尖达人」目录中。',
    },
    {
      q: '如何举报或屏蔽某人？',
      a: '在任意消息、聊天或资料页点击「举报」，即可提交给我们的安全团队——举报会在 24 小时内审核。你也可以「屏蔽」某用户，使其无法再联系你。已屏蔽的用户可在「隐私与安全」中管理。',
    },
    {
      q: '如何修改密码或注销账号？',
      a: '两者都在「我 → 隐私与安全」中。「修改密码」可随时设置新密码；「注销账号」会永久删除你的资料和数据。',
    },
    {
      q: '还需要帮助？',
      a: '在「我」标签页点击「联系客服」给我们发消息——我们会通过邮件回复你。',
    },
  ],
  es: [
    {
      q: '¿Cómo agrego un amigo?',
      a: 'Abre la pestaña Contactos y toca Agregar amigo, luego busca por correo, @usuario o nombre y envía una solicitud. También puedes explorar el directorio de Creadores Top y agregarlos desde ahí. La otra persona debe aceptar antes de que sean contactos.',
    },
    {
      q: '¿Cuál es la diferencia entre Marcas y Campañas?',
      a: 'Una marca es una empresa; una campaña es una colaboración pagada concreta para la que una marca está contratando. En Descubrir, al tocar una marca se filtra la lista de campañas a esa marca. El directorio de Marcas en Contactos te permite explorar marcas y ver las campañas abiertas de cada una.',
    },
    {
      q: '¿Cómo funcionan los favoritos?',
      a: 'Mantén pulsado cualquier mensaje y elige Guardar para conservarlo. Tus favoritos se sincronizan con tu cuenta, así que están disponibles en cualquier dispositivo donde inicies sesión. Encuéntralos en Yo → Favoritos.',
    },
    {
      q: '¿Recibiré notificaciones?',
      a: 'Puedes activar las Notificaciones en Yo → Preferencias. Cuando están activadas, la app pide permiso para enviarte avisos de nuevos mensajes y solicitudes de amistad.',
    },
    {
      q: '¿Quién puede ver cuándo estoy activo?',
      a: 'Contrólalo con el interruptor Estado de Actividad en Privacidad y Seguridad. Desactívalo y los demás no verán tu indicador de conexión. Compartir Datos, en el mismo lugar, controla si apareces en el directorio de Creadores Top.',
    },
    {
      q: '¿Cómo reporto o bloqueo a alguien?',
      a: 'Toca Reportar en cualquier mensaje, chat o perfil para señalarlo a nuestro equipo de seguridad — los reportes se revisan en 24 horas. También puedes Bloquear a un usuario para que no pueda volver a contactarte. Gestiona los usuarios bloqueados en Privacidad y Seguridad.',
    },
    {
      q: '¿Cómo cambio mi contraseña o elimino mi cuenta?',
      a: 'Ambas están en Yo → Privacidad y Seguridad. Cambiar contraseña te permite establecer una nueva cuando quieras; Eliminar Cuenta borra permanentemente tu perfil y tus datos.',
    },
    {
      q: '¿Aún necesitas ayuda?',
      a: 'Toca Contactar soporte desde la pestaña Yo para enviarnos un mensaje — te responderemos por correo.',
    },
  ],
};

export default function Help() {
  const c = useTheme();
  const { t, lang } = useI18n();
  const router = useRouter();
  const items = FAQ[lang] ?? FAQ.en;

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={t('faqTitle')} onBack={() => router.back()} />
      <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 40 }}>
        <Text style={{ color: c.ink, fontSize: 26, fontWeight: '700', marginBottom: 8 }}>{t('faqTitle')}</Text>
        {items.map((qa, i) => (
          <View key={i} style={{ marginTop: 22 }}>
            <Text style={{ color: c.ink, fontSize: 17, fontWeight: '700', marginBottom: 6 }}>{qa.q}</Text>
            <Text style={{ color: c.inkSecondary, fontSize: 15, lineHeight: 22 }}>{qa.a}</Text>
          </View>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}
