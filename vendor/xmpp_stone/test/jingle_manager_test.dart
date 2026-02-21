import 'dart:async';

import 'package:test/test.dart';
import 'package:universal_io/io.dart';
import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/account/XmppAccountSettings.dart';
import 'package:xmpp_stone/src/connection/XmppWebsocketApi.dart';
import 'package:xmpp_stone/src/elements/stanzas/IqStanza.dart';
import 'package:xmpp_stone/src/extensions/jingle/JingleManager.dart';

void main() {
  test('Jingle session-initiate parses file offer + IBB transport', () async {
    final account = XmppAccountSettings.fromJid('user@example.com/res', 'pass');
    final connection = Connection(account);
    connection.socket = _FakeSocket();
    final manager = JingleManager.getInstance(connection);

    final completer = Completer<JingleSessionEvent>();
    manager.sessionStream.listen((event) {
      completer.complete(event);
    });

    final iq = '<iq type="set" id="j1" from="peer@example.com/res" to="user@example.com/res">'
        '<jingle xmlns="urn:xmpp:jingle:1" action="session-initiate" sid="sid123">'
        '<content creator="initiator" name="file">'
        '<description xmlns="urn:xmpp:jingle:apps:file-transfer:5">'
        '<offer>'
        '<file xmlns="urn:xmpp:file:metadata:0">'
        '<name>photo.png</name>'
        '<size>12</size>'
        '<media-type>image/png</media-type>'
        '</file>'
        '</offer>'
        '</description>'
        '<transport xmlns="urn:xmpp:jingle:transports:ibb:1" sid="ibb1" block-size="4096" stanza="iq"/>'
        '</content>'
        '</jingle>'
        '</iq>';

    connection.handleResponse(connection.prepareStreamResponse(iq));

    final event = await completer.future.timeout(const Duration(seconds: 1));
    expect(event.action, JingleAction.sessionInitiate);
    expect(event.sid, 'sid123');
    expect(event.content, isNotNull);
    expect(event.content!.fileOffer, isNotNull);
    expect(event.content!.fileOffer!.fileName, 'photo.png');
    expect(event.content!.fileOffer!.fileSize, 12);
    expect(event.content!.fileOffer!.mediaType, 'image/png');
    expect(event.content!.ibbTransport, isNotNull);
    expect(event.content!.ibbTransport!.sid, 'ibb1');
  });

  test('Jingle manager replies to session-initiate with result', () async {
    final account = XmppAccountSettings.fromJid('user@example.com/res', 'pass');
    final connection = Connection(account);
    connection.socket = _FakeSocket();
    JingleManager.getInstance(connection);
    final responses = <IqStanza>[];
    connection.outStanzasStream.listen((stanza) {
      if (stanza is IqStanza) {
        responses.add(stanza);
      }
    });

    final iq = '<iq type="set" id="j2" from="peer@example.com/res">'
        '<jingle xmlns="urn:xmpp:jingle:1" action="session-initiate" sid="sid124"/>'
        '</iq>';
    connection.handleResponse(connection.prepareStreamResponse(iq));

    await Future<void>.delayed(Duration.zero);
    expect(responses, isNotEmpty);
    expect(responses.first.type, IqStanzaType.RESULT);
  });
}

class _FakeSocket extends Stream<String> implements XmppWebSocket {
  final StreamController<String> _controller = StreamController<String>.broadcast();

  @override
  StreamSubscription<String> listen(void Function(String event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _controller.stream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Future<XmppWebSocket> connect<S>(String host, int port,
      {String Function(String event)? map,
      List<String>? wsProtocols,
      String? wsPath,
      Uri? wsUri,
      bool useWebSocket = false,
      bool directTls = false,
      String? tlsHost}) async {
    return this;
  }

  @override
  void write(Object? message) {}

  @override
  void close() {}

  @override
  Future<SecureSocket?> secure(
      {host,
      SecurityContext? context,
      bool Function(X509Certificate certificate)? onBadCertificate,
      List<String>? supportedProtocols}) async {
    return null;
  }

  @override
  String getStreamOpeningElement(String domain) {
    return '<stream:stream>';
  }
}
