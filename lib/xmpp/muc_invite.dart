import 'package:xmpp_stone/xmpp_stone.dart';

const String mucDirectInviteNamespace = 'jabber:x:conference';
const String _mucUserNamespace = 'http://jabber.org/protocol/muc#user';

class MucDirectInvite {
  MucDirectInvite({
    required this.roomJid,
    this.reason,
    this.password,
  });

  final String roomJid;
  final String? reason;
  final String? password;
}

MucDirectInvite? parseMucDirectInvite(MessageStanza stanza) {
  for (final child in stanza.children) {
    if (child.name != 'x') {
      continue;
    }
    if (child.getAttribute('xmlns')?.value != mucDirectInviteNamespace) {
      continue;
    }
    final roomJid = child.getAttribute('jid')?.value?.trim() ?? '';
    if (roomJid.isEmpty) {
      return null;
    }
    final reason = _trimmed(child.getAttribute('reason')?.value);
    final password = _trimmed(child.getAttribute('password')?.value);
    return MucDirectInvite(
      roomJid: roomJid,
      reason: reason,
      password: password,
    );
  }
  return null;
}

bool isMucMediatedInvite(MessageStanza stanza) {
  for (final child in stanza.children) {
    if (child.name != 'x') {
      continue;
    }
    if (child.getAttribute('xmlns')?.value != _mucUserNamespace) {
      continue;
    }
    final invite = child.getChild('invite');
    if (invite == null) {
      continue;
    }
    return true;
  }
  return false;
}

String? _trimmed(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
