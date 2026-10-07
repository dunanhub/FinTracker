# Android сборки и подпись

Приложение использует `applicationId = com.example.fin_tracker`. `version: 1.0.0+1` в `pubspec.yaml` передаётся Flutter как Android `versionName = 1.0.0` и `versionCode = 1`.

## Debug

```sh
flutter pub get
flutter build apk --debug
```

Результат: `build/app/outputs/flutter-apk/app-debug.apk`. GitHub Actions собирает только debug APK и Web; release ключ в CI не загружается.

## Release

`android/app/build.gradle.kts` читает секреты из локального `android/key.properties` и применяет отдельный `signingConfigs.release`. Подпись debug ключом для release запрещена. Файл ключа хранится в `android/app/fintracker-release.jks`; `storeFile=app/fintracker-release.jks` в properties считается относительно `android/`. Шаблон без секретов — [`android/key.properties.example`](../android/key.properties.example).

Пример структуры **локального** файла (подставить собственные значения, не коммитить):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=fintracker
storeFile=app/fintracker-release.jks
```

Если ключ ещё не создан, из корня проекта в PowerShell можно вызвать `keytool`; пароль вводится интерактивно:

```powershell
& 'D:\Android Studio\jbr\bin\keytool.exe' -genkeypair -v `
  -keystore 'android\app\fintracker-release.jks' `
  -storetype PKCS12 -keyalg RSA -keysize 4096 `
  -validity 10000 -alias fintracker
```

После настройки приватных файлов:

```sh
flutter build apk --release
flutter build appbundle --release
```

Ожидаемые результаты: `build/app/outputs/flutter-apk/app-release.apk` и `build/app/outputs/bundle/release/app-release.aab`. Локальные файлы от 8 октября 2026 года существуют. `apksigner verify --verbose` подтвердил один подписант и APK Signature Scheme v2; `jarsigner -verify` вывел `jar verified` для AAB с предупреждениями о самоподписанном сертификате и отсутствии timestamp. Это проверка локальных артефактов, не публикация.

Пример проверки APK в текущем Windows SDK:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\build-tools\36.0.0\apksigner.bat" verify --verbose 'build\app\outputs\flutter-apk\app-release.apk'
```

Release keystore и пароли нужно сохранить в защищённой резервной копии: без ключа нельзя выпускать обновления, подписанные той же идентичностью. Перед распространением проверить вход Google с отпечатком release сертификата и работоспособность Firebase на установленной release сборке. `android/key.properties`, `*.jks`, `*.keystore` и `google-services.json` игнорируются Git. Play Console publishing этим документом не выполняется.
