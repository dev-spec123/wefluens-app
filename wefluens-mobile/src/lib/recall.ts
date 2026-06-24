/**
 * Message-recall helpers (撤回), shared by 1:1 and group chats.
 *
 * The server enforces a hard 2-minute window + "sender only" rule; these mirror
 * that on the client so the Recall action hides once expired and a failure maps
 * to a specific, localized message instead of one generic toast.
 */

const RECALL_WINDOW_MS = 120_000; // 2 minutes

/** True while a message is still within its 2-minute recall window. Messages
 *  without a timestamp (legacy/import) return true and let the server decide. */
export function withinRecallWindow(m: { createdAt: string | null }): boolean {
  if (!m.createdAt) return true;
  return Date.now() - new Date(m.createdAt).getTime() <= RECALL_WINDOW_MS;
}

export type RecallErrorKey =
  | 'chatRecallExpired'
  | 'chatRecallAlreadyRecalled'
  | 'chatRecallForbidden'
  | 'chatRecallFailed';

/** Maps a server recall error to a specific i18n key (falls back to generic). */
export function recallErrorKey(err: unknown): RecallErrorKey {
  const raw = String((err as any)?.message ?? err ?? '').toUpperCase();
  if (raw.includes('EXPIRED')) return 'chatRecallExpired';
  if (raw.includes('ALREADY_RECALLED')) return 'chatRecallAlreadyRecalled';
  if (raw.includes('FORBIDDEN')) return 'chatRecallForbidden';
  return 'chatRecallFailed';
}
