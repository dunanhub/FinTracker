import '../entities/app_user.dart';

abstract class UserProfileRepository {
  Future<void> saveProfile(AppUser user);
}
