# XEP-0479 Compliance Shortfalls (Client Focus)

Source requirements: XEP-0479 (Compliance Suites 2023).

This is a client-side gap list for the Core, Web, and IM suites. Items are ordered to reach Client first, then Advanced Client, within each suite. (Server requirements are out of scope.)

## Core Suite

Client: appears met (RFC 6120 core, TLS, XEP-0030, XEP-0115). No shortfalls noted.

Advanced Client: appears met (Direct TLS XEP-0368, PEP XEP-0163). No shortfalls noted.

## Web Suite

Client shortfalls (must also satisfy Core Client):
- XEP-0206 (XMPP Over BOSH) — required as part of “Web Connection Mechanisms”.
- XEP-0156 (Connection Mechanism Discovery).

Advanced Client shortfalls (must also satisfy Core Advanced Client + Web Client):
- No additional items beyond Web Client shortfalls.

Status: Web Client and Advanced Web Client are not met until the above are implemented.

## IM Suite

Client shortfalls (must also satisfy Core Client):
- XEP-0245 (/me Command).
- XEP-0249 (Direct MUC Invitations).
- XEP-0363 (HTTP File Upload).

Status: IM Client is not met until the above are implemented.

Advanced Client shortfalls (must also satisfy IM Client):
- XEP-0191 (Blocking Command).
- XEP-0398 + XEP-0153 (User Avatar Compatibility).
- XEP-0410 (MUC Self-Ping / Schrödinger's Chat).
- XEP-0223 (Persistent Storage of Private Data via PubSub).
- XEP-0049 (Private XML Storage).
- XEP-0308 (Last Message Correction).
- XEP-0234 + XEP-0261 (Jingle File Transfer + Jingle IBB transport).
- XEP-0048 (Bookmark Storage) if legacy bookmark storage is not fully supported.

Status: IM Advanced Client is not met until the above are implemented.
