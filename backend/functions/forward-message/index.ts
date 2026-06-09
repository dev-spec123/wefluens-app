// forward-message — forwards one chat message (text / image / video / file) to
// one or more conversations (1:1 friends and/or groups).
//
// Security model (dual permission check, enforced server-side):
//   1. SOURCE read  — the caller must be allowed to READ the source message
//      (a DM participant, or a member of the source group). Without this a user
//      could forward a message they were never able to see.
//   2. TARGET write — for a friend target the caller must be friends with them;
//      for a group target the caller must be a member. The existing send RPCs
//      (send_dm / send_dm_media / send_dm_attachment / send_group_message /
//      send_group_attachment) re-validate this, so it is enforced twice.
//
// Media is NOT re-uploaded: the original private `chat-media` object is copied
// server-side (service role) into the target's folder, then the existing send
// RPC stores that new path. Per product decision: an image forward keeps its
// caption; file/video forwards drop the caption. Sends run through the caller's
// own JWT so `auth.uid()` inside the SECURITY DEFINER send functions resolves to
// the caller (existing functions are reused untouched).

import {
  AuthError,
  corsHeaders,
  createAdminClient,
  jsonResponse,
  requireUser,
} from "../_shared/auth.ts";

interface ForwardSource {
  kind?: "dm" | "group";
  messageId?: string;
}

interface ForwardTarget {
  kind?: "friend" | "group";
  id?: string;
}

interface ForwardBody {
  source?: ForwardSource;
  targets?: ForwardTarget[];
}

interface SourceMessage {
  message_type: string | null;
  body: string | null;
  image_url: string | null;
  image_width: number | null;
  image_height: number | null;
  file_name: string | null;
  file_size: number | null;
  file_mime: string | null;
}

type AdminClient = ReturnType<typeof createAdminClient>;

/** Lowercase file extension of a storage object path (empty when none). */
function extensionOf(path: string): string {
  const base = path.split("/").pop() ?? "";
  const dot = base.lastIndexOf(".");
  return dot > 0 ? base.slice(dot + 1).toLowerCase() : "";
}

/** Builds a fresh `{prefix}/{uuid}.{ext}` destination path inside chat-media. */
function destinationPath(prefix: string, sourcePath: string): string {
  const ext = extensionOf(sourcePath);
  const name = crypto.randomUUID().toLowerCase();
  return ext ? `${prefix}/${name}.${ext}` : `${prefix}/${name}`;
}

async function isGroupMember(
  admin: AdminClient,
  groupId: string,
  uid: string,
): Promise<boolean> {
  const { data } = await admin
    .from("group_members")
    .select("user_id")
    .eq("group_id", groupId)
    .eq("user_id", uid)
    .maybeSingle();
  return !!data;
}

async function areFriends(
  admin: AdminClient,
  a: string,
  b: string,
): Promise<boolean> {
  const { data } = await admin
    .from("friendships")
    .select("user_id")
    .eq("user_id", a)
    .eq("friend_id", b)
    .maybeSingle();
  return !!data;
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { user, supabase: userClient } = await requireUser(req);
    const admin = createAdminClient();
    const uid = user.id;

    const body = (await req.json().catch(() => ({}))) as ForwardBody;
    const source = body.source;
    const targets = Array.isArray(body.targets) ? body.targets : [];

    if (!source?.kind || !source?.messageId || targets.length === 0) {
      return jsonResponse({ ok: false, error: "BAD_REQUEST" }, 400);
    }

    // ---- 1. Load + authorize the SOURCE message (caller must be able to read it).
    let msg: SourceMessage | null = null;
    if (source.kind === "dm") {
      const { data } = await admin
        .from("dm_messages")
        .select(
          "sender_id,recipient_id,message_type,body,image_url,image_width,image_height,file_name,file_size,file_mime",
        )
        .eq("id", source.messageId)
        .maybeSingle();
      if (!data) return jsonResponse({ ok: false, error: "SOURCE_NOT_FOUND" }, 404);
      if (data.sender_id !== uid && data.recipient_id !== uid) {
        return jsonResponse({ ok: false, error: "FORBIDDEN_SOURCE" }, 403);
      }
      msg = data as SourceMessage;
    } else if (source.kind === "group") {
      const { data } = await admin
        .from("group_messages")
        .select(
          "group_id,sender_id,message_type,body,image_url,image_width,image_height,file_name,file_size,file_mime",
        )
        .eq("id", source.messageId)
        .maybeSingle();
      if (!data) return jsonResponse({ ok: false, error: "SOURCE_NOT_FOUND" }, 404);
      if (!(await isGroupMember(admin, data.group_id, uid))) {
        return jsonResponse({ ok: false, error: "FORBIDDEN_SOURCE" }, 403);
      }
      msg = data as SourceMessage;
    } else {
      return jsonResponse({ ok: false, error: "BAD_SOURCE_KIND" }, 400);
    }

    const type = msg.message_type ?? "text";
    const isMedia = type === "image" || type === "video" || type === "file";
    const sourcePath = msg.image_url;
    if (isMedia && !sourcePath) {
      return jsonResponse({ ok: false, error: "SOURCE_MEDIA_MISSING" }, 400);
    }
    // Image forwards keep their caption; file/video forwards drop it.
    const caption = type === "image" ? (msg.body ?? "") : "";

    const results: Array<{ id: string; kind: string; ok: boolean; error?: string }> = [];

    // ---- 2. For each target: authorize WRITE, copy media (if any), send.
    for (const t of targets) {
      const targetId = t.id ?? "";
      try {
        if (!targetId || (t.kind !== "friend" && t.kind !== "group")) {
          results.push({ id: targetId, kind: String(t.kind), ok: false, error: "BAD_TARGET" });
          continue;
        }

        if (t.kind === "friend") {
          if (!(await areFriends(admin, uid, targetId))) {
            results.push({ id: targetId, kind: t.kind, ok: false, error: "NOT_FRIENDS" });
            continue;
          }
          if (type === "text") {
            const { error } = await userClient.rpc("send_dm", {
              p_other: targetId,
              p_body: msg.body ?? "",
            });
            if (error) throw error;
          } else {
            // Resolve (or create) the thread so we know the folder to copy into.
            const { data: threadRaw, error: tErr } = await userClient.rpc(
              "get_or_create_thread",
              { p_other: targetId },
            );
            if (tErr) throw tErr;
            const dest = destinationPath(String(threadRaw), sourcePath!);
            const { error: cErr } = await admin.storage
              .from("chat-media")
              .copy(sourcePath!, dest);
            if (cErr) throw cErr;
            if (type === "image") {
              const { error } = await userClient.rpc("send_dm_media", {
                p_other: targetId,
                p_image_url: dest,
                p_caption: caption,
                p_width: msg.image_width ?? 0,
                p_height: msg.image_height ?? 0,
              });
              if (error) throw error;
            } else {
              const { error } = await userClient.rpc("send_dm_attachment", {
                p_other: targetId,
                p_type: type,
                p_path: dest,
                p_caption: caption,
                p_file_name: msg.file_name,
                p_file_size: msg.file_size,
                p_file_mime: msg.file_mime,
              });
              if (error) throw error;
            }
          }
          results.push({ id: targetId, kind: t.kind, ok: true });
        } else {
          // group target
          if (!(await isGroupMember(admin, targetId, uid))) {
            results.push({ id: targetId, kind: t.kind, ok: false, error: "NOT_MEMBER" });
            continue;
          }
          if (type === "text") {
            const { error } = await userClient.rpc("send_group_message", {
              p_group: targetId,
              p_body: msg.body ?? "",
            });
            if (error) throw error;
          } else {
            const dest = destinationPath(targetId, sourcePath!);
            const { error: cErr } = await admin.storage
              .from("chat-media")
              .copy(sourcePath!, dest);
            if (cErr) throw cErr;
            const { error } = await userClient.rpc("send_group_attachment", {
              p_group: targetId,
              p_type: type,
              p_path: dest,
              p_caption: caption,
              p_file_name: type === "file" ? msg.file_name : null,
              p_file_size: type === "file" ? msg.file_size : null,
              p_file_mime: type === "file" ? msg.file_mime : null,
              p_width: msg.image_width,
              p_height: msg.image_height,
            });
            if (error) throw error;
          }
          results.push({ id: targetId, kind: t.kind, ok: true });
        }
      } catch (e) {
        console.error("forward target failed", targetId, (e as Error)?.message);
        results.push({ id: targetId, kind: String(t.kind), ok: false, error: "FORWARD_FAILED" });
      }
    }

    const forwarded = results.filter((r) => r.ok).length;
    return jsonResponse({
      ok: forwarded > 0,
      forwarded,
      failed: results.length - forwarded,
      results,
    });
  } catch (err) {
    if (err instanceof AuthError) {
      return jsonResponse({ ok: false, error: "UNAUTHORIZED" }, 401);
    }
    console.error(err);
    return jsonResponse({ ok: false, error: "INTERNAL" }, 500);
  }
});
