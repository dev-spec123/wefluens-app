-- migration-recall-constraints.sql
-- Makes message recall actually work (run AFTER functions-delete-recall-clear.sql).
--
-- recall_message clears a message's content (body='', media nulled) so a captured
-- screenshot reveals nothing. But the original CHECK constraints rejected such a row:
--   * dm_messages_body_len     required a TEXT body to be >= 1 char
--   * dm_messages_media_present required a non-text row to keep a media path
--   * group_messages_media_present  same, for groups
-- A recalled message satisfies none of these, so EVERY recall failed. (The live
-- recall_message also wrongly set body = NULL, which additionally violated the
-- NOT NULL body column — fixed by clearing with body = '' in the function file.)
--
-- Fix: exempt recalled rows (recalled_at IS NOT NULL) from those CHECKs. Relaxing a
-- CHECK is safe + additive: every existing non-recalled row still satisfies the
-- original predicate, so ADD CONSTRAINT validates without touching data.
--
-- Idempotent: drop-if-exists then add.

begin;

-- dm_messages: a TEXT body must be 1..4000 chars — unless the row was recalled
alter table public.dm_messages drop constraint if exists dm_messages_body_len;
alter table public.dm_messages add constraint dm_messages_body_len
  check (
    recalled_at is not null
    or (
      char_length(body) <= 4000
      and (message_type <> 'text' or char_length(body) >= 1)
    )
  );

-- dm_messages: a non-text row must carry a media path — unless recalled
alter table public.dm_messages drop constraint if exists dm_messages_media_present;
alter table public.dm_messages add constraint dm_messages_media_present
  check (
    recalled_at is not null
    or message_type = 'text'
    or (image_url is not null and char_length(image_url) > 0)
  );

-- group_messages: a non-text row must carry a media path — unless recalled
-- (group_messages_body_len is already `char_length(body) <= 4000` with no minimum,
--  so an empty recalled body is fine there; no change needed.)
alter table public.group_messages drop constraint if exists group_messages_media_present;
alter table public.group_messages add constraint group_messages_media_present
  check (
    recalled_at is not null
    or message_type = 'text'
    or image_url is not null
  );

commit;
