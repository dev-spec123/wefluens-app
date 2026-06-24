/** Time + color formatting helpers shared across the app. */

/** Short clock time, locale-aware (e.g. "9:05 AM"). */
export function clockTime(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  return d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit' });
}

/** Relative time for the inbox: clock today, "Yesterday", else short date. */
export function relativeTime(iso: string | null | undefined): string {
  if (!iso) return '';
  const d = new Date(iso);
  if (isNaN(d.getTime())) return '';
  const now = new Date();
  const sameDay = d.toDateString() === now.toDateString();
  if (sameDay) return clockTime(iso);
  const yesterday = new Date(now);
  yesterday.setDate(now.getDate() - 1);
  if (d.toDateString() === yesterday.toDateString()) return 'Yesterday';
  const sameYear = d.getFullYear() === now.getFullYear();
  return d.toLocaleDateString(undefined, sameYear ? { month: 'short', day: 'numeric' } : { year: 'numeric', month: 'short', day: 'numeric' });
}

/** Parse a JSON int-array color string like "[16726637,16751706]" into two hex colors. */
export function parseColors(raw: string | null | undefined): [string, string] {
  const fallback: [string, string] = ['#FF4D6D', '#FF9A5A'];
  if (!raw) return fallback;
  try {
    const arr = JSON.parse(raw) as number[];
    if (!Array.isArray(arr) || arr.length < 2) return fallback;
    const toHex = (n: number) => '#' + (n & 0xffffff).toString(16).padStart(6, '0').toUpperCase();
    return [toHex(arr[0]), toHex(arr[1])];
  } catch {
    return fallback;
  }
}

/** Human file size (e.g. "1.2 MB"). */
export function fileSizeLabel(bytes: number | null | undefined): string {
  if (!bytes || bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  let v = bytes;
  let i = 0;
  while (v >= 1024 && i < units.length - 1) { v /= 1024; i++; }
  return `${v.toFixed(v < 10 && i > 0 ? 1 : 0)} ${units[i]}`;
}
