import 'package:flutter_test/flutter_test.dart';
import 'package:wimsy/models/chat_message.dart';

void main() {
  test('ChatMessage serializes reactions and raw XML', () {
    final message = ChatMessage(
      from: 'alice@example.com',
      to: 'bob@example.com',
      body: 'hello',
      timestamp: DateTime.parse('2024-08-09T10:11:12Z'),
      outgoing: false,
      messageId: 'msg-1',
      rawXml: '<message id="msg-1"><body>hello</body></message>',
      reactions: const {
        '👍': ['alice@example.com', 'bob@example.com'],
      },
    );

    final roundtrip = ChatMessage.fromMap(message.toMap());
    expect(roundtrip, isNotNull);
    expect(roundtrip!.rawXml, contains('<message'));
    expect(roundtrip.reactions, isNotNull);
    expect(roundtrip.reactions!['👍'], ['alice@example.com', 'bob@example.com']);
  });

  test('ChatMessage rejects cached entries without raw XML', () {
    final roundtrip = ChatMessage.fromMap({
      'from': 'alice@example.com',
      'to': 'bob@example.com',
      'body': 'hello',
      'timestamp': '2024-08-09T10:11:12Z',
      'outgoing': false,
      'messageId': 'msg-1',
    });

    expect(roundtrip, isNull);
  });
}
