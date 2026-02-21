import 'package:flutter_test/flutter_test.dart';
import 'package:wimsy/xmpp/alt_connection_parser.dart';

void main() {
  test('parseHostMetaJson returns websocket link', () {
    const payload = '''
{
  "links": [
    {
      "rel": "urn:xmpp:alt-connections:websocket",
      "href": "wss://example.com/xmpp-websocket"
    }
  ]
}
''';

    final uri = parseHostMetaJson(payload);
    expect(uri, isNotNull);
    expect(uri!.scheme, 'wss');
    expect(uri.host, 'example.com');
    expect(uri.path, '/xmpp-websocket');
  });

  test('parseHostMetaXml returns websocket link', () {
    const payload = '''
<XRD xmlns="http://docs.oasis-open.org/ns/xri/xrd-1.0">
  <Link rel="urn:xmpp:alt-connections:websocket" href="wss://example.com/xmpp-websocket" />
</XRD>
''';

    final uri = parseHostMetaXml(payload);
    expect(uri, isNotNull);
    expect(uri!.scheme, 'wss');
    expect(uri.host, 'example.com');
    expect(uri.path, '/xmpp-websocket');
  });
}
