class ChatMessage {
  ChatMessage({
    required this.from,
    required this.to,
    required this.body,
    required this.timestamp,
    required this.outgoing,
  });

  final String from;
  final String to;
  final String body;
  final DateTime timestamp;
  final bool outgoing;
}
