# Sent Messages not shown in chat window

Sent messages have stopped showing up in the chat window.

So that's weird - started after the mam-dupe bugs was fixed, I think.

## Notes
- Likely cause: dedupe logic treats empty stanza IDs as real IDs. xmpp_stone sets `stanzaId` to `''` for non-archived messages, so the first message with an empty stanza-id blocks all subsequent ones.
- Potential solutions: ignore empty stanza IDs during dedupe, or change xmpp_stone to use null for missing stanza IDs; alternatively dedupe with message-id when present.
- Final solution: only dedupe on non-empty `mamId`/`stanzaId`.
