import 'dart:async';
import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:xmpp_stone/src/connection/XmppWebsocketApi.dart';
import 'package:xmpp_stone/src/logger/Log.dart';

export 'XmppWebsocketApi.dart';

XmppWebSocket createSocket() {
  return XmppWebSocketIo();
}

bool isTlsRequired() {
  return true;
}

class XmppWebSocketIo extends XmppWebSocket {
  static String TAG = 'XmppWebSocketIo';
  Socket? _tcpSocket;
  WebSocketChannel? _webSocket;
  bool _useWebSocket = false;
  late String Function(String event) _map;
  final TcpSocketConnect _tcpConnect;
  final SecureSocketFactory _secureSocketFactory;
  final WebSocketChannelFactory _webSocketConnect;

  XmppWebSocketIo({
    TcpSocketConnect? tcpConnect,
    SecureSocketFactory? secureSocketFactory,
    WebSocketChannelFactory? webSocketConnect,
  })  : _tcpConnect = tcpConnect ?? Socket.connect,
        _secureSocketFactory = secureSocketFactory ?? _defaultSecureSocketFactory,
        _webSocketConnect = webSocketConnect ?? _defaultWebSocketConnect;

  @override
  Future<XmppWebSocket> connect<S>(String host, int port,
      {String Function(String event)? map,
      List<String>? wsProtocols,
      String? wsPath,
      Uri? wsUri,
      bool useWebSocket = false,
      bool directTls = false,
      String? tlsHost}) async {
    _useWebSocket = useWebSocket || wsUri != null || wsPath != null;
    Log.i(TAG,
        'Socket connect: host=$host port=$port useWebSocket=$_useWebSocket directTls=$directTls');
    if (_useWebSocket) {
      final uri = wsUri ??
          Uri(
            scheme: port == 443 ? 'wss' : 'ws',
            host: host,
            port: port,
            path: wsPath,
          );
      Log.i(TAG, 'WebSocket URI: $uri');
      _webSocket = _webSocketConnect(uri, protocols: wsProtocols);
    } else {
      if (directTls) {
        Log.i(TAG, 'Direct TLS: SecureSocket.connect');
        final rawSocket = await _tcpConnect(host, port);
        _tcpSocket = await _secureSocketFactory(rawSocket, host: tlsHost ?? host);
      } else {
        Log.i(TAG, 'Plain TCP: Socket.connect');
        await _tcpConnect(host, port).then((Socket socket) {
          _tcpSocket = socket;
        });
      }
    }

    if (map != null) {
      _map = map;
    } else {
      _map = (element) => element;
    }

    return Future.value(this);
  }

  @override
  void close() {
    if (_useWebSocket) {
      _webSocket?.sink.close();
    } else {
      _tcpSocket?.close();
    }
  }

  @override
  void write(Object? message) {
    if (_useWebSocket) {
      _webSocket?.sink.add(message);
    } else {
      _tcpSocket?.write(message);
    }
  }

  @override
  StreamSubscription<String> listen(void Function(String event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    if (_useWebSocket) {
      return _webSocket!.stream.map((event) => event.toString()).map(_map).listen(
          onData,
          onError: onError,
          onDone: onDone,
          cancelOnError: cancelOnError);
    }
    return _tcpSocket!.cast<List<int>>().transform(utf8.decoder).map(_map).listen(
        onData,
        onError: onError,
        onDone: onDone,
        cancelOnError: cancelOnError);
  }

  @override
  Future<SecureSocket?> secure(
      {host,
      SecurityContext? context,
      bool Function(X509Certificate certificate)? onBadCertificate,
      List<String>? supportedProtocols}) {
    if (_useWebSocket) {
      return Future.value(null);
    }
    Log.i(TAG, 'StartTLS: SecureSocket.secure');
    return _secureSocketFactory(
      _tcpSocket!,
      host: host,
      onBadCertificate: onBadCertificate,
      supportedProtocols: supportedProtocols,
    ).then((secureSocket) {
      if (secureSocket != null) {
        _tcpSocket = secureSocket;
      }
      return secureSocket;
    });
  }

  @override
  String getStreamOpeningElement(String domain) {
    return """<?xml version='1.0'?><stream:stream xmlns='jabber:client' version='1.0' xmlns:stream='http://etherx.jabber.org/streams' to='$domain' xml:lang='en'>""";
  }
}

typedef TcpSocketConnect = Future<Socket> Function(String host, int port);
typedef SecureSocketFactory = Future<SecureSocket> Function(
  Socket socket, {
  String? host,
  SecurityContext? context,
  bool Function(X509Certificate certificate)? onBadCertificate,
  List<String>? supportedProtocols,
});
typedef WebSocketChannelFactory = WebSocketChannel Function(
  Uri uri, {
  Iterable<String>? protocols,
});

Future<SecureSocket> _defaultSecureSocketFactory(
  Socket socket, {
  String? host,
  SecurityContext? context,
  bool Function(X509Certificate certificate)? onBadCertificate,
  List<String>? supportedProtocols,
}) {
  return SecureSocket.secure(
    socket,
    host: host,
    context: context,
    onBadCertificate: onBadCertificate,
    supportedProtocols: supportedProtocols,
  );
}

WebSocketChannel _defaultWebSocketConnect(
  Uri uri, {
  Iterable<String>? protocols,
}) {
  return WebSocketChannel.connect(uri, protocols: protocols);
}
