import 'dart:async';

import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import 'package:xmpp_stone/src/elements/stanzas/AbstractStanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/IqStanza.dart';

typedef IqRequestHandler = FutureOr<IqStanza?> Function(IqStanza request);
typedef IqResponseHandler = FutureOr<void> Function(IqStanza response);

class IqRouter {
  static const String _stanzasNs = 'urn:ietf:params:xml:ns:xmpp-stanzas';
  static const String _internalServerError = 'internal-server-error';
  static const String _serviceUnavailable = 'service-unavailable';

  static final Map<Connection, IqRouter> _instances = {};

  final Connection _connection;
  final Map<String, IqRequestHandler> _namespaceHandlers = {};
  final Map<String, IqResponseHandler> _responseHandlers = {};

  late final StreamSubscription<AbstractStanza?> _subscription;

  IqRouter(this._connection) {
    _subscription = _connection.inStanzasStream.listen(_processStanza);
  }

  static IqRouter getInstance(Connection connection) {
    var router = _instances[connection];
    if (router == null) {
      router = IqRouter(connection);
      _instances[connection] = router;
    }
    return router;
  }

  static void removeInstance(Connection connection) {
    final router = _instances.remove(connection);
    router?._subscription.cancel();
  }

  void registerNamespaceHandler(String namespace, IqRequestHandler handler) {
    _namespaceHandlers[namespace] = handler;
  }

  void unregisterNamespaceHandler(String namespace) {
    _namespaceHandlers.remove(namespace);
  }

  void registerResponseHandler(String id, IqResponseHandler handler) {
    _responseHandlers[id] = handler;
  }

  void unregisterResponseHandler(String id) {
    _responseHandlers.remove(id);
  }

  Future<void> _processStanza(AbstractStanza? stanza) async {
    if (stanza is! IqStanza) {
      return;
    }

    if (stanza.type == IqStanzaType.RESULT || stanza.type == IqStanzaType.ERROR) {
      final id = stanza.id;
      if (id == null) {
        return;
      }
      final handler = _responseHandlers.remove(id);
      if (handler == null) {
        return;
      }
      try {
        await handler(stanza);
      } catch (error, stackTrace) {
        Connection.reportError(error, stackTrace);
      }
      return;
    }

    if (stanza.type != IqStanzaType.GET && stanza.type != IqStanzaType.SET) {
      return;
    }

    final namespace = _payloadNamespace(stanza);
    final handler = namespace != null ? _namespaceHandlers[namespace] : null;
    if (handler == null) {
      _sendErrorIfPossible(stanza, _serviceUnavailable);
      return;
    }

    try {
      final response = await handler(stanza);
      if (response == null) {
        _sendErrorIfPossible(stanza, _serviceUnavailable);
        return;
      }
      _ensureReplyAddresses(stanza, response);
      _connection.writeStanza(response);
    } catch (error, stackTrace) {
      Connection.reportError(error, stackTrace);
      _sendErrorIfPossible(stanza, _internalServerError);
    }
  }

  String? _payloadNamespace(IqStanza stanza) {
    for (final child in stanza.children) {
      if (child is XmppElement) {
        final xmlns = child.getAttribute('xmlns')?.value;
        if (xmlns != null && xmlns.isNotEmpty) {
          return xmlns;
        }
      }
    }
    return null;
  }

  void _ensureReplyAddresses(IqStanza request, IqStanza response) {
    response.id ??= request.id;
    response.fromJid ??= _connection.fullJid;
    response.toJid ??= request.fromJid;
  }

  void _sendErrorIfPossible(IqStanza request, String condition) {
    final response = _buildErrorResponse(request, condition);
    if (response == null) {
      return;
    }
    _connection.writeStanza(response);
  }

  IqStanza? _buildErrorResponse(IqStanza request, String condition) {
    final response = IqStanza(request.id, IqStanzaType.ERROR);
    response.fromJid = _connection.fullJid;
    if (request.fromJid != null) {
      response.toJid = request.fromJid;
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
