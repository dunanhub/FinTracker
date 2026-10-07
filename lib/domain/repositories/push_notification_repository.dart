abstract class PushNotificationRepository {
  Future<void> saveDevice({
    required String uid,
    required String deviceId,
    required String token,
    required String platform,
  });

  Future<void> removeDevice({required String uid, required String deviceId});
}
