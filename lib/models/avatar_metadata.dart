class AvatarMetadata {
  AvatarMetadata({
    required this.hash,
    required this.mimeType,
    required this.bytes,
    required this.updatedAt,
  });

  final String hash;
  final String mimeType;
  final int bytes;
  final DateTime updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'hash': hash,
      'mimeType': mimeType,
      'bytes': bytes,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  static AvatarMetadata? fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }
    final hash = map['hash']?.toString() ?? '';
    final mimeType = map['mimeType']?.toString() ?? '';
    final bytesRaw = map['bytes'];
    final updatedRaw = map['updatedAt']?.toString() ?? '';
    final bytes = bytesRaw is int ? bytesRaw : int.tryParse(bytesRaw?.toString() ?? '') ?? 0;
    final updatedAt = DateTime.tryParse(updatedRaw);
    if (hash.isEmpty || mimeType.isEmpty || bytes == 0 || updatedAt == null) {
      return null;
    }
    return AvatarMetadata(
      hash: hash,
      mimeType: mimeType,
      bytes: bytes,
      updatedAt: updatedAt,
    );
  }
}
