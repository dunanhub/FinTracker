import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/repositories/push_notification_repository.dart';

class FirebasePushNotificationRepository implements PushNotificationRepository {
  final FirebaseFirestore _firestore;

  FirebasePushNotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> _device({
    required String uid,
    required String deviceId,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('devices')
        .doc(deviceId);
  }

  @override
  Future<void> saveDevice({
    required String uid,
    required String deviceId,
    required String token,
    required String platform,
  }) async {
    await _device(uid: uid, deviceId: deviceId).set({
      'deviceId': deviceId,
      'token': token,
      'platform': platform,
      'enabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> removeDevice({
    required String uid,
    required String deviceId,
  }) async {
    await _device(uid: uid, deviceId: deviceId).delete();
  }
}
