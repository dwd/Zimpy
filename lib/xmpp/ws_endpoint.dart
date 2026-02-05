class WsEndpointConfig {
  WsEndpointConfig({
    required this.uri,
    required this.host,
    required this.port,
    required this.path,
    required this.scheme,
  });

  final Uri uri;
  final String host;
  final int port;
  final String path;
  final String scheme;
}

WsEndpointConfig? parseWsEndpoint(String input) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final hasScheme = trimmed.contains('://');
  final candidate = hasScheme ? trimmed : 'wss://$trimmed';
  final uri = Uri.tryParse(candidate);
  if (uri == null || uri.host.isEmpty) {
    return null;
  }
  if (uri.scheme != 'ws' && uri.scheme != 'wss') {
    return null;
  }
  final path = uri.path.isEmpty ? '/xmpp-websocket' : uri.path;
  final normalized = uri.replace(path: path);
  final port = normalized.hasPort
      ? normalized.port
      : normalized.scheme == 'wss'
          ? 443
          : 80;
  return WsEndpointConfig(
    uri: normalized,
    host: normalized.host,
    port: port,
    path: normalized.path,
    scheme: normalized.scheme,
  );
}
