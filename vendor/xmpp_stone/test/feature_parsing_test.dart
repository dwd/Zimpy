import 'package:test/test.dart';
import 'package:xml/xml.dart' as xml;
import 'package:xmpp_stone/src/features/ConnectionNegotatiorManager.dart';

void main() {
  group('Feature parsing', () {
    test('Parses feature child elements into nonzas', () {
      final doc = xml.XmlDocument.parse(
        '<stream:features xmlns:stream="http://etherx.jabber.org/streams">'
        '<mechanisms xmlns="urn:ietf:params:xml:ns:xmpp-sasl">'
        '<mechanism>PLAIN</mechanism>'
        '</mechanisms>'
        '<starttls xmlns="urn:ietf:params:xml:ns:xmpp-tls"/>'
        '</stream:features>',
      );
      final features = doc.rootElement;

      final nonzas = ConnectionNegotiatorManager.parseFeatureNonzas(features);

      expect(nonzas.length, 2);
      expect(nonzas[0].name, 'mechanisms');
      expect(nonzas[1].name, 'starttls');
    });

    test('Empty feature list yields empty nonzas', () {
      final doc = xml.XmlDocument.parse(
        '<stream:features xmlns:stream="http://etherx.jabber.org/streams"></stream:features>',
      );
      final features = doc.rootElement;

      final nonzas = ConnectionNegotiatorManager.parseFeatureNonzas(features);

      expect(nonzas, isEmpty);
    });
  });
}
