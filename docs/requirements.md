# Соответствие требованиям курсовой

Статус отражает **код и локальные проверки**, а не только заявленные возможности. «Альтернатива» означает реализованную функцию другой технологией; «Частично» — ограничение, которое стоит назвать на защите.

| Requirement | Status | Implementation | Files / Evidence |
|---|---|---|---|
| Null safety | Выполнено | Dart с sound null safety и nullable полями | [`pubspec.yaml`](../pubspec.yaml), [`finance_transaction.dart`](../lib/domain/entities/finance_transaction.dart) |
| Layered architecture | Выполнено | `core`, `domain`, `data`, `presentation` | [`architecture.md`](architecture.md), [`lib/`](../lib/) |
| Repository | Выполнено | Контракты в domain и реализации для Hive/Firebase/REST | [`finance_repository.dart`](../lib/domain/repositories/finance_repository.dart), [`hive_finance_repository.dart`](../lib/data/repositories/hive_finance_repository.dart) |
| Dependency injection | Выполнено | Создание зависимостей в `main`, передача через конструкторы и Provider | [`main.dart`](../lib/main.dart), [`app.dart`](../lib/app.dart) |
| Material 3 | Выполнено | `ThemeData(useMaterial3: true)` | [`app_theme.dart`](../lib/core/theme/app_theme.dart) |
| Не менее 5 экранов | Выполнено | Вход, Dashboard, операции, аналитика, счета, бюджеты и другие | [`app_router.dart`](../lib/core/router/app_router.dart), [`main_shell.dart`](../lib/presentation/shell/main_shell.dart) |
| Light/dark/custom themes | Выполнено | Режим темы и шесть цветовых вариантов | [`theme_controller.dart`](../lib/core/theme/theme_controller.dart), [`theme_preset.dart`](../lib/core/theme/theme_preset.dart) |
| Adaptive UI | Частично | Узкая ширина и крупный текст учтены на Dashboard/навигации; полного аудита планшета нет | [`dashboard_screen.dart`](../lib/presentation/screens/dashboard_screen.dart), [`dashboard_design_test.dart`](../test/dashboard_design_test.dart) |
| Provider | Выполнено | Основные контроллеры и состояние приложения | [`app.dart`](../lib/app.dart) |
| Riverpod или BLoC | Выполнено (Riverpod) | Самостоятельный сценарий валют через `AsyncNotifier` | [`currency_rates_provider.dart`](../lib/presentation/providers/currency_rates_provider.dart), [`currency_rates_screen.dart`](../lib/presentation/screens/currency_rates_screen.dart) |
| REST API | Выполнено | Frankfurter API курсов через Dio | [`frankfurter_currency_repository.dart`](../lib/data/repositories/frankfurter_currency_repository.dart) |
| JSON mapping | Выполнено | Ручное преобразование API и Firestore/Hive карт в сущности | [`frankfurter_currency_repository.dart`](../lib/data/repositories/frankfurter_currency_repository.dart), [`firebase_sync_repository.dart`](../lib/data/sync/firebase_sync_repository.dart) |
| Error states | Выполнено | Состояния загрузки/ошибки валют и синхронизации, повторная попытка | [`currency_rates_screen.dart`](../lib/presentation/screens/currency_rates_screen.dart), [`sync_controller.dart`](../lib/presentation/controllers/sync_controller.dart) |
| SharedPreferences | Выполнено | Тема, настройка встряхивания, идентификатор устройства и очередь sync | [`theme_controller.dart`](../lib/core/theme/theme_controller.dart), [`sync_controller.dart`](../lib/presentation/controllers/sync_controller.dart) |
| Hive / offline | Выполнено с условием | Данные после входа доступны локально в области UID; первичный вход зависит от Auth | [`hive_finance_repository.dart`](../lib/data/repositories/hive_finance_repository.dart), [`sync_controller.dart`](../lib/presentation/controllers/sync_controller.dart) |
| GoRouter | Выполнено | Auth redirect и маршруты приложения | [`app_router.dart`](../lib/core/router/app_router.dart) |
| Firebase Auth | Выполнено | Email/пароль, Google Sign-In, восстановление пароля | [`firebase_auth_repository.dart`](../lib/data/repositories/firebase_auth_repository.dart) |
| Firestore | Выполнено | Пользовательские коллекции и метадокумент синхронизации | [`firebase_sync_repository.dart`](../lib/data/sync/firebase_sync_repository.dart) |
| Firebase Storage | Выполнено | Версионированные облачные объекты чеков и локальный кеш | [`firebase_receipt_storage_repository.dart`](../lib/data/repositories/firebase_receipt_storage_repository.dart), [`storage.rules`](../storage.rules) |
| Firebase Messaging | Выполнено с ограничением | FCM токен, приём и открытие push; серверная автоматическая отправка не реализована | [`push_notification_controller.dart`](../lib/presentation/controllers/push_notification_controller.dart) |
| Map / geolocation | Альтернатива Google Maps | OpenStreetMap через `flutter_map`, координаты через `geolocator`; Google Maps SDK не используется | [`transaction_map_screen.dart`](../lib/presentation/screens/transaction_map_screen.dart), [`location_service.dart`](../lib/data/services/location_service.dart) |
| Camera / gallery | Выполнено | `image_picker`, локальный файл чека и облачная копия | [`receipt_image_service.dart`](../lib/data/services/receipt_image_service.dart) |
| Sensors | Выполнено | `userAccelerometer`, порог и cooldown для Shake to Add | [`shake_detector_service.dart`](../lib/data/services/shake_detector_service.dart), [`main_shell.dart`](../lib/presentation/shell/main_shell.dart) |
| Own Kotlin Platform Channel | Выполнено | `getBatteryInfo`, `getDeviceInfo` | [`MainActivity.kt`](../android/app/src/main/kotlin/com/example/fin_tracker/MainActivity.kt), [`platform_native_device_repository.dart`](../lib/data/repositories/platform_native_device_repository.dart) |
| Tests > 40% | Выполнено | 77 тестов, LCOV 49,50%, порог 40% | [`testing.md`](testing.md), [`check_coverage.dart`](../tool/check_coverage.dart) |
| Performance review | Выполнено как аудит | Оптимизации графика, карты, миниатюры; измерения FPS/памяти остаются ручной проверкой | [`performance.md`](performance.md) |
| Firebase Crashlytics | Выполнено для Android | Глобальные обработчики и тестовая non-fatal ошибка; debug collection выключен | [`crash_reporting_service.dart`](../lib/data/services/crash_reporting_service.dart), [`main.dart`](../lib/main.dart) |
| CI/CD | Частично: CI | GitHub Actions проверяет код и собирает debug APK/Web; автоматического deploy нет | [`ci.yml`](../.github/workflows/ci.yml), [успешный запуск](https://github.com/dunanhub/FinTracker/actions/runs/37673945899) |
| Signed release | Выполнено локально | Release signing config; APK и AAB собраны, подписи проверены локально | [`build.gradle.kts`](../android/app/build.gradle.kts), [`release.md`](release.md) |

## Что отдельно обсудить на защите

- Если требуется **буквально Google Maps**, текущая OpenStreetMap реализация закрывает картографический сценарий альтернативной технологией.
- Синхронизация работает снимками коллекций и не выполняет слияние конфликтующих изменений по полям.
- История уведомлений локальная; Web Push и автоматическая серверная отправка FCM не настроены.
- Исходник правил Firebase Storage есть в репозитории, но правил Firestore здесь нет. Фактические развёрнутые правила следует показать в Firebase Console; документация не подтверждает их состояние.
- CI собирает и тестирует, но не развёртывает приложение автоматически. Отдельные замеры производительности на устройстве нужно провести через DevTools.
