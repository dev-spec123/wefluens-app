/**
 * Group @-mention helpers. Mentions are stored literally in the message body as
 * `@<displayName>` (or an "@all" token). We detect whether a message targets the
 * current user so we can surface a highlighted "@me" indicator.
 */

// "@everyone" tokens across the app's languages — a message containing any of
// these mentions the whole group, so it targets every member.
export const ALL_MENTION_TOKENS = ['@全体成员', '@Everyone', '@Todos'];

/** True when `body` @-mentions everyone. */
export function isAllMention(body: string): boolean {
  return !!body && ALL_MENTION_TOKENS.some((tok) => body.includes(tok));
}

/** True when `body` @-mentions me by name, or @-mentions everyone. */
export function messageMentionsMe(body: string, myName: string | null | undefined): boolean {
  if (!body) return false;
  if (isAllMention(body)) return true;
  return !!myName && myName.length > 0 && body.includes(`@${myName}`);
}
