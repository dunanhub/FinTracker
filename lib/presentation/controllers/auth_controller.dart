import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/entities/app_user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../domain/repositories/user_profile_repository.dart';

class AuthController extends ChangeNotifier {
  final AuthRepository repository;

  final UserProfileRepository profileRepository;

  StreamSubscription<AppUser?>? _subscription;

  AppUser? _user;

  bool _loading = false;

  String? _errorMessage;

  AuthController({required this.repository, required this.profileRepository}) {
    _user = repository.currentUser;

    _subscription = repository.authStateChanges().listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  AppUser? get user => _user;

  bool get isAuthenticated => _user != null;

  bool get isLoading => _loading;

  String? get errorMessage => _errorMessage;

  Future<bool> register({
    required String name,
    required String email,
    required String password,
  }) async {
    return _authenticate(
      () => repository.register(name: name, email: email, password: password),
    );
  }

  Future<bool> signIn({required String email, required String password}) async {
    return _authenticate(
      () => repository.signIn(email: email, password: password),
    );
  }

  Future<bool> signInWithGoogle() async {
    return _authenticate(repository.signInWithGoogle);
  }

  Future<bool> resetPassword(String email) async {
    final clean = email.trim();

    if (clean.isEmpty) {
      _errorMessage = 'Введите email.';
      notifyListeners();

      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      await repository.sendPasswordReset(email: clean);

      return true;
    } catch (error) {
      _errorMessage = error.toString();

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> signOut() async {
    _setLoading(true);
    _errorMessage = null;

    try {
      await repository.signOut();

      _user = null;

      return true;
    } catch (error) {
      _errorMessage = error.toString();

      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> _authenticate(Future<AppUser> Function() action) async {
    if (_loading) {
      return false;
    }

    _setLoading(true);
    _errorMessage = null;

    try {
      final user = await action();

      _user = user;

      try {
        await profileRepository.saveProfile(user);
      } catch (_) {
        // Auth остаётся рабочим,
        // даже если Firestore временно недоступен.
      }

      return true;
    } catch (error) {
      _errorMessage = error.toString();

      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();

    super.dispose();
  }
}
