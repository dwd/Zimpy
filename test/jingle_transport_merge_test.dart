import 'package:flutter_test/flutter_test.dart';
import 'package:wimsy/xmpp/xmpp_service.dart';
import 'package:xmpp_stone/xmpp_stone.dart';

void main() {
  test('mergeIceTransports preserves fingerprint and merges candidates', () {
    const fingerprint = JingleDtlsFingerprint(
      hash: 'sha-256',
      fingerprint: 'AA:BB:CC',
      setup: 'actpass',
    );
    const existing = JingleIceTransport(
      ufrag: 'oldUfrag',
      password: 'oldPwd',
      candidates: [
        JingleIceCandidate(
          foundation: '1',
          component: 1,
          protocol: 'udp',
          priority: 100,
          ip: '10.0.0.1',
          port: 5000,
          type: 'host',
          generation: 0,
        ),
      ],
      fingerprint: fingerprint,
    );
    const update = JingleIceTransport(
      ufrag: '',
      password: '',
      candidates: [
        JingleIceCandidate(
          foundation: '2',
          component: 2,
          protocol: 'udp',
          priority: 200,
          ip: '10.0.0.2',
          port: 6000,
          type: 'host',
          generation: 0,
        ),
      ],
    );

    final merged = XmppService.mergeIceTransports(existing, update);

    expect(merged.ufrag, 'oldUfrag');
    expect(merged.password, 'oldPwd');
    expect(merged.fingerprint, fingerprint);
    expect(merged.candidates.length, 2);
    expect(merged.candidates.first.foundation, '2');
    expect(merged.candidates.last.foundation, '1');
  });
}
