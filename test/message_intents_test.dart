import 'package:flutter_test/flutter_test.dart';
import 'package:xmpp_stone/xmpp_stone.dart';
import 'package:wimsy/xmpp/xmpp_service.dart';

MessageStanza _chatStanza({
  required String id,
  required String from,
  required String to,
  String? body,
}) {
  final stanza = MessageStanza(id, MessageStanzaType.CHAT);
  stanza.fromJid = Jid.fromFullJid(from);
  stanza.toJid = Jid.fromFullJid(to);
  if (body != null) {
    stanza.body = body;
  }
  return stanza;
}

void main() {
  test('buildMessageIntents applies receipt with scoped id', () {
    final service = XmppService();
    final stanza = _chatStanza(
      id: 'm1',
      from: 'alice@example.com/phone',
      to: 'bob@example.com/desktop',
    );
    final received = XmppElement()..name = 'received';
    received.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:receipts'));
    received.addAttribute(XmppAttribute('id', 'r1'));
    stanza.addChild(received);

    final intents = service.buildMessageIntentsForTesting(stanza);

    expect(intents.length, 1);
    expect(intents.first, isA<ApplyReceiptIntent>());
    final intent = intents.first as ApplyReceiptIntent;
    expect(intent.scopedId.scopeJid, 'alice@example.com');
    expect(intent.scopedId.id, 'r1');
  });

  test('buildMessageIntents emits receipt and marker intents', () {
    final service = XmppService();
    final stanza = _chatStanza(
      id: 'm2',
      from: 'alice@example.com/phone',
      to: 'bob@example.com/desktop',
      body: 'hi',
    );
    final request = XmppElement()..name = 'request';
    request.addAttribute(XmppAttribute('xmlns', 'urn:xmpp:receipts'));
    stanza.addChild(request);
    final markable = XmppElement()..name = 'markable';
    markable.addAttribute(
        XmppAttribute('xmlns', 'urn:xmpp:chat-markers:0'));
    stanza.addChild(markable);

    final intents = service.buildMessageIntentsForTesting(stanza);

    expect(intents.length, 2);
    expect(intents[0], isA<SendReceiptIntent>());
    expect(intents[1], isA<SendMarkerIntent>());
    final receipt = intents[0] as SendReceiptIntent;
    final marker = intents[1] as SendMarkerIntent;
    expect(receipt.scopedId.scopeJid, 'alice@example.com');
    expect(receipt.scopedId.id, 'm2');
    expect(marker.name, 'received');
    expect(marker.scopedId.id, 'm2');
  });
}
