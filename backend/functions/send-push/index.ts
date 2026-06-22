// send-push — STUB. The whole push pipeline is BUILT here except the final APNs
// HTTPS call, which is marked TODO(APNs) below. It cannot be completed in this
// repo because it needs an Apple Developer account we do not have:
//
//   What's missing (a developer WITH an Apple Developer account fills this in):
//     1. An APNs Auth Key (.p8) + its Key ID + the Apple Team ID + the app's
//        bundle id (com.…WeConnect). Store them in `app_secrets`:
//          APNS_KEY_P8, APNS_KEY_ID, APNS_TEAM_ID, APNS_BUNDLE_ID
//          APNS_ENV = 'sandbox' | 'production'
//     2. Replace the TODO(APNs) block with: build an ES256 JWT signed with the
//        .p8 key, then POST to
//          https://api.push.apple.com/3/device/<token>   (production)
//          https://api.sandbox.push.apple.com/3/device/<token>  (sandbox)
//        with header `apns-topic: <bundle id>` and the apns payload below.
//     3. Enable the Push Notifications capability on the App ID + the app target.
//
//   Everything else — token lookup, opt-out filtering, payload shape, the call
//   site (migration-push-triggers.sql) — is already in place. See PLAN.md
//   ("Push notifications") for the full hand-off checklist.
//
// Until then this function is a no-op that returns { ok: true, delivered: 0,
// stub: true } and logs exactly what it WOULD have sent, so it can be wired and
// observed end-to-end without ever silently failing.

import {
  corsHeaders,
  createAdminClient,
  jsonResponse,
} from "../_shared/auth.ts";

// One push to send. `userIds` are recipients; we expand them to device tokens and
// drop anyone who turned notifications off. `data` rides along as custom keys so
// the app can deep-link (e.g. { kind: "dm", threadId } / { kind: "friend_request" }).
interface PushBody {
  userIds?: string[];
  title?: string;
  body?: string;
  data?: Record<string, string>;
}

// Internal guard: callers (DB triggers via pg_net, or a future worker) must send
// `x-internal-secret` matching PUSH_INTERNAL_SECRET from app_secrets/env. Keeps
// the endpoint from being invokable by ordinary clients with just an anon key.
async function assertInternal(
  req: Request,
  admin: ReturnType<typeof createAdminClient>,
): Promise<boolean> {
  const provided = req.headers.get("x-internal-secret") ?? "";
  let expected = (Deno.env.get("PUSH_INTERNAL_SECRET") ?? "").trim();
  if (!expected) {
    const { data } = await admin
      .from("app_secrets")
      .select("value")
      .eq("key", "PUSH_INTERNAL_SECRET")
      .maybeSingle();
    expected = ((data?.value as string) ?? "").trim();
  }
  return expected.length > 0 && provided === expected;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const admin = createAdminClient();

  if (!(await assertInternal(req, admin))) {
    return jsonResponse({ ok: false, error: "FORBIDDEN" }, 403);
  }

  const payload = (await req.json().catch(() => ({}))) as PushBody;
  const userIds = (payload.userIds ?? []).filter((s) => typeof s === "string");
  if (userIds.length === 0) {
    return jsonResponse({ ok: false, error: "NO_RECIPIENTS" });
  }

  // Respect the per-user opt-out: only users with notifications_enabled = true.
  const { data: optedIn } = await admin
    .from("profiles")
    .select("id")
    .in("id", userIds)
    .eq("notifications_enabled", true);
  const deliverableUserIds = (optedIn ?? []).map((r: { id: string }) => r.id);
  if (deliverableUserIds.length === 0) {
    return jsonResponse({ ok: true, delivered: 0, stub: true, reason: "all_opted_out" });
  }

  // Expand to device tokens.
  const { data: tokenRows } = await admin
    .from("device_tokens")
    .select("token")
    .in("user_id", deliverableUserIds);
  const tokens = (tokenRows ?? []).map((r: { token: string }) => r.token);

  // The APNs payload we would deliver to each token.
  const apnsPayload = {
    aps: {
      alert: { title: payload.title ?? "Wefluens", body: payload.body ?? "" },
      sound: "default",
      badge: 1,
    },
    ...(payload.data ?? {}),
  };

  // ── TODO(APNs): replace this block with the real send ──────────────────────
  // for (const token of tokens) {
  //   const jwt = await buildApnsJwt(keyP8, keyId, teamId);     // ES256
  //   await fetch(`${apnsHost}/3/device/${token}`, {
  //     method: "POST",
  //     headers: { authorization: `bearer ${jwt}`, "apns-topic": bundleId,
  //                "apns-push-type": "alert" },
  //     body: JSON.stringify(apnsPayload),
  //   });
  // }
  // ───────────────────────────────────────────────────────────────────────────
  console.log(
    `[send-push STUB] would deliver to ${tokens.length} token(s):`,
    JSON.stringify(apnsPayload),
  );

  return jsonResponse({
    ok: true,
    stub: true,
    delivered: 0,
    wouldDeliverTo: tokens.length,
  });
});
