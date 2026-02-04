class RoomEntry {
  RoomEntry({
    required this.roomJid,
    this.nick,
    this.subject,
    this.joined = false,
    this.occupantCount = 0,
  });

  final String roomJid;
  final String? nick;
  final String? subject;
  final bool joined;
  final int occupantCount;

  RoomEntry copyWith({
    String? nick,
    String? subject,
    bool? joined,
    int? occupantCount,
  }) {
    return RoomEntry(
      roomJid: roomJid,
      nick: nick ?? this.nick,
      subject: subject ?? this.subject,
      joined: joined ?? this.joined,
      occupantCount: occupantCount ?? this.occupantCount,
    );
  }
}
