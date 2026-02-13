import 'package:mockito/mockito.dart';
import 'package:test/test.dart';
import 'package:universal_io/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xmpp_stone/src/connection/XmppWebsocketIo.dart';

class MockSocket extends Mock implements Socket {}

class MockSecureSocket extends Mock implements SecureSocket {}

class MockWebSocketChannel extends Mock implements WebSocketChannel {}

void main() {
  group('XmppWebSocketIo', () {
    test('Uses websocket factory when useWebSocket=true', () async {
      var tcpCalled = false;
      var wsCalled = false;
      final channel = MockWebSocketChannel();
      final socket = XmppWebSocketIo(
        tcpConnect: (host, port) {
          tcpCalled = true;
          return Future.value(MockSocket());
        },
        webSocketConnect: (uri, {protocols}) {
          wsCalled = true;
          return channel;
        },
      );

      await socket.connect(
        'example.com',
        443,
        useWebSocket: true,
        wsUri: Uri.parse('wss://example.com/ws'),
      );

      expect(wsCalled, isTrue);
      expect(tcpCalled, isFalse);
    });

    test('Direct TLS uses tcp + secure factories', () async {
      var tcpCalled = false;
      var secureCalled = false;
      final rawSocket = MockSocket();
      final secureSocket = MockSecureSocket();
      final socket = XmppWebSocketIo(
        tcpConnect: (host, port) {
          tcpCalled = true;
          return Future.value(rawSocket);
        },
        secureSocketFactory: (socket, {host, context, onBadCertificate, supportedProtocols}) {
          secureCalled = true;
          return Future.value(secureSocket);
        },
      );

      await socket.connect(
        'example.com',
        5223,
        directTls: true,
      );

      expect(tcpCalled, isTrue);
      expect(secureCalled, isTrue);
    });
  });
}
