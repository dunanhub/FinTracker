import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/platform_native_device_repository.dart';
import '../../data/services/crash_reporting_service.dart';
import '../../domain/entities/native_device_info.dart';
import '../../domain/repositories/native_device_repository.dart';
import '../controllers/device_diagnostics_controller.dart';

class DeviceDiagnosticsPage extends StatelessWidget {
  final NativeDeviceRepository? repository;
  final CrashReportingService? crashReporting;

  const DeviceDiagnosticsPage({
    super.key,
    this.repository,
    this.crashReporting,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create:
          (_) => DeviceDiagnosticsController(
            repository: repository ?? PlatformNativeDeviceRepository(),
            crashReporting:
                crashReporting ??
                Provider.of<CrashReportingService?>(context, listen: false),
          )..refresh(),
      child: const DeviceDiagnosticsScreen(),
    );
  }
}

class DeviceDiagnosticsScreen extends StatelessWidget {
  const DeviceDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DeviceDiagnosticsController>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Диагностика устройства')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          Text(
            'Данные Android устройства и батареи',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          switch (controller.status) {
            DeviceDiagnosticsStatus.initial ||
            DeviceDiagnosticsStatus.loading => const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: CircularProgressIndicator(),
              ),
            ),
            DeviceDiagnosticsStatus.unsupported => const _MessageCard(
              icon: Icons.info_outline_rounded,
              message: 'Нативная диагностика доступна только на Android',
            ),
            DeviceDiagnosticsStatus.error => _MessageCard(
              icon: Icons.error_outline_rounded,
              message:
                  controller.errorMessage ??
                  'Не удалось получить данные устройства.',
            ),
            DeviceDiagnosticsStatus.loaded => Column(
              children: [
                _DiagnosticsCard(
                  title: 'Устройство',
                  icon: Icons.smartphone_rounded,
                  rows: [
                    ('Производитель', _value(controller.device?.manufacturer)),
                    ('Модель', _value(controller.device?.model)),
                    ('Android', _value(controller.device?.androidVersion)),
                    (
                      'SDK',
                      controller.device?.sdkInt?.toString() ?? 'Недоступно',
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _DiagnosticsCard(
                  title: 'Батарея',
                  icon: Icons.battery_std_rounded,
                  rows: [
                    ('Заряд', _batteryLevel(controller.battery)),
                    ('Статус зарядки', _chargingStatus(controller.battery)),
                    ('Источник питания', _powerSource(controller.battery)),
                  ],
                ),
              ],
            ),
          },
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed:
                controller.status == DeviceDiagnosticsStatus.loading ||
                        controller.status == DeviceDiagnosticsStatus.unsupported
                    ? null
                    : controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Обновить данные'),
          ),
          const SizedBox(height: 24),
          _DiagnosticsCard(
            title: 'Crashlytics',
            icon: Icons.bug_report_outlined,
            rows: [
              (
                'Статус',
                controller.canSendTestError
                    ? 'Тестовая отправка доступна'
                    : 'Доступно только на Android',
              ),
              if (controller.canSendTestError)
                ('Отправка', 'Также отправятся ожидающие отчёты'),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed:
                controller.canSendTestError
                    ? () async {
                      final result = await controller.sendTestError();
                      if (!context.mounted) return;
                      final message = switch (result) {
                        CrashReportResult.queued =>
                          'Тестовый отчёт поставлен в очередь отправки',
                        CrashReportResult.unsupported =>
                          'Crashlytics доступен только на Android',
                        CrashReportResult.unavailable =>
                          'Не удалось отправить тестовый отчёт',
                      };
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(message)));
                    }
                    : null,
            icon: const Icon(Icons.send_outlined),
            label: const Text('Отправить тестовую ошибку'),
          ),
        ],
      ),
    );
  }
}

String _value(String? value) => value ?? 'Недоступно';

String _batteryLevel(NativeBatteryInfo? battery) =>
    battery?.level == null ? 'Недоступно' : '${battery!.level}%';

String _chargingStatus(NativeBatteryInfo? battery) => switch (battery
    ?.isCharging) {
  true => 'Заряжается',
  false => 'Не заряжается',
  null => 'Недоступно',
};

String _powerSource(NativeBatteryInfo? battery) => switch (battery?.source) {
  'ac' => 'Сеть',
  'usb' => 'USB',
  'wireless' => 'Беспроводная зарядка',
  'dock' => 'Док станция',
  'battery' => 'Батарея',
  _ => 'Недоступно',
};

class _DiagnosticsCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<(String, String)> rows;

  const _DiagnosticsCard({
    required this.title,
    required this.icon,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(title, style: theme.textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 14),
          for (final (label, value) in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(label, style: theme.textTheme.bodyMedium),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      value,
                      textAlign: TextAlign.end,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String message;

  const _MessageCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
