// invite-user — admin-only. Creates an invite token, stores it, and emails an
// activation link via Resend. The user clicks the link (handled by activate-invite),
// which creates their account with the initial password 11111111.

import {
  AuthError,
  corsHeaders,
  createAdminClient,
  jsonResponse,
  requireUser,
} from "../_shared/auth.ts";

interface InviteBody {
  email?: string;
}

function randomToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function inviteEmailHtml(link: string): string {
  return `<!DOCTYPE html>
<html lang="zh">
<body style="margin:0;background:#1a1430;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <div style="max-width:520px;margin:0 auto;padding:40px 24px;">
    <div style="background:linear-gradient(135deg,#FF4D6D,#FF9A5A);border-radius:24px;padding:32px;text-align:center;">
      <div style="font-size:30px;font-weight:800;color:#fff;letter-spacing:0.5px;">Wefluens</div>
      <div style="font-size:14px;color:rgba(255,255,255,0.85);margin-top:6px;">创作者与品牌的连接之地</div>
    </div>
    <div style="background:#fff;border-radius:24px;padding:32px;margin-top:16px;">
      <h1 style="font-size:22px;margin:0 0 12px;color:#1a1430;">你被邀请加入 Wefluens 🎉</h1>
      <p style="font-size:15px;line-height:1.6;color:#444;margin:0 0 8px;">
        点击下面的按钮即可激活你的账号。激活后请回到 <b>Wefluens App</b>，使用此邮箱和初始密码登录。
      </p>
      <p style="font-size:15px;line-height:1.6;color:#444;margin:0 0 24px;">
        Tap the button below to activate your account, then open the <b>Wefluens app</b> and sign in with this email.
      </p>
      <div style="text-align:center;margin:28px 0;">
        <a href="${link}" style="display:inline-block;background:linear-gradient(135deg,#FF4D6D,#FF9A5A);color:#fff;text-decoration:none;font-size:16px;font-weight:700;padding:15px 36px;border-radius:14px;">
          激活账号 / Activate account
        </a>
      </div>
      <div style="background:#f6f5fb;border-radius:14px;padding:16px;text-align:center;">
        <div style="font-size:13px;color:#888;">初始密码 / Initial password</div>
        <div style="font-size:24px;font-weight:800;color:#1a1430;letter-spacing:3px;margin-top:4px;">11111111</div>
        <div style="font-size:12px;color:#aa6;margin-top:8px;">登录后请立即修改密码 · Please change it after first login</div>
      </div>
      <p style="font-size:12px;color:#aaa;margin:24px 0 0;line-height:1.5;">
        此链接 7 天内有效。如果按钮无法点击，请复制以下链接到浏览器打开：<br/>
        <span style="color:#FF4D6D;word-break:break-all;">${link}</span>
      </p>
    </div>
  </div>
</body>
</html>`;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user } = await requireUser(req);
    const admin = createAdminClient();

    // Only admins may invite.
    const { data: me } = await admin
      .from("profiles")
      .select("is_admin")
      .eq("id", user.id)
      .maybeSingle();
    if (!me?.is_admin) {
      return jsonResponse({ ok: false, error: "FORBIDDEN" }, 403);
    }

    const body = (await req.json().catch(() => ({}))) as InviteBody;
    const email = (body.email ?? "").trim().toLowerCase();
    if (!email || !email.includes("@") || !email.includes(".")) {
      return jsonResponse({ ok: false, error: "INVALID_EMAIL" });
    }

    // Block if already registered (a profile row exists for that email).
    const { data: existing } = await admin
      .from("profiles")
      .select("id")
      .eq("email", email)
      .maybeSingle();
    if (existing) {
      return jsonResponse({ ok: false, error: "ALREADY_REGISTERED" });
    }

    const token = randomToken();

    // Clear any prior pending invites for this email, then create a fresh one.
    await admin.from("invites").delete().eq("email", email).eq("status", "pending");

    const { error: insErr } = await admin.from("invites").insert({
      email,
      token,
      status: "pending",
      invited_by: user.id,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    });
    if (insErr) {
      console.error("invite insert failed:", insErr.message);
      return jsonResponse({ ok: false, error: "DB_ERROR" });
    }

    const resendKey = Deno.env.get("RESEND_API_KEY");
    if (!resendKey) {
      console.error("RESEND_API_KEY is not configured");
      return jsonResponse({ ok: false, error: "EMAIL_NOT_CONFIGURED" });
    }

    const from = Deno.env.get("RESEND_FROM") ?? "Wefluens <onboarding@resend.dev>";
    const link = `${Deno.env.get("SUPABASE_URL")}/functions/v1/activate-invite?token=${token}`;

    const resp = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from,
        to: [email],
        subject: "你被邀请加入 Wefluens / You're invited to Wefluens",
        html: inviteEmailHtml(link),
      }),
    });

    if (!resp.ok) {
      const detail = await resp.text();
      console.error("Resend send failed:", resp.status, detail);
      return jsonResponse({ ok: false, error: "EMAIL_SEND_FAILED", detail });
    }

    return jsonResponse({ ok: true });
  } catch (err) {
    if (err instanceof AuthError) {
      return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
    }
    console.error(err);
    return jsonResponse({ ok: false, error: "INTERNAL" }, 500);
  }
});
