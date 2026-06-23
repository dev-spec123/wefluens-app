// submit-support-ticket — any signed-in user. Records an in-app support ticket
// in `support_tickets` and emails it to the support inbox via Resend, reusing the
// same app_secrets-backed email config as invite-user (Rork private env vars do
// not reach the edge runtime, so the Resend key lives in the service-role-only
// `app_secrets` table). The Help/Contact screen in the app calls this.

import {
  AuthError,
  corsHeaders,
  createAdminClient,
  jsonResponse,
  requireUser,
} from "../_shared/auth.ts";

interface TicketBody {
  subject?: string;
  body?: string;
}

const DEFAULT_FROM = "Wefluens <invite@wefluens.com>";
const SUPPORT_INBOX = "support@wefluens.com";

// Mirrors invite-user.loadEmailConfig: env wins, then app_secrets, then default
// sender. RESEND_TO lets ops redirect the support inbox without a code change.
async function loadEmailConfig(
  admin: ReturnType<typeof createAdminClient>,
): Promise<{ resendKey: string; from: string; to: string }> {
  const db: Record<string, string> = {};
  const { data } = await admin
    .from("app_secrets")
    .select("key,value")
    .in("key", ["RESEND_API_KEY", "RESEND_FROM", "RESEND_SUPPORT_TO"]);
  for (const row of (data ?? []) as Array<{ key: string; value: string }>) {
    db[row.key] = row.value;
  }
  const resendKey = (Deno.env.get("RESEND_API_KEY") || db["RESEND_API_KEY"] || "").trim();
  const from = (Deno.env.get("RESEND_FROM") || db["RESEND_FROM"] || DEFAULT_FROM).trim();
  const to = (Deno.env.get("RESEND_SUPPORT_TO") || db["RESEND_SUPPORT_TO"] || SUPPORT_INBOX).trim();
  return { resendKey, from, to };
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function ticketEmailHtml(args: {
  subject: string;
  body: string;
  email: string;
  userId: string;
}): string {
  return `<!DOCTYPE html>
<html lang="en">
<body style="margin:0;background:#f6f5fb;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <div style="max-width:560px;margin:0 auto;padding:32px 24px;">
    <div style="background:linear-gradient(135deg,#FF4D6D,#FF9A5A);border-radius:18px;padding:20px 24px;">
      <div style="font-size:20px;font-weight:800;color:#fff;">New support ticket</div>
    </div>
    <div style="background:#fff;border-radius:18px;padding:24px;margin-top:14px;">
      <div style="font-size:13px;color:#888;">Subject</div>
      <div style="font-size:17px;font-weight:700;color:#1a1430;margin:2px 0 16px;">${escapeHtml(args.subject)}</div>
      <div style="font-size:13px;color:#888;">Message</div>
      <div style="font-size:15px;line-height:1.6;color:#333;white-space:pre-wrap;margin-top:4px;">${escapeHtml(args.body)}</div>
      <hr style="border:none;border-top:1px solid #eee;margin:20px 0;" />
      <div style="font-size:12px;color:#aaa;">From: ${escapeHtml(args.email)} · user ${args.userId}</div>
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

    const payload = (await req.json().catch(() => ({}))) as TicketBody;
    const subject = (payload.subject ?? "").trim();
    const body = (payload.body ?? "").trim();
    if (subject.length === 0 || body.length === 0) {
      return jsonResponse({ ok: false, error: "EMPTY" });
    }
    if (subject.length > 200 || body.length > 5000) {
      return jsonResponse({ ok: false, error: "TOO_LONG" });
    }

    // Record the ticket (service role: the row is owned by the caller).
    const { error: insErr } = await admin.from("support_tickets").insert({
      user_id: user.id,
      subject,
      body,
      status: "open",
    });
    if (insErr) {
      console.error("support ticket insert failed:", insErr.message);
      return jsonResponse({ ok: false, error: "DB_ERROR" });
    }

    // Best-effort email to the support inbox. The ticket is already saved, so an
    // email misconfig is non-fatal — we still report success to the user.
    const { resendKey, from, to } = await loadEmailConfig(admin);
    if (resendKey) {
      const resp = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${resendKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from,
          to: [to],
          reply_to: user.email ?? undefined,
          subject: `[Support] ${subject}`,
          html: ticketEmailHtml({
            subject,
            body,
            email: user.email ?? "(unknown)",
            userId: user.id,
          }),
        }),
      });
      if (!resp.ok) {
        // Logged, but not surfaced — the ticket is persisted regardless.
        console.error("support email send failed:", resp.status, await resp.text());
      }
    } else {
      console.error("RESEND_API_KEY not configured; ticket saved without email");
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
