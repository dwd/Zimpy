# MAM Sync Behavior

This document describes how Wimsy syncs Message Archive Management (MAM) history, how it de-dupes messages, and when fetches occur.

## When MAM requests happen

- Global sync on connect: a global MAM query is issued when the connection becomes ready (rate-limited to once every 30 seconds).
- Per-conversation only when empty: MAM requests are issued when a 1:1 chat is opened and there are no cached messages for that JID.
- Requests are rate-limited per JID: a 1:1 backfill for the same JID will not run more than once every 30 seconds.
- Rooms: joining a room triggers a MAM request for recent history in that room.

## Initial fetch strategy (per conversation)

When a chat is opened and there are no cached messages, Wimsy queries MAM for that JID with `max = 50`.
The query uses the `with` field set to the JID for the chat and `before = ''` (most recent page).

If there are already cached messages, MAM is not queried for that JID on open.

## Initial global fetch strategy

On connection ready, Wimsy primes the archive with a global fetch:

- 1:1 messages: if there is any cached MAM ID, request messages after the newest one (`max = 50`) and also request the most recent page (`before = ''`, `max = 50`).
- 1:1 messages: if there is no cached MAM ID, request only the most recent page (`before = ''`, `max = 50`).
- Bookmarked rooms: query most recent 25 messages per bookmarked room JID (`before = ''`).

## De-duplication strategy

Wimsy de-dupes messages on insertion using identifiers provided by the server:

- If a MAM `result` has an ID (`mamId`), it is a de-dupe key.
- If a `stanza-id` is present, it is also a de-dupe key.
- If an incoming message has a matching `messageId`, Wimsy merges missing `mamId`/`stanza-id` onto the existing message.
- Empty IDs are ignored (they are not valid keys).

This prevents duplicate messages when:
- MAM backfill overlaps with previously cached history.
- Carbons or live messages are later delivered as MAM results.

## Sent messages vs MAM copies

- Sent messages appear immediately via the local chat flow.
- When the server later returns the same message via MAM, Wimsy merges `mamId`/`stanza-id` onto the existing message where possible.
- Merge uses the stanza `id` when available; otherwise it falls back to a short body/from/to/time heuristic.

## Paging / older history

Per-conversation paging is not automatic beyond the initial 50 for empty chats.

For global sync after reconnect:

- If there is a latest cached 1:1 MAM ID, Wimsy requests all messages after it (`max = 50`).
- When a cached MAM ID exists, Wimsy starts a background backfill loop that requests older pages using `before = oldestSeenMamId` (`max = 50`) every ~2 seconds.
- The loop stops when the oldest known MAM ID stops changing (i.e., no older messages arrive).

## Notes and limitations

- Global MAM sync excludes bookmarked rooms when calculating newest/oldest MAM IDs.
- Bookmarked rooms are queried for recent messages on connect and when the room is joined.
