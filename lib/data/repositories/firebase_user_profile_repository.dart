import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/user_profile_repository.dart';

class FirebaseUserProfileRepository implements UserProfileRepository {
  final FirebaseFirestore _firestore;

  FirebaseUserProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  @override
  Future<void> saveProfile(AppUser user) async {
    final reference = _firestore.collection('users').doc(user.uid);

    final old = await reference.get();

    final data = <String, dynamic>{
      'uid': user.uid,
      'email': user.email,
      'displayName': user.displayName,
      'photoUrl': user.photoUrl,
      'lastLoginAt': FieldValue.serverTimestamp(),
    };

    if (!old.exists) {
      data['createdAt'] = FieldValue.serverTimestamp();
    }

    await reference.set(data, SetOptions(merge: true));
  }
}
