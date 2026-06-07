// activate-invite — PUBLIC landing page. Opened from the invite email link.
// Validates the token, creates the user (confirmed) with the initial password
// 11111111, flags them to change it on first login, and renders an HTML page.

import { corsHeaders, createAdminClient } from "../_shared/auth.ts";

const INITIAL_PASSWORD = "11111111";

function htmlResponse(body: string, status = 200) {
  return new Response(body, {
    status,
    headers: { ...corsHeaders, "Content-Type": "text/html; charset=utf-8" },
  });
}

function page(title: string, bodyHtml: string): string {
  return `<!DOCTYPE html>
<html lang="zh">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1" />
  <title>${title} · Wefluens</title>
</head>
<body style="margin:0;min-height:100vh;background:linear-gradient(160deg,#2a1f48,#1a1430);font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;display:flex;align-items:center;justify-content:center;padding:24px;">
  <div style="max-width:440px;width:100%;background:#fff;border-radius:28px;padding:36px 28px;text-align:center;box-shadow:0 24px 60px rgba(0,0,0,0.3);">
    ${bodyHtml}
  </div>
</body>
</html>`;
}

function successPage(email: string, alreadyActive: boolean): string {
  const heading = alreadyActive ? "账号已激活" : "账号激活成功 🎉";
  const sub = alreadyActive
    ? "这个账号之前已经激活过了。"
    : "你的 Wefluens 账号已经创建好了。";
  return page(
    heading,
    `<div style="font-size:54px;line-height:1;margin-bottom:8px;">✅</div>
     <h1 style="font-size:24px;margin:8px 0 6px;color:#1a1430;">${heading}</h1>
     <p style="font-size:15px;color:#666;margin:0 0 22px;line-height:1.6;">${sub}<br/>Your Wefluens account is ready.</p>
     <div style="background:#f6f5fb;border-radius:16px;padding:18px;text-align:left;">
       <div style="font-size:12px;color:#999;text-transform:uppercase;letter-spacing:1px;">邮箱 / Email</div>
       <div style="font-size:16px;font-weight:700;color:#1a1430;margin-top:2px;word-break:break-all;">${email}</div>
       <div style="font-size:12px;color:#999;text-transform:uppercase;letter-spacing:1px;margin-top:14px;">初始密码 / Password</div>
       <div style="font-size:22px;font-weight:800;color:#FF4D6D;letter-spacing:3px;margin-top:2px;">${INITIAL_PASSWORD}</div>
     </div>
     <p style="font-size:14px;color:#444;margin:22px 0 0;line-height:1.6;">
       请打开 <b>Wefluens App</b>，用上面的邮箱和初始密码登录，登录后系统会要求你立即修改密码。<br/>
       <span style="color:#888;">Open the Wefluens app and sign in — you'll be asked to set a new password.</span>
     </p>`,
  );
}

function errorPage(zh: string, en: string): string {
  return page(
    "无法激活",
    `<div style="font-size:54px;line-height:1;margin-bottom:8px;">⚠️</div>
     <h1 style="font-size:22px;margin:8px 0 6px;color:#1a1430;">无法激活</h1>
     <p style="font-size:15px;color:#666;margin:0;line-height:1.6;">${zh}<br/><span style="color:#999;">${en}</span></p>`,
  );
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const url = new URL(req.url);
  const token = url.searchParams.get("token") ?? "";
  if (!token) {
    return htmlResponse(errorPage("链接无效。", "Invalid link."), 400);
  }

  const admin = createAdminClient();

  try {
    const { data: invite } = await admin
      .from("invites")
      .select("*")
      .eq("token", token)
      .maybeSingle();

    if (!invite) {
      return htmlResponse(
        errorPage("邀请链接无效或已失效。", "This invite link is invalid."),
        404,
      );
    }

    if (invite.status === "activated") {
      return htmlResponse(successPage(invite.email, true));
    }

    if (new Date(invite.expires_at).getTime() < Date.now()) {
      return htmlResponse(
        errorPage(
          "邀请链接已过期，请联系管理员重新邀请。",
          "This invite link has expired — please ask your admin for a new one.",
        ),
        410,
      );
    }

    // Create the confirmed user with the shared initial password.
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email: invite.email,
      password: INITIAL_PASSWORD,
      email_confirm: true,
    });

    if (createErr) {
      // Most likely the user already exists — treat as already activated.
      console.error("createUser error:", createErr.message);
      await admin
        .from("invites")
        .update({ status: "activated", activated_at: new Date().toISOString() })
        .eq("id", invite.id);
      return htmlResponse(successPage(invite.email, true));
    }

    const newUserId = created.user?.id;
    if (newUserId) {
      // The handle_new_user trigger created the profile row; flag a forced change.
      await admin
        .from("profiles")
        .update({ must_change_password: true, email: invite.email })
        .eq("id", newUserId);
    }

    await admin
      .from("invites")
      .update({ status: "activated", activated_at: new Date().toISOString() })
      .eq("id", invite.id);

    return htmlResponse(successPage(invite.email, false));
  } catch (err) {
    console.error("activate-invite failed:", err);
    return htmlResponse(
      errorPage("激活失败，请稍后再试。", "Activation failed, please try again later."),
      500,
    );
  }
});
