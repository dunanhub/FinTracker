# Тестирование FinTracker

Проверено локально 8 октября 2026 года: **77 тестов прошли**, LCOV: **49,50%** (`4872 / 9842` строк, 73 включённых файла). Порог проекта — **40%**. Число относится к `coverage/lcov.info`: Flutter не включает в него каждый нетронутый файл `lib`.

## Команды

```sh
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test --coverage
dart run tool/check_coverage.dart
flutter build apk --debug
flutter build web
```

`tool/check_coverage.dart` возвращает ненулевой код при отсутствии/повреждении LCOV или покрытии ниже 40%. В CI тесты запускаются один раз с `--coverage`; тот же результат служит основным test run и источником LCOV.

## Что покрывают тесты

| Область | Примеры |
|---|---|
| Финансовая логика | Доходы, расходы, переводы, редактирование/удаление и балансы: `finance_controller_business_test.dart` |
| Бюджеты, цели, долги | Пополнение цели, погашение долга и учёт суммы: `budget_goal_debt_business_test.dart`, `finance_features_widget_test.dart` |
| Hive и чек | Чтение старых записей, независимые локальный/облачный пути, ошибки загрузки: `hive_repositories_test.dart`, `receipt_persistence_test.dart`, `sync_receipt_failure_test.dart` |
| Графики и Dashboard | Даты и суммы, жесты, пустые данные, темы, узкий экран: `chart_interaction_test.dart`, `dashboard_design_test.dart` |
| Riverpod и диагностика | Async состояния валют, конвертация, MethodChannel и ошибки: `currency_rates_provider_test.dart`, `currency_and_diagnostics_widget_test.dart`, `device_diagnostics_test.dart` |
| Уведомления, датчик, Crashlytics | Планирование, история по UID, FCM дедупликация, порог/cooldown, fake crash reporter: `notification_center_test.dart`, `shake_detector_service_test.dart`, `crash_reporting_service_test.dart` |
| Настройки и калькулятор | Сохранение темы/датчика, режимы расчёта: `settings_calculator_test.dart` |

Общие подмены репозиториев находятся в [`test/helpers/fake_repositories.dart`](../test/helpers/fake_repositories.dart). Тесты Crashlytics используют fake reporter, а тесты валют — переопределение Riverpod provider; реальный Firebase SDK, сетевой API и физический датчик в unit/widget тестах не вызываются.

## CI и ручная проверка

Workflow [`ci.yml`](../.github/workflows/ci.yml) запускается на push и pull request в `main`, проверяет формат, анализ, тесты/покрытие и собирает debug APK и Web. APK и LCOV сохраняются на 7 дней. Последний проверенный [запуск на GitHub](https://github.com/dunanhub/FinTracker/actions/runs/37673945899) завершился успешно.

Перед демонстрацией на Android вручную проверить вход, синхронизацию между двумя устройствами, загрузку чека, разрешения камеры/геолокации/уведомлений, локальное напоминание и встряхивание. Замеры кадров, CPU и памяти описаны в [`performance.md`](performance.md).
