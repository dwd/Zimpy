class AccountRecord {
  AccountRecord({
    required this.jid,
    required this.password,
    required this.host,
    required this.port,
    required this.resource,
  });

  final String jid;
  final String password;
  final String host;
  final int port;
  final String resource;

  Map<String, dynamic> toMap() {
    return {
      'jid': jid,
      'password': password,
      'host': host,
      'port': port,
      'resource': resource,
    };
  }

  static AccountRecord? fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return null;
    }
    final jid = map['jid']?.toString() ?? '';
    final password = map['password']?.toString() ?? '';
    final host = map['host']?.toString() ?? '';
    final portRaw = map['port'];
    final resource = map['resource']?.toString() ?? '';
    final port = portRaw is int ? portRaw : int.tryParse(portRaw?.toString() ?? '') ?? 5222;
    if (jid.isEmpty || password.isEmpty) {
      return null;
    }
    return AccountRecord(
      jid: jid,
      password: password,
      host: host,
      port: port,
      resource: resource,
    );
  }
}
