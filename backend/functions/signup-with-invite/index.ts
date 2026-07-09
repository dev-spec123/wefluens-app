// signup-with-invite — public. The ONLY way to create an account once invite-only
// is enabled (public auth.signUp is disabled in Auth settings). Validates an
// invite code, creates an email-confirmed account via the admin API, consumes one
// use of the code, and records the redemption. The client then signs in normally.
//
// Code claiming is atomic (claim_invite_code does a conditional UPDATE), so a
// single-use code can't be redeemed twice by concurrent requests. If account
// creation fails after a claim, we release the use (best-effort).

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
    if (!code) {
      return jsonResponse({ ok: false, error: "CODE_REQUIRED" });
    }

    const admin = createAdminClient();

    // Atomically claim one use. Returns the code id, or null if the code is
    // invalid / revoked / expired / exhausted.
    const { data: codeId, error: claimErr } = await admin.rpc("claim_invite_code", { p_code: code });
    if (claimErr) {
      console.error("claim_invite_code failed:", claimErr.message);
      return jsonResponse({ ok: false, error: "SERVER_ERROR" });
    }
    if (!codeId) {
      return jsonResponse({ ok: false, error: "INVALID_CODE" });
    }

    // Create the account, already email-confirmed (server-trusted).
    const { data: created, error: createErr } = await admin.auth.admin.createUser({
      email,
      password,
      email_confirm: true,
    });

    if (createErr || !created?.user) {
      // Give the use back so a transient failure doesn't burn the code.
      await admin.rpc("release_invite_code", { p_code: code });
      const msg = (createErr?.message ?? "").toLowerCase();
      if (msg.includes("already") || msg.includes("registered") || msg.includes("exists")) {
        return jsonResponse({ ok: false, error: "EMAIL_TAKEN" });
      }
      console.error("createUser failed:", createErr?.message);
      return jsonResponse({ ok: false, error: "SIGNUP_FAILED" });
    }

    // Audit the redemption (best-effort — the account already exists).
    await admin.from("code_redemptions").insert({
      code_id: codeId,
      code,
      user_id: created.user.id,
      email,
    });

    return jsonResponse({ ok: true });
  } catch (err) {
    console.error(err);
    return jsonResponse({ ok: false, error: "INTERNAL" }, 500);
  }
});
