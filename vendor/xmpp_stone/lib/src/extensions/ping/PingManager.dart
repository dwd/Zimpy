import 'dart:async';

import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import 'package:xmpp_stone/src/elements/stanzas/IqStanza.dart';
import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/extensions/iq_router/IqRouter.dart';

class PingManager {
  static const String _pingNamespace = 'urn:xmpp:ping';
  static const String _stanzasNs = 'urn:ietf:params:xml:ns:xmpp-stanzas';

  final Connection _connection;
  late final IqRouter _router;

  static final Map<Connection, PingManager> _instances = {};

  late StreamSubscription<XmppConnectionState> _xmppConnectionStateSubscription;

  PingManager(this._connection) {
    _xmppConnectionStateSubscription =
        _connection.connectionStateStream.listen(_connectionStateProcessor);
    _router = IqRouter.getInstance(_connection);
    _router.registerNamespaceHandler(_pingNamespace, _handlePing);
  }

  static PingManager getInstance(Connection connection) {
    var manager = _instances[connection];
    if (manager == null) {
      manager = PingManager(connection);
      _instances[connection] = manager;
    }
    return manager;
  }

  static void removeInstance(Connection connection) {
    _instances[connection]?._router.unregisterNamespaceHandler(_pingNamespace);
    _instances[connection]?._xmppConnectionStateSubscription.cancel();
    _instances.remove(connection);
  }

  void _connectionStateProcessor(XmppConnectionState event) {
    // connection state processor.
  }

  IqStanza? _handlePing(IqStanza stanza) {
    if (stanza.type != IqStanzaType.GET) {
      return _buildError(stanza, 'bad-request');
    }
    final ping = stanza.getChild('ping');
    if (ping == null) {
      return _buildError(stanza, 'bad-request');
    }
    final iqStanza = IqStanza(stanza.id, IqStanzaType.RESULT);
    iqStanza.fromJid = _connection.fullJid;
    if (stanza.fromJid != null) {
      iqStanza.toJid = stanza.fromJid;
    }
    return iqStanza;
  }

  IqStanza _buildError(IqStanza stanza, String condition) {
    final response = IqStanza(stanza.id, IqStanzaType.ERROR);
    response.fromJid = _connection.fullJid;
    if (stanza.fromJid != null) {
      response.toJid = stanza.fromJid;
    }
    final error = XmppElement()..name = 'error';
    error.addAttribute(XmppAttribute('type', 'cancel'));
    final conditionElement = XmppElement()..name = condition;
    conditionElement.addAttribute(XmppAttribute('xmlns', _stanzasNs));
    error.addChild(conditionElement);
    response.addChild(error);
    return response;
  }
}
