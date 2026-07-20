// invite-user — any signed-in user. Whitelists an email for signup: stores a
// pending row in `invites`, which signup-with-invite accepts in place of an
// invite code. No email is sent — the inviter tells the person to download the
// app and sign up with this exact email address (they pick their own password).

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

// The invites table has a token column (used by the legacy emailed activation
// links, still honored by activate-invite). We keep minting one per row so the
// schema is unchanged; it's simply never sent anywhere.
function randomToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Any signed-in user may invite. Admins invite freely; everyone else spends
    // one of their personal invite allowance (same budget as their invite code).
    const { user, supabase: userClient } = await requireUser(req);
    const admin = createAdminClient();

    const { data: me } = await admin
      .from("profiles")
      .select("is_admin")
      .eq("id", user.id)
      .maybeSingle();
    const isAdmin = !!me?.is_admin;

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

    // Charge a non-admin one invite up front (atomic). Refunded below if the
    // whitelist row can't be created.
    let spentInvite = false;
    if (!isAdmin) {
      const { data: ok, error: spendErr } = await userClient.rpc("spend_my_invite");
      if (spendErr) {
        console.error("spend_my_invite failed:", spendErr.message);
        return jsonResponse({ ok: false, error: "DB_ERROR" });
      }
      if (!ok) {
        return jsonResponse({ ok: false, error: "NO_INVITES_LEFT" });
      }
      spentInvite = true;
    }

    // Clear any prior pending invites for this email, then create a fresh one.
    await admin.from("invites").delete().eq("email", email).eq("status", "pending");

    const { error: insErr } = await admin.from("invites").insert({
      email,
      token: randomToken(),
      status: "pending",
      invited_by: user.id,
      expires_at: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toISOString(),
    });
    if (insErr) {
      console.error("invite insert failed:", insErr.message);
      if (spentInvite) await userClient.rpc("refund_my_invite");
      return jsonResponse({ ok: false, error: "DB_ERROR" });
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
