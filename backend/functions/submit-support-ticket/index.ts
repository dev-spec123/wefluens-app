// submit-support-ticket — any signed-in user. Records an in-app support ticket
// in `support_tickets` and emails it to the support inbox via Resend, reusing the
// same app_secrets-backed email config as invite-user (Rork private env vars do
// not reach the edge runtime, so the Resend key lives in the service-role-only
// `app_secrets` table). The Help/Contact screen in the app calls this.
//
// It ALSO mirrors the submission into the company "hub" — a SEPARATE Supabase
// project whose URL + service-role key live in `app_secrets` (HUB_SUPABASE_URL,
// HUB_SERVICE_ROLE_KEY). Image attachments are uploaded to the hub's Storage and
// one row is written to the hub's shared `feedback` table. The hub step is
// best-effort: if its secrets are missing or any hub call fails, we log and still
// succeed on the local ticket + email, returning `{ ok: true, hub: false }`.

import {
  AuthError,
  corsHeaders,
  createAdminClient,
  jsonResponse,
  requireUser,
} from "../_shared/auth.ts";

interface ImageInput {
  dataBase64?: string;
  mime?: string;
}

interface TicketBody {
  subject?: string;
  body?: string;
  type?: string;
  lang?: string;
  images?: ImageInput[];
}

type FeedbackType = "bug" | "idea" | "other";

const DEFAULT_FROM = "Wefluens <invite@wefluens.com>";
const SUPPORT_INBOX = "support@wefluens.com";

const MAX_IMAGES = 6;
const MAX_IMAGE_BYTES = 5 * 1024 * 1024; // 5 MB per image, decoded
const HUB_BUCKET = "feedback-attachments";
const HUB_KEY_PREFIX = "App - Feedback";

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

// Service-role-only hub credentials, read with the same app_secrets pattern as
// the Resend key. Both must be present or the hub step is skipped.
async function loadHubConfig(
  admin: ReturnType<typeof createAdminClient>,
): Promise<{ url: string; serviceRoleKey: string }> {
  const db: Record<string, string> = {};
  const { data } = await admin
    .from("app_secrets")
    .select("key,value")
    .in("key", ["HUB_SUPABASE_URL", "HUB_SERVICE_ROLE_KEY"]);
  for (const row of (data ?? []) as Array<{ key: string; value: string }>) {
    db[row.key] = row.value;
  }
  // Trim a trailing slash off the URL so `${url}/storage/...` is well-formed.
  const url = (db["HUB_SUPABASE_URL"] || "").trim().replace(/\/+$/, "");
  const serviceRoleKey = (db["HUB_SERVICE_ROLE_KEY"] || "").trim();
  return { url, serviceRoleKey };
}

function escapeHtml(s: string): string {
  return s
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function normalizeType(raw: string | undefined): FeedbackType {
  return raw === "bug" || raw === "idea" || raw === "other" ? raw : "other";
}

function normalizeLang(raw: string | undefined): "zh" | "en" {
  return raw === "zh" ? "zh" : "en";
}

// Decode a base64 string (standard or URL-safe, with or without a data: prefix)
// to raw bytes. Returns null on malformed input.
function decodeBase64(input: string): Uint8Array | null {
  try {
    // Strip an optional `data:<mime>;base64,` prefix.
    const comma = input.indexOf(",");
    let b64 = comma >= 0 && /^data:/i.test(input) ? input.slice(comma + 1) : input;
    // Normalize URL-safe alphabet and strip whitespace.
    b64 = b64.replace(/-/g, "+").replace(/_/g, "/").replace(/\s+/g, "");
    const binary = atob(b64);
    const bytes = new Uint8Array(binary.length);
    for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  } catch {
    return null;
  }
}

// Sniff the leading magic bytes and return a canonical mime + file extension for
// the four accepted formats, or null if the bytes are not a supported image.
function sniffImage(bytes: Uint8Array): { mime: string; ext: string } | null {
  // PNG: 89 50 4E 47 0D 0A 1A 0A
  if (
    bytes.length >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4e && bytes[3] === 0x47 &&
    bytes[4] === 0x0d && bytes[5] === 0x0a && bytes[6] === 0x1a && bytes[7] === 0x0a
  ) {
    return { mime: "image/png", ext: "png" };
  }
  // JPEG: FF D8 FF
  if (bytes.length >= 3 && bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) {
    return { mime: "image/jpeg", ext: "jpg" };
  }
  // GIF: "GIF87a" or "GIF89a"
  if (
    bytes.length >= 6 &&
    bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x38 &&
    (bytes[4] === 0x37 || bytes[4] === 0x39) && bytes[5] === 0x61
  ) {
    return { mime: "image/gif", ext: "gif" };
  }
  // WEBP: "RIFF"...."WEBP"
  if (
    bytes.length >= 12 &&
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50
  ) {
    return { mime: "image/webp", ext: "webp" };
  }
  return null;
}

// Sanitize the storage submitter segment: keep it readable but path-safe.
function sanitizeSubmitter(raw: string): string {
  const cleaned = raw.replace(/[^a-zA-Z0-9._@-]+/g, "_").replace(/^_+|_+$/g, "");
  return cleaned.length > 0 ? cleaned.slice(0, 64) : "user";
}

function randomHex(): string {
  return crypto.randomUUID().replace(/-/g, "").slice(0, 12);
}

interface ValidImage {
  bytes: Uint8Array;
  mime: string;
  ext: string;
}

// Validate, decode and sniff up to MAX_IMAGES attachments. Invalid entries are
// logged and dropped; the caller proceeds with whatever survives.
function collectValidImages(images: ImageInput[] | undefined): ValidImage[] {
  if (!Array.isArray(images) || images.length === 0) return [];
  const out: ValidImage[] = [];
  for (const img of images.slice(0, MAX_IMAGES)) {
    const data = (img?.dataBase64 ?? "").trim();
    if (!data) continue;
    const bytes = decodeBase64(data);
    if (!bytes) {
      console.error("hub image rejected: undecodable base64");
      continue;
    }
    if (bytes.length === 0 || bytes.length > MAX_IMAGE_BYTES) {
      console.error(`hub image rejected: size ${bytes.length} out of bounds`);
      continue;
    }
    const sniffed = sniffImage(bytes);
    if (!sniffed) {
      console.error("hub image rejected: unsupported format (magic-byte sniff)");
      continue;
    }
    out.push({ bytes, mime: sniffed.mime, ext: sniffed.ext });
  }
  return out;
}

// Upload one image's raw bytes to the hub Storage bucket and return its public
// URL, or null on failure.
async function uploadHubImage(
  hub: { url: string; serviceRoleKey: string },
  submitter: string,
  img: ValidImage,
): Promise<string | null> {
  const key = `${HUB_KEY_PREFIX}/${submitter}/${Date.now()}_${randomHex()}.${img.ext}`;
  const encodedKey = encodeURI(key);
  const uploadUrl = `${hub.url}/storage/v1/object/${HUB_BUCKET}/${encodedKey}`;
  try {
    const resp = await fetch(uploadUrl, {
      method: "POST",
      headers: {
        apikey: hub.serviceRoleKey,
        Authorization: `Bearer ${hub.serviceRoleKey}`,
        "Content-Type": img.mime,
      },
      body: img.bytes,
    });
    if (!resp.ok) {
      console.error("hub image upload failed:", resp.status, await resp.text());
      return null;
    }
    return `${hub.url}/storage/v1/object/public/${HUB_BUCKET}/${encodedKey}`;
  } catch (e) {
    console.error("hub image upload threw:", e);
    return null;
  }
}

function ticketEmailHtml(args: {
  subject: string;
  body: string;
  email: string;
  userId: string;
  imageUrls: string[];
}): string {
  const attachmentsBlock = args.imageUrls.length
    ? `
      <hr style="border:none;border-top:1px solid #eee;margin:20px 0;" />
      <div style="font-size:13px;color:#888;">Attachments</div>
      <div style="font-size:14px;line-height:1.6;margin-top:4px;">
        ${args.imageUrls
          .map(
            (u) =>
              `<div><a href="${escapeHtml(u)}" style="color:#FF4D6D;word-break:break-all;">${escapeHtml(u)}</a></div>`,
          )
          .join("")}
      </div>`
    : "";
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
      <div style="font-size:15px;line-height:1.6;color:#333;white-space:pre-wrap;margin-top:4px;">${escapeHtml(args.body)}</div>${attachmentsBlock}
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

    const type = normalizeType(payload.type);
    const lang = normalizeLang(payload.lang);

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

    // Mirror into the company hub: upload attachments to hub Storage + insert a
    // `feedback` row. Best-effort — the local ticket is already saved, so any hub
    // failure (missing secrets, upload/insert error) is logged and non-fatal.
    const submittedBy = user.email ?? user.id;
    const submitter = sanitizeSubmitter(user.email ?? user.id);
    const validImages = collectValidImages(payload.images);
    let hubOk = false;
    const hubUrls: string[] = [];
    try {
      const hub = await loadHubConfig(admin);
      if (hub.url && hub.serviceRoleKey) {
        for (const img of validImages) {
          const url = await uploadHubImage(hub, submitter, img);
          if (url) hubUrls.push(url);
        }
        const row = {
          type,
          subject,
          details: body,
          panel: "app",
          lang,
          submitted_by: submittedBy,
          done: false,
          image_url: hubUrls.length ? JSON.stringify(hubUrls) : null,
        };
        const resp = await fetch(`${hub.url}/rest/v1/feedback`, {
          method: "POST",
          headers: {
            apikey: hub.serviceRoleKey,
            Authorization: `Bearer ${hub.serviceRoleKey}`,
            "Content-Type": "application/json",
            Prefer: "return=minimal",
          },
          body: JSON.stringify(row),
        });
        if (resp.ok) {
          hubOk = true;
        } else {
          console.error("hub feedback insert failed:", resp.status, await resp.text());
        }
      } else {
        console.error("hub secrets missing (HUB_SUPABASE_URL / HUB_SERVICE_ROLE_KEY); skipping hub mirror");
      }
    } catch (e) {
      console.error("hub mirror threw:", e);
    }

    // Best-effort email to the support inbox. The ticket is already saved, so an
    // email misconfig is non-fatal — we still report success to the user. The
    // hub attachment URLs (if any) are listed in the email body.
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
            imageUrls: hubUrls,
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

    return jsonResponse({ ok: true, hub: hubOk });
  } catch (err) {
    if (err instanceof AuthError) {
      return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
    }
    console.error(err);
    return jsonResponse({ ok: false, error: "INTERNAL" }, 500);
  }
});
