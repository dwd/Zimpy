import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/data/Jid.dart';
import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import 'package:xmpp_stone/src/elements/stanzas/AbstractStanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/MessageStanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/PresenceStanza.dart';

class MucManager {
  static const _mucNs = 'http://jabber.org/protocol/muc';
  static const _mucUserNs = 'http://jabber.org/protocol/muc#user';

  static final Map<Connection, MucManager> _instances = {};

  static MucManager getInstance(Connection connection) {
    var instance = _instances[connection];
    if (instance == null) {
      instance = MucManager(connection);
      _instances[connection] = instance;
    }
    return instance;
  }

  final Connection _connection;

  final StreamController<MucMessage> _messageController = StreamController.broadcast();
  final StreamController<MucPresenceUpdate> _presenceController = StreamController.broadcast();
  final StreamController<MucSubjectUpdate> _subjectController = StreamController.broadcast();

  Stream<MucMessage> get roomMessageStream => _messageController.stream;
  Stream<MucPresenceUpdate> get roomPresenceStream => _presenceController.stream;
  Stream<MucSubjectUpdate> get roomSubjectStream => _subjectController.stream;

  MucManager(this._connection) {
    _connection.inStanzasStream.listen(_handleStanza);
  }

  void joinRoom(Jid roomJid, String nick, {String? password}) {
    final stanza = PresenceStanza();
    stanza.toJid = Jid.fromFullJid('${roomJid.userAtDomain}/$nick');
    final x = XmppElement()..name = 'x';
    x.addAttribute(XmppAttribute('xmlns', _mucNs));
    if (password != null && password.trim().isNotEmpty) {
      final pass = XmppElement()..name = 'password';
      pass.textValue = password;
      x.addChild(pass);
    }
    stanza.addChild(x);
    _connection.writeStanza(stanza);
  }

  void leaveRoom(Jid roomJid, String nick) {
    final stanza = PresenceStanza.withType(PresenceType.UNAVAILABLE);
    stanza.toJid = Jid.fromFullJid('${roomJid.userAtDomain}/$nick');
    _connection.writeStanza(stanza);
  }

  void sendGroupMessage(Jid roomJid, String body, {String? messageId}) {
    final stanza = MessageStanza(
      messageId ?? AbstractStanza.getRandomId(),
      MessageStanzaType.GROUPCHAT,
    );
    stanza.toJid = roomJid;
    stanza.body = body;
    _connection.writeStanza(stanza);
  }

  void _handleStanza(AbstractStanza? stanza) {
    if (stanza == null) {
      return;
    }
    if (stanza is MessageStanza && stanza.type == MessageStanzaType.GROUPCHAT) {
      _handleGroupMessage(stanza);
    } else if (stanza is PresenceStanza) {
      _handlePresence(stanza);
    }
  }

  void _handleGroupMessage(MessageStanza stanza) {
    final from = stanza.fromJid;
    if (from == null) {
      return;
    }
    final roomJid = from.userAtDomain;
    final nick = from.resource;
    final subject = stanza.subject;
    if (subject != null && subject.isNotEmpty && (stanza.body ?? '').isEmpty) {
      _subjectController.add(MucSubjectUpdate(roomJid: roomJid, subject: subject));
      return;
    }
    final body = stanza.body ?? '';
    if (body.trim().isEmpty) {
      return;
    }
    _messageController.add(MucMessage(
      roomJid: roomJid,
      nick: nick ?? '',
      body: body,
      stanzaId: stanza.id,
      timestamp: DateTime.now(),
    ));
  }

  void _handlePresence(PresenceStanza stanza) {
    final from = stanza.fromJid;
    if (from == null || from.resource == null || from.resource!.isEmpty) {
      return;
    }
    final x = stanza.children.firstWhereOrNull(
      (child) => child.name == 'x' && child.getAttribute('xmlns')?.value == _mucUserNs,
    );
    if (x == null) {
      return;
    }
    final item = x.getChild('item');
    final role = item?.getAttribute('role')?.value;
    final affiliation = item?.getAttribute('affiliation')?.value;
    final statusCodes = x.children
        .where((child) => child.name == 'status')
        .map((child) => child.getAttribute('code')?.value ?? '')
        .where((code) => code.isNotEmpty)
        .toSet();
    final isSelf = statusCodes.contains('110');
    final isUnavailable = stanza.type == PresenceType.UNAVAILABLE;
    final presence = MucPresenceUpdate(
      roomJid: from.userAtDomain,
      nick: from.resource ?? '',
      role: role,
      affiliation: affiliation,
      isSelf: isSelf,
      unavailable: isUnavailable,
    );
    _presenceController.add(presence);
  }
}

class MucMessage {
  MucMessage({
    required this.roomJid,
    required this.nick,
    required this.body,
    required this.timestamp,
    this.stanzaId,
  });

  final String roomJid;
  final String nick;
  final String body;
  final DateTime timestamp;
  final String? stanzaId;
}

class MucPresenceUpdate {
  MucPresenceUpdate({
    required this.roomJid,
    required this.nick,
    this.role,
    this.affiliation,
    required this.isSelf,
    required this.unavailable,
  });

  final String roomJid;
  final String nick;
  final String? role;
  final String? affiliation;
  final bool isSelf;
  final bool unavailable;
}

class MucSubjectUpdate {
  MucSubjectUpdate({required this.roomJid, required this.subject});

  final String roomJid;
  final String subject;
}

extension MucModuleGetter on Connection {
  MucManager getMucModule() {
    return MucManager.getInstance(this);
  }
}
