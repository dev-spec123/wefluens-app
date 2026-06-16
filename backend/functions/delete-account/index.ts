// delete-account — permanently deletes the signed-in user's auth account and
// associated data (Apple 5.1.1 in-app account deletion).
//
// Security model: the caller is authenticated via their own JWT (requireUser).
// We never trust a user-supplied id — the account to delete is ALWAYS the
// authenticated caller's. The service-role key (never in the app bundle) is used
// to remove the data the user cannot delete under RLS, then the auth user itself.

import {
  AuthError,
  corsHeaders,
  createAdminClient,
  jsonResponse,
  requireUser,
} from "../_shared/auth.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user } = await requireUser(req);
    const admin = createAdminClient();
    const uid = user.id;

    // Best-effort removal of associated rows. Order is chosen so dependent rows
    // go first; any individual failure is logged but never aborts the deletion.
    const cleanup: Array<Promise<unknown>> = [
      admin.from("reports").delete().eq("reporter_id", uid),
      admin.from("blocks").delete().or(`blocker_id.eq.${uid},blocked_id.eq.${uid}`),
      admin.from("friendships").delete().or(`user_id.eq.${uid},friend_id.eq.${uid}`),
      admin.from("friend_requests").delete().or(`from_user_id.eq.${uid},to_user_id.eq.${uid}`),
      admin.from("dm_messages").delete().or(`sender_id.eq.${uid},recipient_id.eq.${uid}`),
      admin.from("group_messages").delete().eq("sender_id", uid),
      admin.from("group_members").delete().eq("user_id", uid),
      admin.from("message_deletions").delete().eq("user_id", uid),
      admin.from("dm_clears").delete().eq("user_id", uid),
      admin.from("group_clears").delete().eq("user_id", uid),
      admin.from("conversation_hides").delete().eq("user_id", uid),
    ];
    for (const op of cleanup) {
      try {
        await op;
      } catch (e) {
        console.error("delete-account cleanup step failed", (e as Error)?.message);
      }
    }

    // Remove the profile row, then the auth user itself.
    await admin.from("profiles").delete().eq("id", uid);
    const { error } = await admin.auth.admin.deleteUser(uid);
    if (error) throw error;

    return jsonResponse({ ok: true });
  } catch (err) {
    if (err instanceof AuthError) {
      return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
    }
    console.error("delete-account failed", (err as Error)?.message);
    return jsonResponse({ ok: false, error: "INTERNAL" }, 500);
  }
});
