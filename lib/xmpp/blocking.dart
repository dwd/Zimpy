import 'package:xmpp_stone/xmpp_stone.dart';

const String blockingNamespace = 'urn:xmpp:blocking';

List<String> parseBlocklistIq(IqStanza stanza) {
  if (stanza.type != IqStanzaType.RESULT) {
    return const [];
  }
  final blocklist = stanza.children.firstWhere(
    (child) => child.name == 'blocklist' && child.getAttribute('xmlns')?.value == blockingNamespace,
    orElse: () => XmppElement(),
  );
  if (blocklist.name != 'blocklist') {
    return const [];
  }
  return _parseBlockItems(blocklist);
}

BlockingUpdate? parseBlockingUpdate(IqStanza stanza) {
  final element = stanza.children.firstWhere(
    (child) =>
        (child.name == 'block' || child.name == 'unblock') &&
        child.getAttribute('xmlns')?.value == blockingNamespace,
    orElse: () => XmppElement(),
  );
  if (element.name != 'block' && element.name != 'unblock') {
    return null;
  }
  final items = _parseBlockItems(element);
  return BlockingUpdate(
    isBlock: element.name == 'block',
    items: items,
  );
}

List<String> _parseBlockItems(XmppElement element) {
  final items = <String>[];
  for (final child in element.children.where((child) => child.name == 'item')) {
    final jid = child.getAttribute('jid')?.value?.trim() ?? '';
    if (jid.isNotEmpty) {
      items.add(jid);
    }
  }
  return items;
}

class BlockingUpdate {
  BlockingUpdate({
    required this.isBlock,
    required this.items,
  });

  final bool isBlock;
  final List<String> items;
}
