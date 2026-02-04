import 'dart:convert';
import 'dart:typed_data';

import 'package:xmpp_stone/xmpp_stone.dart';

import '../models/avatar_metadata.dart';
import '../storage/storage_service.dart';

typedef PepUpdateCallback = void Function();

class PepManager {
  PepManager({
    required this.connection,
    required this.storage,
    required this.selfBareJid,
    required PepUpdateCallback onUpdate,
  }) : _onUpdate = onUpdate {
    _metadataByJid.addAll(storage.loadAvatarMetadata());
    _avatarBlobs.addAll(storage.loadAvatarBlobs());
  }

  final Connection connection;
  final StorageService storage;
  final String selfBareJid;
  final PepUpdateCallback _onUpdate;

  final Map<String, AvatarMetadata> _metadataByJid = {};
  final Map<String, String> _avatarBlobs = {};
  final Map<String, _PendingAvatarData> _pendingDataRequests = {};

  Uint8List? avatarBytesFor(String bareJid) {
    final meta = _metadataByJid[bareJid];
    if (meta == null) {
      return null;
    }
    final base64Data = _avatarBlobs[meta.hash];
    if (base64Data == null) {
      return null;
    }
    try {
      return base64Decode(base64Data);
    } catch (_) {
      return null;
    }
  }

  bool hasAvatarMetadata(String bareJid) {
    return _metadataByJid.containsKey(bareJid);
  }

  void subscribeToAvatarMetadata(String bareJid) {
    _sendSubscribe(bareJid);
  }

  void requestMetadataIfMissing(String bareJid) {
    if (_metadataByJid.containsKey(bareJid)) {
      return;
    }
    _requestMetadata(bareJid);
  }

  String? requestAvatarData(String bareJid, String hash) {
    if (_avatarBlobs.containsKey(hash)) {
      return null;
    }
    final id = AbstractStanza.getRandomId();
    final iqStanza = IqStanza(id, IqStanzaType.GET);
    iqStanza.toJid = Jid.fromFullJid(bareJid);
    final pubsub = XmppElement()..name = 'pubsub';
    pubsub.addAttribute(XmppAttribute('xmlns', 'http://jabber.org/protocol/pubsub'));
    final items = XmppElement()..name = 'items';
    items.addAttribute(XmppAttribute('node', 'urn:xmpp:avatar:data'));
    final item = XmppElement()..name = 'item';
    item.addAttribute(XmppAttribute('id', hash));
    items.addChild(item);
    pubsub.addChild(items);
    iqStanza.addChild(pubsub);
    _pendingDataRequests[id] = _PendingAvatarData(bareJid: bareJid, hash: hash);
    connection.writeStanza(iqStanza);
    return id;
  }

  void handleStanza(AbstractStanza stanza) {
    if (stanza is MessageStanza) {
      _handleEventMessage(stanza);
    } else if (stanza is IqStanza) {
      _handleIqResult(stanza);
    }
  }

  void clearCache() {
    _metadataByJid.clear();
    _avatarBlobs.clear();
    _onUpdate();
  }

  void _sendSubscribe(String bareJid) {
    final id = AbstractStanza.getRandomId();
    final iqStanza = IqStanza(id, IqStanzaType.SET);
    iqStanza.toJid = Jid.fromFullJid(bareJid);
    final pubsub = XmppElement()..name = 'pubsub';
    pubsub.addAttribute(XmppAttribute('xmlns', 'http://jabber.org/protocol/pubsub'));
    final subscribe = XmppElement()..name = 'subscribe';
    subscribe.addAttribute(XmppAttribute('node', 'urn:xmpp:avatar:metadata'));
    subscribe.addAttribute(XmppAttribute('jid', selfBareJid));
    pubsub.addChild(subscribe);
    iqStanza.addChild(pubsub);
    connection.writeStanza(iqStanza);
  }

  void _requestMetadata(String bareJid) {
    final id = AbstractStanza.getRandomId();
    final iqStanza = IqStanza(id, IqStanzaType.GET);
    iqStanza.toJid = Jid.fromFullJid(bareJid);
    final pubsub = XmppElement()..name = 'pubsub';
    pubsub.addAttribute(XmppAttribute('xmlns', 'http://jabber.org/protocol/pubsub'));
    final items = XmppElement()..name = 'items';
    items.addAttribute(XmppAttribute('node', 'urn:xmpp:avatar:metadata'));
    items.addAttribute(XmppAttribute('max_items', '1'));
    pubsub.addChild(items);
    iqStanza.addChild(pubsub);
    connection.writeStanza(iqStanza);
  }

  void _handleEventMessage(MessageStanza stanza) {
    final event = stanza.children.firstWhere(
      (child) => child.name == 'event' && child.getAttribute('xmlns')?.value == 'http://jabber.org/protocol/pubsub#event',
      orElse: () => XmppElement(),
    );
    if (event.name != 'event') {
      return;
    }
    final items = event.getChild('items');
    if (items == null) {
      return;
    }
    final node = items.getAttribute('node')?.value;
    if (node != 'urn:xmpp:avatar:metadata') {
      return;
    }
    final item = items.getChild('item');
    if (item == null) {
      return;
    }
    final hash = item.getAttribute('id')?.value;
    final metadata = item.children.firstWhere(
      (child) => child.name == 'metadata' && child.getAttribute('xmlns')?.value == 'urn:xmpp:avatar:metadata',
      orElse: () => XmppElement(),
    );
    if (metadata.name != 'metadata') {
      return;
    }
    final info = metadata.getChild('info');
    final mimeType = info?.getAttribute('type')?.value ?? '';
    final bytesRaw = info?.getAttribute('bytes')?.value ?? '';
    final hashValue = info?.getAttribute('id')?.value ?? hash ?? '';
    final bytes = int.tryParse(bytesRaw) ?? 0;
    if (hashValue.isEmpty || mimeType.isEmpty || bytes == 0) {
      return;
    }
    final from = stanza.fromJid?.userAtDomain ?? '';
    if (from.isEmpty) {
      return;
    }
    final metadataEntry = AvatarMetadata(
      hash: hashValue,
      mimeType: mimeType,
      bytes: bytes,
      updatedAt: DateTime.now(),
    );
    _metadataByJid[from] = metadataEntry;
    storage.storeAvatarMetadata(from, metadataEntry);
    if (!_avatarBlobs.containsKey(hashValue)) {
      requestAvatarData(from, hashValue);
    }
    _onUpdate();
  }

  void _handleIqResult(IqStanza stanza) {
    final pending = _pendingDataRequests.remove(stanza.id);
    if (pending == null) {
      return;
    }
    if (stanza.type != IqStanzaType.RESULT) {
      return;
    }
    final pubsub = stanza.getChild('pubsub');
    if (pubsub == null || pubsub.getAttribute('xmlns')?.value != 'http://jabber.org/protocol/pubsub') {
      return;
    }
    final items = pubsub.getChild('items');
    if (items == null || items.getAttribute('node')?.value != 'urn:xmpp:avatar:data') {
      return;
    }
    final item = items.getChild('item');
    final data = item?.getChild('data');
    final base64Data = data?.textValue?.trim();
    if (base64Data == null || base64Data.isEmpty) {
      return;
    }
    _avatarBlobs[pending.hash] = base64Data;
    storage.storeAvatarBlob(pending.hash, base64Data);
    _onUpdate();
  }
}

class _PendingAvatarData {
  _PendingAvatarData({required this.bareJid, required this.hash});

  final String bareJid;
  final String hash;
}
