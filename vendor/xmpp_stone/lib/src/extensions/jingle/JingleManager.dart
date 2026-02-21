import 'dart:async';

import 'package:xmpp_stone/src/Connection.dart';
import 'package:xmpp_stone/src/data/Jid.dart';
import 'package:xmpp_stone/src/elements/XmppAttribute.dart';
import 'package:xmpp_stone/src/elements/XmppElement.dart';
import 'package:xmpp_stone/src/elements/stanzas/AbstractStanza.dart';
import 'package:xmpp_stone/src/elements/stanzas/IqStanza.dart';
import 'package:xmpp_stone/src/extensions/iq_router/IqRouter.dart';

enum JingleAction {
  sessionInitiate,
  sessionAccept,
  sessionTerminate,
  unknown,
}

class JingleFileTransferOffer {
  const JingleFileTransferOffer({
    required this.fileName,
    required this.fileSize,
    this.mediaType,
  });

  final String fileName;
  final int fileSize;
  final String? mediaType;
}

class JingleIbbTransport {
  const JingleIbbTransport({
    required this.sid,
    required this.blockSize,
    this.stanza,
  });

  final String sid;
  final int blockSize;
  final String? stanza;
}

class JingleContent {
  const JingleContent({
    required this.name,
    required this.creator,
    this.fileOffer,
    this.ibbTransport,
  });

  final String name;
  final String creator;
  final JingleFileTransferOffer? fileOffer;
  final JingleIbbTransport? ibbTransport;
}

class JingleSessionEvent {
  const JingleSessionEvent({
    required this.action,
    required this.sid,
    required this.from,
    required this.to,
    required this.stanza,
    this.content,
    this.reason,
  });

  final JingleAction action;
  final String sid;
  final Jid from;
  final Jid to;
  final IqStanza stanza;
  final JingleContent? content;
  final String? reason;
}

class JingleManager {
  static const String jingleNamespace = 'urn:xmpp:jingle:1';
  static const String fileTransferNamespace = 'urn:xmpp:jingle:apps:file-transfer:5';
  static const String fileMetadataNamespace = 'urn:xmpp:file:metadata:0';
  static const String ibbTransportNamespace = 'urn:xmpp:jingle:transports:ibb:1';

  static final Map<Connection, JingleManager> _instances = {};

  static JingleManager getInstance(Connection connection) {
    var instance = _instances[connection];
    if (instance == null) {
      instance = JingleManager(connection);
      _instances[connection] = instance;
    }
    return instance;
  }

  static void removeInstance(Connection connection) {
    final instance = _instances.remove(connection);
    if (instance == null) {
      return;
    }
    IqRouter.getInstance(connection).unregisterNamespaceHandler(jingleNamespace);
  }

  final Connection _connection;
  final StreamController<JingleSessionEvent> _sessionController = StreamController.broadcast();

  Stream<JingleSessionEvent> get sessionStream => _sessionController.stream;

  JingleManager(this._connection) {
    IqRouter.getInstance(_connection).registerNamespaceHandler(
      jingleNamespace,
      _handleJingleIq,
    );
  }

  Future<IqStanza?> _handleJingleIq(IqStanza request) async {
    final event = _parseEvent(request);
    if (event == null) {
      return null;
    }
    _sessionController.add(event);
    return IqStanza(request.id, IqStanzaType.RESULT);
  }

  JingleSessionEvent? _parseEvent(IqStanza request) {
    final jingle = request.getChild('jingle');
    if (jingle == null ||
        jingle.getAttribute('xmlns')?.value != jingleNamespace) {
      return null;
    }
    final actionValue = jingle.getAttribute('action')?.value ?? '';
    final sid = jingle.getAttribute('sid')?.value ?? '';
    if (sid.isEmpty) {
      return null;
    }
    final action = _actionFromString(actionValue);
    final from = request.fromJid;
    final to = request.toJid ?? _connection.fullJid;
    if (from == null || to == null) {
      return null;
    }
    final content = _parseContent(jingle);
    final reason = _parseReason(jingle);
    return JingleSessionEvent(
      action: action,
      sid: sid,
      from: from,
      to: to,
      stanza: request,
      content: content,
      reason: reason,
    );
  }

  JingleContent? _parseContent(XmppElement jingle) {
    for (final child in jingle.children) {
      if (child.name != 'content') {
        continue;
      }
      final creator = child.getAttribute('creator')?.value ?? '';
      final name = child.getAttribute('name')?.value ?? '';
      final description = child.getChild('description');
      final offer = _parseFileOffer(description);
      final transport = _parseIbbTransport(child.getChild('transport'));
      if (name.isEmpty && offer == null && transport == null) {
        continue;
      }
      return JingleContent(
        name: name,
        creator: creator.isEmpty ? 'initiator' : creator,
        fileOffer: offer,
        ibbTransport: transport,
      );
    }
    return null;
  }

  JingleFileTransferOffer? _parseFileOffer(XmppElement? description) {
    if (description == null ||
        description.getAttribute('xmlns')?.value != fileTransferNamespace) {
      return null;
    }
    XmppElement? fileElement;
    final offer = description.getChild('offer');
    if (offer != null) {
      fileElement = offer.getChild('file');
    } else {
      fileElement = description.getChild('file');
    }
    if (fileElement == null) {
      return null;
    }
    if (fileElement.getAttribute('xmlns')?.value == null) {
      fileElement.addAttribute(XmppAttribute('xmlns', fileMetadataNamespace));
    }
    final name = fileElement.getChild('name')?.textValue?.trim() ?? '';
    final sizeText = fileElement.getChild('size')?.textValue?.trim() ?? '';
    final size = int.tryParse(sizeText) ?? 0;
    if (name.isEmpty || size <= 0) {
      return null;
    }
    final mediaType = fileElement.getChild('media-type')?.textValue?.trim();
    return JingleFileTransferOffer(
      fileName: name,
      fileSize: size,
      mediaType: (mediaType == null || mediaType.isEmpty) ? null : mediaType,
    );
  }

  JingleIbbTransport? _parseIbbTransport(XmppElement? transport) {
    if (transport == null ||
        transport.getAttribute('xmlns')?.value != ibbTransportNamespace) {
      return null;
    }
    final sid = transport.getAttribute('sid')?.value ?? '';
    if (sid.isEmpty) {
      return null;
    }
    final blockSizeText = transport.getAttribute('block-size')?.value ?? '';
    final blockSize = int.tryParse(blockSizeText) ?? 4096;
    final stanza = transport.getAttribute('stanza')?.value;
    return JingleIbbTransport(
      sid: sid,
      blockSize: blockSize,
      stanza: stanza,
    );
  }

  String? _parseReason(XmppElement jingle) {
    final reason = jingle.getChild('reason');
    if (reason == null) {
      return null;
    }
    for (final child in reason.children) {
      final name = child.name;
      if (name != null && name.isNotEmpty && name != 'text') {
        return name;
      }
    }
    return null;
  }

  JingleAction _actionFromString(String action) {
    switch (action) {
      case 'session-initiate':
        return JingleAction.sessionInitiate;
      case 'session-accept':
        return JingleAction.sessionAccept;
      case 'session-terminate':
        return JingleAction.sessionTerminate;
      default:
        return JingleAction.unknown;
    }
  }

  IqStanza buildSessionInitiate({
    required Jid to,
    required String sid,
    required JingleContent content,
    required String ibbSid,
    required int blockSize,
  }) {
    final stanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
    stanza.toJid = to;
    stanza.fromJid = _connection.fullJid;
    stanza.addChild(_buildJinglePayload(
      action: 'session-initiate',
      sid: sid,
      content: content,
      ibbSid: ibbSid,
      blockSize: blockSize,
    ));
    return stanza;
  }

  IqStanza buildSessionAccept({
    required Jid to,
    required String sid,
    required JingleContent content,
    required String ibbSid,
    required int blockSize,
  }) {
    final stanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
    stanza.toJid = to;
    stanza.fromJid = _connection.fullJid;
    stanza.addChild(_buildJinglePayload(
      action: 'session-accept',
      sid: sid,
      content: content,
      ibbSid: ibbSid,
      blockSize: blockSize,
    ));
    return stanza;
  }

  IqStanza buildSessionTerminate({
    required Jid to,
    required String sid,
    required String reason,
  }) {
    final stanza = IqStanza(AbstractStanza.getRandomId(), IqStanzaType.SET);
    stanza.toJid = to;
    stanza.fromJid = _connection.fullJid;
    final jingle = XmppElement()..name = 'jingle';
    jingle.addAttribute(XmppAttribute('xmlns', jingleNamespace));
    jingle.addAttribute(XmppAttribute('action', 'session-terminate'));
    jingle.addAttribute(XmppAttribute('sid', sid));
    final reasonElement = XmppElement()..name = 'reason';
    final reasonChild = XmppElement()..name = reason;
    reasonElement.addChild(reasonChild);
    jingle.addChild(reasonElement);
    stanza.addChild(jingle);
    return stanza;
  }

  XmppElement _buildJinglePayload({
    required String action,
    required String sid,
    required JingleContent content,
    required String ibbSid,
    required int blockSize,
  }) {
    final jingle = XmppElement()..name = 'jingle';
    jingle.addAttribute(XmppAttribute('xmlns', jingleNamespace));
    jingle.addAttribute(XmppAttribute('action', action));
    jingle.addAttribute(XmppAttribute('sid', sid));
    final contentElement = XmppElement()..name = 'content';
    contentElement.addAttribute(XmppAttribute('creator', content.creator));
    contentElement.addAttribute(XmppAttribute('name', content.name));

    if (content.fileOffer != null) {
      final description = XmppElement()..name = 'description';
      description.addAttribute(XmppAttribute('xmlns', fileTransferNamespace));
      final offer = XmppElement()..name = 'offer';
      final file = XmppElement()..name = 'file';
      file.addAttribute(XmppAttribute('xmlns', fileMetadataNamespace));
      final name = XmppElement()..name = 'name';
      name.textValue = content.fileOffer!.fileName;
      final size = XmppElement()..name = 'size';
      size.textValue = content.fileOffer!.fileSize.toString();
      file.addChild(name);
      file.addChild(size);
      final mediaType = content.fileOffer!.mediaType;
      if (mediaType != null && mediaType.isNotEmpty) {
        final media = XmppElement()..name = 'media-type';
        media.textValue = mediaType;
        file.addChild(media);
      }
      offer.addChild(file);
      description.addChild(offer);
      contentElement.addChild(description);
    }

    final transport = XmppElement()..name = 'transport';
    transport.addAttribute(XmppAttribute('xmlns', ibbTransportNamespace));
    transport.addAttribute(XmppAttribute('sid', ibbSid));
    transport.addAttribute(XmppAttribute('block-size', blockSize.toString()));
    transport.addAttribute(XmppAttribute('stanza', 'iq'));
    contentElement.addChild(transport);

    jingle.addChild(contentElement);
    return jingle;
  }
}
