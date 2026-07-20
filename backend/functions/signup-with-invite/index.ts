// signup-with-invite — public. The ONLY way to create an account once invite-only
// is enabled (public auth.signUp is disabled in Auth settings). Creates an
// email-confirmed account via the admin API, then the client signs in normally.
//
// TWO ways to be invited (either is sufficient):
//   1. Email invite — an admin invited this email (a pending, unexpired row in
//      `invites`). No code needed; the invite is marked activated on success.
//   2. Invite code — a valid code (admin-minted or a user's personal code).
// Email invites are checked FIRST, so an invited user never burns a code.
// Neither ⇒ INVITE_REQUIRED (the client shows "Wefluens Connect is invite-only").
//
// Both claims are atomic (a conditional UPDATE / claim_invite_code), so they can't
// be double-redeemed by concurrent requests. If account creation fails after a
// claim, we release it (best-effort).

import {
  corsHeaders,
  createAdminClient,
  jsonResponse,
} from "../_shared/auth.ts";

interface Body {
  email?: string;
  password?: string;
  code?: string;
}

const MIN_PASSWORD = 8;

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const body = (await req.json().catch(() => ({}))) as Body;
    const email = (body.email ?? "").trim().toLowerCase();
    const password = body.password ?? "";
    const code = (body.code ?? "").trim();

    if (!email || !email.includes("@") || !email.includes(".")) {
      return jsonResponse({ ok: false, error: "INVALID_EMAIL" });
    }
    if (password.length < MIN_PASSWORD) {
      return jsonResponse({ ok: false, error: "WEAK_PASSWORD" });
    }

    const admin = createAdminClient();

    let claimedCodeId: string | null = null;
    let claimedInviteId: string | null = null;

    // 1) Email invite: atomically flip a pending, unexpired invite for this email
    //    to activated. If one existed, this user is invited — no code needed.
    const { data: invites } = await admin
      .from("invites")
      .update({ status: "activated", activated_at: new Date().toISOString() })
      .eq("email", email)
      .eq("status", "pending")
      .gt("expires_at", new Date().toISOString())
      .select("id");
    claimedInviteId = (invites as Array<{ id: string }> | null)?.[0]?.id ?? null;

    // 2) No email invite ⇒ fall back to an invite code.
    if (!claimedInviteId) {
      if (!code) {
        return jsonResponse({ ok: false, error: "INVITE_REQUIRED" });
      }
      const { data: codeId, error: claimErr } = await admin.rpc("claim_invite_code", { p_code: code });
      if (claimErr) {
        console.error("claim_invite_code failed:", claimErr.message);
        return jsonResponse({ ok: false, error: "SERVER_ERROR" });
      }
      if (!codeId) {
        return jsonResponse({ ok: false, error: "INVALID_CODE" });
      }
      claimedCodeId = codeId as string;
    }

    // Create the account, already email-confirmed (server-trusted).
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (createErr || !created?.user) {
      // Release whichever claim we made so a transient failure doesn't burn it.
      if (claimedCodeId) {
        await admin.rpc("release_invite_code", { p_code: code });
      }
      if (claimedInviteId) {
        await admin.from("invites")
          .update({ status: "pending", activated_at: null })
          .eq("id", claimedInviteId);
      }
      const msg = (createErr?.message ?? "").toLowerCase();
      if (msg.includes("already") || msg.includes("registered") || msg.includes("exists")) {
        return jsonResponse({ ok: false, error: "EMAIL_TAKEN" });
      }
      console.error("createUser failed:", createErr?.message);
      return jsonResponse({ ok: false, error: "SIGNUP_FAILED" });
    }

    // Audit the code redemption (best-effort — the account already exists).
    // Email invites are their own audit trail: the invites row is now activated.
    if (claimedCodeId) {
      await admin.from("code_redemptions").insert({
        code_id: claimedCodeId,
        code,
        user_id: created.user.id,
        email,
      });
    }

    return jsonResponse({ ok: true });
  } catch (err) {
    console.error(err);
    return jsonResponse({ ok: false, error: "INTERNAL" }, 500);
  }
});
