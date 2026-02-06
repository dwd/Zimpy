# Background Session Plan (Wimsy)

## Goal
Keep the XMPP session alive when the main window is closed on platforms that can support it (desktop + Android), reconnecting automatically as needed. Avoid breaking existing UX and keep battery/OS policy in mind.

## Feasibility Summary
- Linux/macOS/Windows: Feasible. Closing the main window should not terminate the process. Keep the XMPP connection in memory, run reconnect logic, and provide a tray/menu or explicit Quit action. Beware of OS resource policies and expectations.
- Android: Feasible with a foreground service (persistent notification). Background execution without a foreground service is increasingly restricted and unreliable.
- iOS: Not feasible to keep a persistent XMPP socket in the background outside of VOIP/Push-driven constraints; treat iOS as not supported for always-on background connections.
- Web: Not applicable for background keepalive beyond browser tab lifecycle; ignore.

## Current State (Observed)
- App appears to exit when the main window is closed on desktop (default Flutter runner behavior).
- XMPP connection lives in `XmppService` and is owned by the running process; no background service or tray integration exists.

## Strategy Overview
1. Desktop: convert “window close” to “hide to tray / keep running” and add explicit Quit.
2. Android: introduce a foreground service that holds the connection and reconnects; keep a persistent notification.
3. XMPP reconnect: ensure reconnection logic is centralized and tolerant of suspend/resume.
4. UX: user can opt in/out and see status; provide clear indicators and battery impact warning on Android.
5. Notifications: add message notifications on supported platforms, tied to background mode.

## Detailed Plan

### Phase 1: Desktop keepalive (Linux/macOS/Windows)
- Intercept window close and hide/minimize instead of terminating.
- Add a system tray icon/menu to restore or quit.
- Keep `XmppService` alive in app singleton; avoid re-initializing on hide/show.
- Ensure session reconnect logic resumes after sleep/wake.

Implementation notes:
- Linux: handle GTK window close (override delete-event) and hide. Consider libappindicator or a minimal tray (or fallback to “minimize to dock”).
- macOS: update window close to `NSApplication.shared.hide` or just close window while app remains active; add status bar item for restore/quit.
- Windows: use a tray icon via a Flutter desktop plugin (e.g. `tray_manager` or `system_tray`) to show/hide/quit.
- Add settings toggle: “Keep running in background when window closes.” Default off until tested.

Risks:
- Tray plugins differ by platform; need a multi-platform plugin or per-OS implementations.
- Users may expect app to quit on close; ensure a clear Quit option and first-run prompt.

### Phase 2: Android background keepalive
- Add a foreground service (via plugin, e.g. `flutter_foreground_task` or `flutter_background_service`) that runs the XMPP session.
- When app UI closes, keep service running; show a persistent notification with status (Connected/Connecting/Disconnected).
- Implement battery/Doze handling: reconnect with backoff, pause on network loss.
- Provide a quick action in notification to disconnect/stop service.
- Add settings toggle: “Keep connected in background (requires persistent notification).”

Risks:
- Foreground service is mandatory for reliable background connectivity.
- OEM restrictions can still kill the service; need robust reconnect and user guidance.

### Phase 3: Reconnection behavior and state management
- Centralize reconnection strategy in `XmppService` (backoff, jitter, max retry window).
- Ensure connection survives window lifecycle: don’t tie connection lifetime to UI widgets.
- Persist minimal session state in storage to resume quickly on process restart.
- Consider a lightweight heartbeat to detect dead sockets (existing SM + ping logic should be adequate).

### Phase 4: UX and Settings
- Add a “Background connection” setting with platform-specific notes.
- Provide a clear “Quit Wimsy” action (tray/menu) that disconnects cleanly.
- Add a small status indicator showing connection state and whether background mode is active.

### Phase 5: Notifications (desktop + Android)
- Desktop: show native notifications for incoming messages while the app is hidden or not focused.
- Android: show message notifications in addition to the foreground service notification (grouped if possible).
- Provide notification settings (enabled, sound, preview text, per-chat mute).
- Ensure notifications respect OS permission flows and quiet hours (where available).

Implementation notes:
- Use a cross-platform notifications plugin (e.g. `flutter_local_notifications`) and wire to message events in `XmppService`.
- When the app is focused, suppress notifications or show as in-app banners.
- On Android, keep the foreground service notification separate from message notifications.

## Out of Scope (for now)
- iOS always-on background connection.
- Full push-based wakeup or OS-level message delivery.

## Open Questions
- Desired default: keep running on close or opt-in?
- For desktop, is a tray icon required or is “minimize to dock” acceptable on macOS?
- Should Android background mode be enabled by default, or only via setting?

## Suggested Next Actions
1. Choose desktop tray plugin and UX behavior for close-to-tray.
2. Choose Android foreground service plugin and notification design.
3. Implement the desktop window-close intercept and tray menu.
4. Implement Android service + reconnect backoff.
5. Implement notifications and settings.
6. Update documentation.
