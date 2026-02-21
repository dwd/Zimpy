import 'package:flutter_test/flutter_test.dart';
import 'package:wimsy/xmpp/blocking.dart';
import 'package:xmpp_stone/xmpp_stone.dart';

void main() {
  test('parseBlocklistIq extracts blocklist items', () {
    final stanza = IqStanza('b1', IqStanzaType.RESULT);
    final blocklist = XmppElement()..name = 'blocklist';
    blocklist.addAttribute(XmppAttribute('xmlns', blockingNamespace));
    final item = XmppElement()..name = 'item';
    item.addAttribute(XmppAttribute('jid', 'alice@example.com'));
    blocklist.addChild(item);
    stanza.addChild(blocklist);

    final items = parseBlocklistIq(stanza);
    expect(items, ['alice@example.com']);
  });

  test('parseBlockingUpdate handles block push', () {
    final stanza = IqStanza('b2', IqStanzaType.SET);
    final block = XmppElement()..name = 'block';
    block.addAttribute(XmppAttribute('xmlns', blockingNamespace));
    final item = XmppElement()..name = 'item';
    item.addAttribute(XmppAttribute('jid', 'bob@example.com'));
    block.addChild(item);
    stanza.addChild(block);

    final update = parseBlockingUpdate(stanza);
    expect(update, isNotNull);
    expect(update!.isBlock, true);
    expect(update.items, ['bob@example.com']);
  });

  test('parseBlockingUpdate handles unblock all', () {
    final stanza = IqStanza('b3', IqStanzaType.SET);
    final unblock = XmppElement()..name = 'unblock';
    unblock.addAttribute(XmppAttribute('xmlns', blockingNamespace));
    stanza.addChild(unblock);

    final update = parseBlockingUpdate(stanza);
    expect(update, isNotNull);
    expect(update!.isBlock, false);
    expect(update.items, isEmpty);
  });
}
