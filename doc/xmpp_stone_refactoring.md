# xmpp_stone Refactoring Notes

## Testability quick wins

- Extract MUC message parsing into a pure function (e.g., `MucMessage? parseGroupMessage(MessageStanza)`), and unit-test it without a live `Connection`.
- Inject socket/websocket factories into `XmppWebsocketIo` to test connect/secure paths without real network access.
- Isolate stream feature parsing (SASL/SM/TLS) into pure parsers to test negotiation logic without a live server.

## Coverage gaps to target next

- Connection negotiation state machine and error paths.
- Stream management ack handling and reconnection logic.
- XML parsing for roster, presence, and MAM results (edge cases, missing fields).
- MUC presence updates (self-join, leave, occupant deltas).
