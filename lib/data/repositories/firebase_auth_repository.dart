import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthException implements Exception {
  final String message;

  const AuthException(this.message);

  @override
  String toString() => message;
}

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;

  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  bool _googleInitialized = false;

  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  @override
  AppUser? get currentUser => _mapUser(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() {
    return _auth.authStateChanges().map(_mapUser);
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw const AuthException('Не удалось создать аккаунт.');
      }

      final cleanName = name.trim();

      if (cleanName.isNotEmpty) {
        await user.updateDisplayName(cleanName);

        await user.reload();
      }

      final updatedUser = _auth.currentUser;

      if (updatedUser == null) {
        throw const AuthException('Не удалось загрузить пользователя.');
      }

      return _mapUser(updatedUser)!;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageForCode(error.code, fallback: error.message));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Не удалось создать аккаунт.');
    }
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;

      if (user == null) {
        throw const AuthException('Не удалось выполнить вход.');
      }

      return _mapUser(user)!;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageForCode(error.code, fallback: error.message));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException('Не удалось выполнить вход.');
    }
  }

  @override
  Future<AppUser> signInWithGoogle() async {
    try {
      UserCredential credential;

      if (kIsWeb) {
        final provider = GoogleAuthProvider();

        credential = await _auth.signInWithPopup(provider);
      } else {
        await _initializeGoogle();

        if (!_googleSignIn.supportsAuthenticate()) {
          throw const AuthException('Google Sign-In недоступен.');
        }

        final googleUser = await _googleSignIn.authenticate();

        final authentication = googleUser.authentication;

        final idToken = authentication.idToken;

        if (idToken == null || idToken.isEmpty) {
          throw const AuthException('Google не вернул ID Token.');
        }

        final googleCredential = GoogleAuthProvider.credential(
          idToken: idToken,
        );

        credential = await _auth.signInWithCredential(googleCredential);
      }

      final user = credential.user;

      if (user == null) {
        throw const AuthException('Не удалось войти через Google.');
      }

      return _mapUser(user)!;
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageForCode(error.code, fallback: error.message));
    } on AuthException {
      rethrow;
    } catch (_) {
      throw const AuthException(
        'Вход через Google был отменён '
        'или завершился ошибкой.',
      );
    }
  }

  @override
  Future<void> sendPasswordReset({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthException(_messageForCode(error.code, fallback: error.message));
    }
  }

  @override
  Future<void> signOut() async {
    await _auth.signOut();

    if (!kIsWeb) {
      try {
        await _initializeGoogle();
        await _googleSignIn.signOut();
      } catch (_) {
        // Firebase session уже завершена.
      }
    }
  }

  Future<void> _initializeGoogle() async {
    if (_googleInitialized) {
      return;
    }

    await _googleSignIn.initialize();

    _googleInitialized = true;
  }

  AppUser? _mapUser(User? user) {
    if (user == null) {
      return null;
    }

    return AppUser(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
      photoUrl: user.photoURL,
    );
  }

  String _messageForCode(String code, {String? fallback}) {
    switch (code) {
      case 'invalid-email':
        return 'Некорректный email.';

      case 'email-already-in-use':
        return 'Этот email уже зарегистрирован.';

      case 'weak-password':
        return 'Пароль слишком простой. '
            'Минимум 6 символов.';

      case 'user-disabled':
        return 'Аккаунт отключён.';

      case 'user-not-found':
        return 'Пользователь не найден.';

      case 'wrong-password':
      case 'invalid-credential':
        return 'Неверный email или пароль.';

      case 'too-many-requests':
        return 'Слишком много попыток. '
            'Попробуй позже.';

      case 'network-request-failed':
        return 'Нет подключения к интернету.';

      case 'operation-not-allowed':
        return 'Этот способ входа не включён '
            'в Firebase.';

      case 'account-exists-with-different-credential':
        return 'Этот email уже используется '
            'другим способом входа.';

      default:
        return fallback ?? 'Ошибка авторизации.';
    }
  }
}
