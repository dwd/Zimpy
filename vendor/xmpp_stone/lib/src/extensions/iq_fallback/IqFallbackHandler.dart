import 'dart:async';

import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import 'package:xmpp_stone/src/elements/stanzas/AbstractStanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/IqStanza.dart';

class IqFallbackHandler {
  static const String _discoInfoNs = 'http://jabber.org/protocol/disco#info';
  static const String _pingNs = 'urn:xmpp:ping';
  static const String _stanzasNs = 'urn:ietf:params:xml:ns:xmpp-stanzas';

  final Connection _connection;

  static final Map<Connection, IqFallbackHandler> _instances = {};

  late StreamSubscription<AbstractStanza?> _subscription;

  IqFallbackHandler(this._connection) {
    _subscription = _connection.inStanzasStream.listen(_processStanza);
  }

  static IqFallbackHandler getInstance(Connection connection) {
    var manager = _instances[connection];
    if (manager == null) {
      manager = IqFallbackHandler(connection);
      _instances[connection] = manager;
    }
    return manager;
  }

  static void removeInstance(Connection connection) {
    _instances[connection]?._subscription.cancel();
    _instances.remove(connection);
  }

  void _processStanza(AbstractStanza? stanza) {
    if (stanza is! IqStanza) {
      return;
    }
    if (stanza.type != IqStanzaType.GET && stanza.type != IqStanzaType.SET) {
      return;
    }
    if (_isDiscoInfo(stanza) || _isPing(stanza)) {
      return;
    }
    if (stanza.fromJid == null) {
      return;
    }
    final response = IqStanza(stanza.id, IqStanzaType.ERROR);
    response.fromJid = _connection.fullJid;
    response.toJid = stanza.fromJid;
    final error = XmppElement()..name = 'error';
    error.addAttribute(XmppAttribute('type', 'cancel'));
    final condition = XmppElement()..name = 'service-unavailable';
    condition.addAttribute(XmppAttribute('xmlns', _stanzasNs));
    error.addChild(condition);
    response.addChild(error);
    _connection.writeStanza(response);
  }

  bool _isDiscoInfo(IqStanza stanza) {
    final query = stanza.getChild('query');
    return query?.getAttribute('xmlns')?.value == _discoInfoNs;
  }

  bool _isPing(IqStanza stanza) {
    final ping = stanza.getChild('ping');
    return ping?.getAttribute('xmlns')?.value == _pingNs;
  }
}
