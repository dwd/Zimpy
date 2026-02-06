# Wimsy

Wimsy is a cross-platform XMPP client built with Flutter, focused on modern
server support and TLS-first connections.

## Features

- Direct TLS (XEP-0368) and StartTLS support with SRV discovery
- Login with full JID + resource (custom host/port supported)
- Roster sync and manual JID chat creation
- One-to-one chat view with message history per contact (MAM-aware backfill)
- Multi-User Chat bookmarks and join/leave
- Presence state + custom status message
- Native notifications for incoming messages (desktop + Android)
- Console protocol traces for send/receive (when enabled)

## Platform Support

- Linux, macOS, Windows, Android, iOS, Web

## Notes

- `xmpp_stone` is vendored locally in `vendor/xmpp_stone` to enforce StartTLS
  and surface XML traffic during debugging.
- macOS builds that use `flutter_secure_storage` require the `keychain-access-groups`
  entitlement (not `com.apple.security.keychain-access-groups`) to avoid `-34018`.
