import { useLocalSearchParams, useRouter } from 'expo-router';
import { Pressable, ScrollView, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { NavBar } from '@/components/ui';
import { useI18n, type Lang } from '@/lib/i18n';
import { useTheme } from '@/lib/theme';

const SUPPORT = 'support@wefluens.com';

type Section = { h: string; b: string };
type DocSet = { updated: string; terms: Section[]; guidelines: Section[]; privacy: Section[] };

const CONTENT: Record<Lang, DocSet> = {
  zh: {
    updated: '最后更新：2026 年 6 月',
    terms: [
      { h: '1. 接受条款', b: 'Wefluens Connect 是创作者与品牌沟通、协作的社交平台。注册或使用本应用，即表示你同意本《使用条款》与《社区准则》。若不同意，请勿使用。' },
      { h: '2. 使用资格', b: '你须年满 17 周岁并具备签署本协议的法律资格。你须妥善保管账号凭据，并对账号下的一切活动负责。' },
      { h: '3. 你的内容', b: '你发送的消息、图片等内容归你所有，你须对其独立负责。你授予 Wefluens Connect 有限许可以托管并展示这些内容，使应用得以正常运行（例如把你的消息送达给接收方）。' },
      { h: '4. 对不良内容与滥用零容忍', b: 'Wefluens Connect 对不良、滥用或违法的内容及行为零容忍。你同意不发布或发送此类内容，不骚扰、威胁或辱骂他人。违规将导致内容被立即移除、账号被终止。' },
      { h: '5. 举报与内容管理', b: '应用提供举报不良内容/用户、屏蔽滥用者的功能。我们会审核举报并处理（通常 24 小时内），移除违规内容并清退违规用户。你可在聊天或资料页举报任意消息或用户，并在「隐私与安全」中管理已屏蔽的账户。' },
      { h: '6. 注销账号', b: '你可随时在「我 → 注销账号」删除账号及相关数据。对违反本条款的账号，我们有权暂停或终止。' },
      { h: '7. 免责与联系', b: `应用按"现状"提供，不作任何明示或默示担保。条款相关问题请发邮件至 ${SUPPORT}。` },
    ],
    guidelines: [
      { h: '互相尊重', b: 'Wefluens Connect 是创作者与品牌的专业社区。请尊重他人。骚扰、欺凌、仇恨言论与威胁一律禁止。' },
      { h: '禁止不良内容', b: '不得发布或发送色情、暴力、仇恨、歧视、违法，或剥削、危害他人的内容；文字、图片、文件、群聊均适用。我们对此零容忍，一经发现即移除。' },
      { h: '禁止垃圾信息与诈骗', b: '不得群发骚扰信息、发布欺诈性优惠或钓鱼链接，也不得冒充他人。' },
      { h: '举报与屏蔽', b: '发现违规内容，点击消息、聊天或资料页上的「举报」。也可「屏蔽」某用户，使其无法再联系你或查看你的内容。举报内容保密，并在 24 小时内审核。' },
      { h: '违规处理', b: `违规内容将被移除，违规用户可能被暂停或永久清退。严重违规将上报相关部门。联系安全团队：${SUPPORT}。` },
    ],
    privacy: [
      { h: '我们收集的信息', b: '账号信息（邮箱）、你填写的资料（昵称、用户名、简介、所在地、头像），以及你在应用内发送的内容（消息、图片、语音、视频）。我们也会记录基本的使用与设备信息，以保障服务正常运行。' },
      { h: '我们如何使用', b: '仅用于提供与维护服务：登录、把你的消息送达给接收方、展示资料、通过内容审核保障社区安全。我们不会出售你的个人信息。' },
      { h: '存储与安全', b: '数据存储在我们的后端服务商（Supabase）。传输全程使用 HTTPS 加密；聊天中的图片/视频存放在私有空间，仅凭限时签名链接访问。' },
      { h: '信息共享', b: '我们不出售你的数据。仅在为提供服务所必需、或法律要求时，才与服务商共享。你发送的消息会展示给对应的接收方。' },
      { h: '数据保留与删除', b: '你可随时在「我 → 注销账号」删除账号，我们会移除你的资料及相关数据。' },
      { h: '未成年人', b: '本应用面向 17 周岁及以上用户，我们不会在知情情况下收集未成年人的信息。' },
      { h: '联系我们', b: `隐私相关问题请发邮件至 ${SUPPORT}。` },
    ],
  },
  en: {
    updated: 'Last updated: June 2026',
    terms: [
      { h: '1. Acceptance', b: 'Wefluens Connect is a social platform where creators and brands connect, message, and collaborate. By creating an account or using the app you agree to these Terms of Use and to our Community Guidelines. If you do not agree, do not use the app.' },
      { h: '2. Eligibility', b: 'You must be at least 17 years old and legally able to enter into this agreement. You are responsible for keeping your credentials secure and for all activity under your account.' },
      { h: '3. Your content', b: 'You retain ownership of the messages, images, and other content you submit, and you are solely responsible for it. You grant Wefluens Connect a limited license to host and display it so the app can function.' },
      { h: '4. Zero tolerance for objectionable content and abuse', b: 'There is no tolerance for objectionable, abusive, or illegal content or behavior on Wefluens Connect. You agree not to post or send such content and not to harass, threaten, or abuse other users. Violations may result in immediate content removal and account termination.' },
      { h: '5. Reporting and moderation', b: 'The app lets you report objectionable content or users and block abusive users. We review reports and act on them — typically within 24 hours — by removing offending content and ejecting violators. Report any message or user from the chat or profile screens; manage blocked users in Privacy & Security.' },
      { h: '6. Account deletion', b: 'You may delete your account at any time from Profile → Delete Account, which removes your profile and associated data. We may suspend or terminate accounts that violate these Terms.' },
      { h: '7. Disclaimer & contact', b: `The app is provided "as is" without warranties of any kind. Questions about these Terms can be sent to ${SUPPORT}.` },
    ],
    guidelines: [
      { h: 'Be respectful', b: 'Wefluens Connect is a professional community for creators and brands. Treat others with respect. Harassment, bullying, hate speech, and threats are never allowed.' },
      { h: 'No objectionable content', b: 'Do not post or send content that is sexually explicit, violent, hateful, discriminatory, illegal, or that exploits or endangers anyone. This applies to text, images, files, and group chats. We have zero tolerance for this content and remove it as soon as we become aware of it.' },
      { h: 'No spam or scams', b: "Don't send unsolicited bulk messages, deceptive offers, phishing links, or impersonate others." },
      { h: 'Report and block', b: 'If you see something that breaks these guidelines, tap Report on the message, chat, or profile. You can also Block a user so they can no longer contact you or see your content. Reports are confidential and reviewed within 24 hours.' },
      { h: 'Enforcement', b: `Content that violates these guidelines is removed, and violators may be suspended or permanently removed. Serious violations are reported to the authorities. To reach our safety team, email ${SUPPORT}.` },
    ],
    privacy: [
      { h: 'Information we collect', b: 'Your account (email), the profile you provide (name, handle, bio, location, avatar), and the content you send in the app (messages, images, voice, video). We also record basic usage and device information so the service runs reliably.' },
      { h: 'How we use it', b: 'Only to provide and maintain the service: signing you in, delivering your messages to recipients, showing your profile, and keeping the community safe through moderation. We do not sell your personal information.' },
      { h: 'Storage and security', b: 'Data is stored with our backend provider (Supabase). All traffic is encrypted in transit over HTTPS; chat images and videos are kept in private storage and accessed only through short-lived signed links.' },
      { h: 'Sharing', b: 'We do not sell your data. We share it only with service providers as needed to operate the app, or when required by law. Messages you send are shown to their intended recipients.' },
      { h: 'Retention and deletion', b: 'You can delete your account anytime from Profile → Delete Account, which removes your profile and associated data.' },
      { h: 'Children', b: 'The app is intended for users 17 and older. We do not knowingly collect information from minors.' },
      { h: 'Contact', b: `For privacy questions, email ${SUPPORT}.` },
    ],
  },
  es: {
    updated: 'Última actualización: junio de 2026',
    terms: [
      { h: '1. Aceptación', b: 'Wefluens Connect es una plataforma social donde creadores y marcas se conectan, conversan y colaboran. Al crear una cuenta o usar la app aceptas estos Términos de Uso y nuestras Normas de la Comunidad. Si no estás de acuerdo, no uses la app.' },
      { h: '2. Elegibilidad', b: 'Debes tener al menos 17 años y capacidad legal para aceptar este acuerdo. Eres responsable de mantener seguras tus credenciales y de toda la actividad de tu cuenta.' },
      { h: '3. Tu contenido', b: 'Conservas la propiedad de los mensajes, imágenes y demás contenido que envíes, y eres el único responsable de ellos. Otorgas a Wefluens Connect una licencia limitada para alojarlo y mostrarlo para que la app funcione.' },
      { h: '4. Tolerancia cero al contenido objetable y al abuso', b: 'No hay tolerancia para contenido o conductas objetables, abusivas o ilegales en Wefluens Connect. Aceptas no publicar ni enviar dicho contenido ni acosar, amenazar o abusar de otros. Las infracciones pueden conllevar la eliminación inmediata del contenido y la cancelación de la cuenta.' },
      { h: '5. Reportes y moderación', b: 'La app permite reportar contenido o usuarios objetables y bloquear a usuarios abusivos. Revisamos los reportes y actuamos —normalmente en 24 horas— eliminando el contenido infractor y expulsando a los infractores. Reporta cualquier mensaje o usuario desde el chat o el perfil; gestiona los bloqueados en Privacidad y Seguridad.' },
      { h: '6. Eliminación de cuenta', b: 'Puedes eliminar tu cuenta en cualquier momento en Perfil → Eliminar Cuenta, lo que borra tu perfil y datos asociados. Podemos suspender o cancelar cuentas que infrinjan estos Términos.' },
      { h: '7. Descargo y contacto', b: `La app se ofrece "tal cual", sin garantías de ningún tipo. Para preguntas sobre estos Términos, escribe a ${SUPPORT}.` },
    ],
    guidelines: [
      { h: 'Sé respetuoso', b: 'Wefluens Connect es una comunidad profesional de creadores y marcas. Trata a los demás con respeto. El acoso, la intimidación, el discurso de odio y las amenazas nunca se permiten.' },
      { h: 'Sin contenido objetable', b: 'No publiques ni envíes contenido sexualmente explícito, violento, de odio, discriminatorio, ilegal o que explote o ponga en peligro a alguien. Aplica a texto, imágenes, archivos y chats de grupo. Tenemos tolerancia cero y lo eliminamos en cuanto lo detectamos.' },
      { h: 'Sin spam ni estafas', b: 'No envíes mensajes masivos no solicitados, ofertas engañosas, enlaces de phishing ni suplantes a otros.' },
      { h: 'Reporta y bloquea', b: 'Si ves algo que infringe estas normas, toca Reportar en el mensaje, chat o perfil. También puedes Bloquear a un usuario para que no pueda contactarte ni ver tu contenido. Los reportes son confidenciales y se revisan en 24 horas.' },
      { h: 'Cumplimiento', b: `El contenido que infringe estas normas se elimina, y los infractores pueden ser suspendidos o expulsados permanentemente. Las infracciones graves se reportan a las autoridades. Contacta a nuestro equipo de seguridad en ${SUPPORT}.` },
    ],
    privacy: [
      { h: 'Información que recopilamos', b: 'Tu cuenta (correo), el perfil que proporcionas (nombre, usuario, biografía, ubicación, avatar) y el contenido que envías en la app (mensajes, imágenes, voz, video). También registramos información básica de uso y del dispositivo para que el servicio funcione de forma fiable.' },
      { h: 'Cómo la usamos', b: 'Solo para ofrecer y mantener el servicio: iniciar sesión, entregar tus mensajes a los destinatarios, mostrar tu perfil y mantener la comunidad segura mediante moderación. No vendemos tu información personal.' },
      { h: 'Almacenamiento y seguridad', b: 'Los datos se almacenan con nuestro proveedor de backend (Supabase). Todo el tráfico se cifra en tránsito mediante HTTPS; las imágenes y videos del chat se guardan en almacenamiento privado y se acceden solo mediante enlaces firmados de corta duración.' },
      { h: 'Compartir', b: 'No vendemos tus datos. Solo los compartimos con proveedores de servicios según sea necesario para operar la app, o cuando la ley lo exige. Los mensajes que envías se muestran a sus destinatarios.' },
      { h: 'Conservación y eliminación', b: 'Puedes eliminar tu cuenta en cualquier momento en Perfil → Eliminar Cuenta, lo que borra tu perfil y los datos asociados.' },
      { h: 'Menores', b: 'La app está destinada a usuarios de 17 años o más. No recopilamos conscientemente información de menores.' },
      { h: 'Contacto', b: `Para preguntas de privacidad, escribe a ${SUPPORT}.` },
    ],
  },
};

export default function Legal() {
  const c = useTheme();
  const { t, lang } = useI18n();
  const router = useRouter();
  const { doc } = useLocalSearchParams<{ doc?: string }>();
  const docType: 'terms' | 'guidelines' | 'privacy' =
    doc === 'guidelines' ? 'guidelines' : doc === 'privacy' ? 'privacy' : 'terms';
  const title = docType === 'guidelines' ? t('legalGuidelines')
    : docType === 'privacy' ? t('legalPrivacy') : t('legalTerms');
  const set = CONTENT[lang] ?? CONTENT.en;
  const sections = set[docType];

  return (
    <SafeAreaView style={{ flex: 1, backgroundColor: c.paper }} edges={['top']}>
      <NavBar title={title} onBack={() => router.back()} />
      <ScrollView contentContainerStyle={{ padding: 20, paddingBottom: 40 }}>
        <Text style={{ color: c.ink, fontSize: 26, fontWeight: '700' }}>{title}</Text>
        <Text style={{ color: c.inkTertiary, fontSize: 13, marginTop: 4, marginBottom: 16 }}>{set.updated}</Text>
        {sections.map((s, i) => (
          <View key={i} style={{ marginBottom: 20 }}>
            <Text style={{ color: c.ink, fontSize: 17, fontWeight: '700', marginBottom: 6 }}>{s.h}</Text>
            <Text style={{ color: c.inkSecondary, fontSize: 15, lineHeight: 22 }}>{s.b}</Text>
          </View>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}
