enum AppThemePreset { white, black, gray, pink, navy, blue }

extension AppThemePresetX on AppThemePreset {
  String get title {
    switch (this) {
      case AppThemePreset.white:
        return 'Белый';
      case AppThemePreset.black:
        return 'Чёрный';
      case AppThemePreset.gray:
        return 'Серый';
      case AppThemePreset.pink:
        return 'Розовый';
      case AppThemePreset.navy:
        return 'Тёмно-синий';
      case AppThemePreset.blue:
        return 'Синий';
    }
  }
}
