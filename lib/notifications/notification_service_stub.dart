class NotificationService {
  Future<void> initialize() async {}

  Future<void> showMessage({
    required int id,
    required String title,
    required String body,
    String? tag,
  }) async {}

  bool get isInitialized => true;
}
