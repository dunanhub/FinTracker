import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/repositories/push_notification_repository.dart';
import 'auth_controller.dart';
import 'notification_center_controller.dart';

class PushMessageInfo {
  final String? title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime receivedAt;

  const PushMessageInfo({
    this.title,
    this.body,
    required this.data,
    required this.receivedAt,
  });
}

class PushNotificationController extends ChangeNotifier {
  static const String _deviceIdKey = 'fintracker_push_device_id';

  final AuthController authController;

  final PushNotificationRepository repository;
  final NotificationCenterController? notificationCenter;

  final FirebaseMessaging _messaging;

  PushNotificationController({
    required this.authController,
    required this.repository,
    this.notificationCenter,
    FirebaseMessaging? messaging,
  }) : _messaging = messaging ?? FirebaseMessaging.instance;

  AuthorizationStatus _permissionStatus = AuthorizationStatus.notDetermined;

  String? _token;
  String? _deviceId;
  String? _activeUid;
  String? _errorMessage;

  PushMessageInfo? _lastMessage;

  bool _busy = false;
  bool _started = false;
  bool _handlingAuth = false;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;

  AuthorizationStatus get permissionStatus => _permissionStatus;

  String? get token => _token;

  String? get errorMessage => _errorMessage;

  PushMessageInfo? get lastMessage => _lastMessage;

  bool get isBusy => _busy;

  bool get isEnabled =>
      _permissionStatus == AuthorizationStatus.authorized ||
      _permissionStatus == AuthorizationStatus.provisional;

  String get permissionLabel {
    switch (_permissionStatus) {
      case AuthorizationStatus.authorized:
        return 'Разрешены';

      case AuthorizationStatus.provisional:
        return 'Разрешены частично';

      case AuthorizationStatus.denied:
        return 'Запрещены';

      case AuthorizationStatus.deniedPermanently:
        return 'Запрещены навсегда';

      case AuthorizationStatus.notDetermined:
        return 'Не настроены';
    }
  }

  String get tokenPreview {
    final value = _token;

    if (value == null || value.isEmpty) {
      return 'Токен ещё не получен';
    }

    if (value.length <= 28) {
      return value;
    }

    return '${value.substring(0, 14)}...'
        '${value.substring(value.length - 10)}';
  }

  Future<void> start() async {
    if (_started) {
      return;
    }

    _started = true;

    final preferences = await SharedPreferences.getInstance();

    _deviceId = preferences.getString(_deviceIdKey);

    if (_deviceId == null) {
      _deviceId = 'device-${DateTime.now().microsecondsSinceEpoch}';

      await preferences.setString(_deviceIdKey, _deviceId!);
    }

    authController.addListener(_onAuthChanged);

    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      (message) => _handleMessage(message, opened: false),
    );

    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => _handleMessage(message, opened: true),
    );

    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      _token = token;

      notifyListeners();

      unawaited(_saveToken());
    });

    final initialMessage = await _messaging.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage, opened: true);
    }

    await _handleAuthChanged();
  }

  void _onAuthChanged() {
    unawaited(_handleAuthChanged());
  }

  Future<void> _handleAuthChanged() async {
    if (_handlingAuth) {
      return;
    }

    _handlingAuth = true;

    try {
      final newUid = authController.user?.uid;

      if (newUid == _activeUid) {
        return;
      }

      final oldUid = _activeUid;

      if (oldUid != null && _deviceId != null) {
        try {
          await repository.removeDevice(uid: oldUid, deviceId: _deviceId!);
        } catch (_) {
          // Выход не блокируем из-за сети.
        }
      }

      _activeUid = newUid;

      if (newUid == null) {
        _token = null;
        _errorMessage = null;
        _permissionStatus = AuthorizationStatus.notDetermined;

        notifyListeners();

        return;
      }

      await requestPermission();
    } finally {
      _handlingAuth = false;
    }
  }

  Future<void> requestPermission() async {
    if (_busy) {
      return;
    }

    _busy = true;
    _errorMessage = null;

    notifyListeners();

    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      _permissionStatus = settings.authorizationStatus;

      if (isEnabled) {
        await _loadToken();
      }
    } catch (error) {
      _errorMessage = 'Не удалось настроить уведомления: $error';
    } finally {
      _busy = false;

      notifyListeners();
    }
  }

  Future<void> refreshToken() async {
    if (_busy || !isEnabled) {
      return;
    }

    _busy = true;
    _errorMessage = null;

    notifyListeners();

    try {
      await _loadToken();
    } catch (error) {
      _errorMessage = 'Не удалось получить FCM token: $error';
    } finally {
      _busy = false;

      notifyListeners();
    }
  }

  Future<void> _loadToken() async {
    if (kIsWeb) {
      _errorMessage =
          'Web Push пока не настроен. '
          'Android FCM работает отдельно.';

      return;
    }

    final token = await _messaging.getToken();

    if (token == null || token.isEmpty) {
      _errorMessage = 'Firebase не вернул FCM token.';

      return;
    }

    _token = token;

    await _saveToken();
  }

  Future<void> _saveToken() async {
    final uid = _activeUid;

    final deviceId = _deviceId;

    final token = _token;

    if (uid == null || deviceId == null || token == null || token.isEmpty) {
      return;
    }

    try {
      await repository.saveDevice(
        uid: uid,
        deviceId: deviceId,
        token: token,
        platform: _platformName(),
      );
    } catch (error) {
      _errorMessage =
          'Токен получен, но не удалось '
          'сохранить его в Firestore: $error';

      notifyListeners();
    }
  }

  void _handleMessage(RemoteMessage message, {required bool opened}) {
    _lastMessage = PushMessageInfo(
      title: message.notification?.title,
      body: message.notification?.body,
      data: Map<String, dynamic>.from(message.data),
      receivedAt: DateTime.now(),
    );

    notifyListeners();
    final center = notificationCenter;
    if (center != null) {
      unawaited(
        center.recordPush(
          id:
              message.messageId ??
              '${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}:${message.data.hashCode}',
          title: message.notification?.title ?? 'Уведомление',
          body: message.notification?.body ?? '',
          data: message.data,
          opened: opened,
        ),
      );
    }
  }

  String _platformName() {
    if (kIsWeb) {
      return 'web';
    }

    return defaultTargetPlatform.name;
  }

  @override
  void dispose() {
    authController.removeListener(_onAuthChanged);

    _foregroundSubscription?.cancel();
    _openedSubscription?.cancel();
    _tokenSubscription?.cancel();

    super.dispose();
  }
}
