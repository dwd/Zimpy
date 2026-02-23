import 'package:test/test.dart';
import 'package:xmpp_stone/src/muc/MucManager.dart';
import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/data/Jid.dart';
import 'package:xmpp_stone/src/account/XmppAccountSettings.dart';
import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import 'package:xmpp_stone/src/elements/stanzas/PresenceStanza.dart';

void main() {
  test('Muc presence exposes status codes', () async {
    final connection = Connection(XmppAccountSettings('test', 'user', 'example.com', 'pass', 5222));
    final manager = MucManager.getInstance(connection);

    final presence = PresenceStanza();
    presence.fromJid = Jid.fromFullJid('room@example.com/nick');
    final x = XmppElement()..name = 'x';
    x.addAttribute(XmppAttribute('xmlns', 'http://jabber.org/protocol/muc#user'));
    final status201 = XmppElement()..name = 'status';
    status201.addAttribute(XmppAttribute('code', '201'));
    final status110 = XmppElement()..name = 'status';
    status110.addAttribute(XmppAttribute('code', '110'));
    x.addChild(status201);
    x.addChild(status110);
    presence.addChild(x);

    final nextUpdate = manager.roomPresenceStream.first;
    connection.fireNewStanzaEvent(presence);
    final update = await nextUpdate;
    expect(update.statusCodes.contains('201'), isTrue);
    expect(update.statusCodes.contains('110'), isTrue);
  });
}
