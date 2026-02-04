# MAM duplication

When opening a chat, MAM fetches messages to backfill the chat as needed. However, currently, all messages seem to be fetched. I suspect we're fetching simply the latest 50 messages without considering what messages exist in the cache.

The proper approach should be to fetch all messages after the latest message in the cache - if we have any messages in the cache at all.

Then, backfill should occur by locating the oldest message in the cache (if we have any) and searching for the 50 before it - using no "before" message if none yet exists.

## Resolution
- Use `afterId` based on the latest cached MAM id to fetch newer messages.
- Use `beforeId` based on the oldest cached MAM id to backfill older messages.
- Add MAM/stanza-id dedupe on insert to prevent double entries.
