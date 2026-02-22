import 'package:flutter_test/flutter_test.dart';
import 'package:wimsy/av/call_session.dart';

void main() {
  test('CallSession tracks basic fields', () {
    final session = CallSession(
      sid: 'sid1',
      peerBareJid: 'alice@example.com',
      direction: CallDirection.outgoing,
      video: false,
      state: CallState.ringing,
    );

    expect(session.sid, 'sid1');
    expect(session.peerBareJid, 'alice@example.com');
    expect(session.direction, CallDirection.outgoing);
    expect(session.video, isFalse);
    expect(session.state, CallState.ringing);
  });
}
