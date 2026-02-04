## Plan
- Keep this plan updated throughout the work and ensure this instruction remains in the plan.
- Current status: MUC (XEP-0045) support is implemented end-to-end with basic tests. Next step is to run tests and walk the manual MUC checklist.

## Local Data Strategy (implemented)
- Storage: Hive encrypted box now stores chat history, roster cache, settings, and the XMPP account password.
- Encryption: Hive AES encryption with a 256-bit key derived via PBKDF2.
- Key handling: per-device salt stored in flutter_secure_storage; PIN unlocks the key and box.
- Unlock flow: PIN gate on launch; account data + roster + messages are loaded after unlock.
- Review current Flutter example app and identify required XMPP client capabilities for modern servers. (done)
- Add XMPP dependency and build a connection/service layer (login, TLS, roster, messages, presence). (done)
- Replace UI with a cross-platform client flow (connect, roster, chat, status). (done)
- Wire UI to service layer, handle errors, and provide minimal testing/verification notes. (done)
