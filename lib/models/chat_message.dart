class ChatMessage {
  ChatMessage({
    required this.from,
    required this.to,
    required this.body,
    required this.timestamp,
    required this.outgoing,
    this.messageId,
    this.mamId,
    this.stanzaId,
  });

  final String from;
  final String to;
  final String body;
  final DateTime timestamp;
  final bool outgoing;
  final String? messageId;
  final String? mamId;
  final String? stanzaId;

  Map<String, dynamic> toMap() {
    return {
      'from': from,
      'to': to,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'outgoing': outgoing,
      'messageId': messageId,
      'mamId': mamId,
      'stanzaId': stanzaId,
    };
  }

  static ChatMessage? fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }
    final from = map['from']?.toString() ?? '';
    final to = map['to']?.toString() ?? '';
    final body = map['body']?.toString() ?? '';
    final ts = map['timestamp']?.toString() ?? '';
    final outgoing = map['outgoing'] == true;
    final messageId = map['messageId']?.toString();
    final mamId = map['mamId']?.toString();
    final stanzaId = map['stanzaId']?.toString();
    if (from.isEmpty || to.isEmpty || body.isEmpty || ts.isEmpty) {
      return null;
    }
    final timestamp = DateTime.tryParse(ts);
    if (timestamp == null) {
      return null;
    }
    return ChatMessage(
      from: from,
      to: to,
      body: body,
      timestamp: timestamp,
      outgoing: outgoing,
      messageId: messageId,
      mamId: mamId,
      stanzaId: stanzaId,
    );
  }
}
