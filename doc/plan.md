## Plan
- Keep this plan updated throughout the work and ensure this instruction remains in the plan.
- Current status: StartTLS now negotiates; patched xmpp_stone secure socket to swap the underlying socket after TLS. Next step is to re-run `flutter run` and confirm auth succeeds.
- Review current Flutter example app and identify required XMPP client capabilities for modern servers. (done)
- Add XMPP dependency and build a connection/service layer (login, TLS, roster, messages, presence). (done)
- Replace UI with a cross-platform client flow (connect, roster, chat, status). (done)
- Wire UI to service layer, handle errors, and provide minimal testing/verification notes. (done)
