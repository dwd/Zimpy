import 'dart:async';
import 'dart:convert';

import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/data/Jid.dart';
import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import 'package:xmpp_stone/src/elements/stanzas/AbstractStanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/IqStanza.dart';
import 'package:xmpp_stone/src/extensions/iq_router/IqRouter.dart';

class IbbOpen {
  const IbbOpen({
    required this.sid,
    required this.blockSize,
    required this.stanza,
    required this.from,
    required this.to,
  });

  final String sid;
  final int blockSize;
  final String stanza;
  final Jid from;
  final Jid to;
}

class IbbData {
  const IbbData({
    required this.sid,
    required this.seq,
    required this.bytes,
    required this.from,
    required this.to,
  });

  final String sid;
  final int seq;
  final List<int> bytes;
  final Jid from;
  final Jid to;
}

class IbbClose {
  const IbbClose({
    required this.sid,
    required this.from,
    required this.to,
  });

  final String sid;
  final Jid from;
  final Jid to;
}

class IbbManager {
  static const String ibbNamespace = 'http://jabber.org/protocol/ibb';

  static final Map<Connection, IbbManager> _instances = {};

  static IbbManager getInstance(Connection connection) {
    var instance = _instances[connection];
    if (instance == null) {
      instance = IbbManager(connection);
      _instances[connection] = instance;
    }
    return instance;
  }

  static void removeInstance(Connection connection) {
    final instance = _instances.remove(connection);
    if (instance == null) {
      return;
    }
    IqRouter.getInstance(connection).unregisterNamespaceHandler(ibbNamespace);
  }

  final Connection _connection;
  final StreamController<IbbOpen> _openController = StreamController.broadcast();
  final StreamController<IbbData> _dataController = StreamController.broadcast();
  final StreamController<IbbClose> _closeController = StreamController.broadcast();

  Stream<IbbOpen> get openStream => _openController.stream;
  Stream<IbbData> get dataStream => _dataController.stream;
  Stream<IbbClose> get closeStream => _closeController.stream;

  IbbManager(this._connection) {
    IqRouter.getInstance(_connection).registerNamespaceHandler(
      ibbNamespace,
      _handleIbbIq,
    );
  }

  Future<IqStanza?> _handleIbbIq(IqStanza request) async {
    final from = request.fromJid;
    final to = request.toJid ?? _connection.fullJid;
    if (from == null || to == null) {
      return null;
    }
    final open = request.getChild('open');
    if (open != null && open.getAttribute('xmlns')?.value == ibbNamespace) {
      final sid = open.getAttribute('sid')?.value ?? '';
      final blockSizeText = open.getAttribute('block-size')?.value ?? '';
      final blockSize = int.tryParse(blockSizeText) ?? 4096;
      final stanza = open.getAttribute('stanza')?.value ?? 'iq';
      if (sid.isNotEmpty) {
        _openController.add(IbbOpen(
          sid: sid,
          blockSize: blockSize,
          stanza: stanza,
          from: from,
          to: to,
        ));
      }
      return IqStanza(request.id, IqStanzaType.RESULT);
    }
    final data = request.getChild('data');
    if (data != null && data.getAttribute('xmlns')?.value == ibbNamespace) {
      final sid = data.getAttribute('sid')?.value ?? '';
      final seqText = data.getAttribute('seq')?.value ?? '';
      final seq = int.tryParse(seqText) ?? 0;
      final payload = data.textValue ?? '';
      if (sid.isNotEmpty && payload.isNotEmpty) {
        final bytes = base64Decode(payload);
        _dataController.add(IbbData(
          sid: sid,
          seq: seq,
          bytes: bytes,
          from: from,
          to: to,
        ));
      }
      return IqStanza(request.id, IqStanzaType.RESULT);
    }
    final close = request.getChild('close');
    if (close != null && close.getAttribute('xmlns')?.value == ibbNamespace) {
      final sid = close.getAttribute('sid')?.value ?? '';
      if (sid.isNotEmpty) {
        _closeController.add(IbbClose(
          sid: sid,
          from: from,
          to: to,
        ));
      }
      return IqStanza(request.id, IqStanzaType.RESULT);
    }
    return null;
  }

  Future<bool> sendOpen({
    required Jid to,
    required String sid,
    required int blockSize,
  }) async {
    final stanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
    stanza.toJid = to;
    stanza.fromJid = _connection.fullJid;
    final open = XmppElement()..name = 'open';
    open.addAttribute(XmppAttribute('xmlns', ibbNamespace));
    open.addAttribute(XmppAttribute('sid', sid));
    open.addAttribute(XmppAttribute('block-size', blockSize.toString()));
    open.addAttribute(XmppAttribute('stanza', 'iq'));
    stanza.addChild(open);
    final result = await _sendIqAndAwait(stanza);
    return result?.type == IqStanzaType.RESULT;
  }

  Future<bool> sendData({
    required Jid to,
    required String sid,
    required int seq,
    required List<int> bytes,
  }) async {
    final stanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
    stanza.toJid = to;
    stanza.fromJid = _connection.fullJid;
    final data = XmppElement()..name = 'data';
    data.addAttribute(XmppAttribute('xmlns', ibbNamespace));
    data.addAttribute(XmppAttribute('sid', sid));
    data.addAttribute(XmppAttribute('seq', seq.toString()));
    data.textValue = base64Encode(bytes);
    stanza.addChild(data);
    final result = await _sendIqAndAwait(stanza);
    return result?.type == IqStanzaType.RESULT;
  }

  Future<bool> sendClose({
    required Jid to,
    required String sid,
  }) async {
    final stanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
    stanza.toJid = to;
    stanza.fromJid = _connection.fullJid;
    final close = XmppElement()..name = 'close';
    close.addAttribute(XmppAttribute('xmlns', ibbNamespace));
    close.addAttribute(XmppAttribute('sid', sid));
    stanza.addChild(close);
    final result = await _sendIqAndAwait(stanza);
    return result?.type == IqStanzaType.RESULT;
  }

  Future<IqStanza?> _sendIqAndAwait(IqStanza stanza) async {
    final id = stanza.id;
    if (id == null || id.isEmpty) {
      return null;
    }
    final router = IqRouter.getInstance(_connection);
    final completer = Completer<IqStanza?>();
    Timer? timer;
    timer = Timer(const Duration(seconds: 10), () {
      router.unregisterResponseHandler(id);
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    });
    router.registerResponseHandler(id, (response) {
      timer?.cancel();
      if (!completer.isCompleted) {
        completer.complete(response);
      }
    });
    _connection.writeStanza(stanza);
    return completer.future;
  }
}
