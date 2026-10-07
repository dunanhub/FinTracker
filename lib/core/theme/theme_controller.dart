import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_preset.dart';

class ThemeController extends ChangeNotifier {
  static const String _presetKey = 'theme_preset';
  static const String _modeKey = 'theme_mode';

  AppThemePreset _preset = AppThemePreset.navy;
  ThemeMode _themeMode = ThemeMode.system;

  AppThemePreset get preset => _preset;

  ThemeMode get themeMode => _themeMode;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();

    final presetName = preferences.getString(_presetKey);
    final modeName = preferences.getString(_modeKey);

    if (presetName != null) {
      try {
        _preset = AppThemePreset.values.byName(presetName);
      } catch (_) {
        _preset = AppThemePreset.navy;
      }
    }

    if (modeName != null) {
      try {
        _themeMode = ThemeMode.values.byName(modeName);
      } catch (_) {
        _themeMode = ThemeMode.system;
      }
    }
  }

  Future<void> setPreset(AppThemePreset preset) async {
    if (_preset == preset) {
      return;
    }

    _preset = preset;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_presetKey, preset.name);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }

    _themeMode = mode;
    notifyListeners();

    final preferences = await SharedPreferences.getInstance();

    await preferences.setString(_modeKey, mode.name);
  }
}
