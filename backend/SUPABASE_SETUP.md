# Supabase setup — "Full Completion" feature pass

Runbook for whoever has Supabase access. Applying this lights up the new app
features: **Top Talent** directory, **Brands** directory, cloud-synced
**Favorites**, in-app **Support** tickets, the **Activity Status / Data Sharing**
privacy controls, and the **Push Notifications** opt-in (delivery is stubbed —
see step 4).

Everything fails gracefully if skipped: the app won't crash, the related feature
just stays empty/inert until its step is done. Apply the steps in order.

Project ref: `zlyufsfbzssjseprkuvd` — **confirm the dashboard you're in matches this
ref** before running anything (Settings → General → Reference ID). This project's
`profiles` table already matches the app (`name`, `handle`, `avatar_url`,
`followers`, `is_admin`, ...). A different project with a `full_name`/
`creator_handle` schema also exists — do **not** run these there.

---

## 1. Run the schema migration  *(required)*

Dashboard → **SQL Editor** → New query → paste the full contents of
**`backend/functions/migration-full-completion.sql`** → **Run**.

Creates:
- profile preference columns: `notifications_enabled`, `activity_status`, `data_sharing`
- tables (with RLS): `device_tokens`, `favorites`, `support_tickets`
- function: `browse_top_talent()` (the Top Talent directory)

Idempotent — safe to re-run.

> If it errors on a column of `friendships` / `friend_requests` / `blocks`, the
> live schema uses different column names than the app code implied. Note the
> error and have the developer adjust the `EXISTS` clauses in `browse_top_talent`
> before re-running. Names assumed: `friendships(user_id, friend_id)`,
> `friend_requests(from_user_id, to_user_id, status)`, `blocks(blocker_id, blocked_id)`.

**Verify:** in SQL Editor run `select * from public.browse_top_talent(5);` while
logged in as any user — it should return rows (or none) without error.

---

## 2. Run the push-trigger migration  *(required, but dormant)*

Same place — paste **`backend/functions/migration-push-triggers.sql`** → **Run**.

Adds friend-request notification triggers + the `notify_push()` helper. It is a
**no-op until push is fully configured** (step 4), so running it now is safe and
changes nothing visible.

---

## 3. Deploy the edge functions  *(submit-support-ticket = required for Support)*

Deploy these the same way the existing functions (`invite-user`, `delete-account`)
are deployed — they sit in the same `backend/functions/` folder and share the
`_shared/auth.ts` helper.

| Function | Folder | Needed for |
|---|---|---|
| `submit-support-ticket` | `backend/functions/submit-support-ticket/` | In-app Contact Support form (saves ticket + emails support@) |
| `send-push` | `backend/functions/send-push/` | Push pipeline (STUB — only logs for now; deploy so it's wired) |

CLI form, if used:
```
supabase functions deploy submit-support-ticket --project-ref zlyufsfbzssjseprkuvd
supabase functions deploy send-push --project-ref zlyufsfbzssjseprkuvd
```

`submit-support-ticket` reuses the existing **Resend** email config from the
`app_secrets` table (same as `invite-user`). Tickets email `support@wefluens.com`
by default; to redirect, add an `app_secrets` row with key `RESEND_SUPPORT_TO`.

**Verify:** in the app, Me → Contact Support → send a test message. It should
report success and a row should appear in `public.support_tickets`.

---

## 4. Push notification delivery  *(LATER — needs an Apple Developer account)*

The app already requests permission and registers device tokens into
`device_tokens`; the server **send** path is a deliberate stub because it needs an
Apple Developer account. When that's available, the developer:

1. Enables the Push Notifications capability on the App ID + `WeConnect` target;
   creates an APNs Auth Key (`.p8`) + notes Key ID, Team ID, bundle id.
2. Adds to `app_secrets`: `APNS_KEY_P8`, `APNS_KEY_ID`, `APNS_TEAM_ID`,
   `APNS_BUNDLE_ID`, `APNS_ENV` (`sandbox`/`production`), `PUSH_INTERNAL_SECRET`,
   `EDGE_BASE_URL` (`https://zlyufsfbzssjseprkuvd.supabase.co/functions/v1`).
3. Runs `create extension if not exists pg_net;`.
4. Replaces the `TODO(APNs)` block in `backend/functions/send-push/index.ts` with
   the real APNs call (instructions are in that file's header) and redeploys.
5. Optionally completes the message-push triggers at the bottom of
   `migration-push-triggers.sql`.

No iOS changes are needed after that — token registration and the opt-in toggle
are already live.
