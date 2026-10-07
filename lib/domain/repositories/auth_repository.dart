import '../entities/app_user.dart';

abstract class AuthRepository {
  AppUser? get currentUser;

  Stream<AppUser?> authStateChanges();

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  });

  Future<AppUser> signIn({required String email, required String password});

  Future<AppUser> signInWithGoogle();

  Future<void> sendPasswordReset({required String email});

  Future<void> signOut();
}
