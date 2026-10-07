import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShakeSettingsController extends ChangeNotifier {
  static const String _enabledKey = 'shake_to_add_enabled';

  bool _enabled = true;

  bool get enabled => _enabled;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _enabled = preferences.getBool(_enabledKey) ?? true;
    notifyListeners();
  }

  Future<void> setEnabled(bool enabled) async {
    if (_enabled == enabled) return;
    _enabled = enabled;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_enabledKey, enabled);
  }
}
