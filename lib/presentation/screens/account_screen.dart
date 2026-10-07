import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/auth_controller.dart';
import '../controllers/sync_controller.dart';
import '../controllers/push_notification_controller.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final auth = context.watch<AuthController>();

    final sync = context.watch<SyncController>();

    final push = context.watch<PushNotificationController>();

    final user = auth.user;

    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Пользователь не найден')),
      );
    }

    final name =
        user.displayName?.trim().isNotEmpty == true
            ? user.displayName!
            : 'Пользователь';

    return Scaffold(
      appBar: AppBar(title: const Text('Аккаунт')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: theme.colorScheme.primary.withValues(
                    alpha: 0.10,
                  ),
                  backgroundImage:
                      user.photoUrl == null
                          ? null
                          : NetworkImage(user.photoUrl!),
                  child:
                      user.photoUrl == null
                          ? Icon(
                            Icons.person_rounded,
                            size: 36,
                            color: theme.colorScheme.primary,
                          )
                          : null,
                ),
                const SizedBox(height: 14),
                Text(name, style: theme.textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(
                  user.email ?? 'Email отсутствует',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Text('Синхронизация', style: theme.textTheme.titleLarge),

          const SizedBox(height: 12),

          _SyncCard(sync: sync),

          const SizedBox(height: 24),

          const SizedBox(height: 24),

          Text('Уведомления', style: theme.textTheme.titleLarge),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        push.isEnabled
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_off_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Push-уведомления',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            push.permissionLabel,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text('FCM token', style: theme.textTheme.labelLarge),

                const SizedBox(height: 5),

                SelectableText(
                  push.tokenPreview,
                  style: theme.textTheme.bodySmall,
                ),

                if (push.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    push.errorMessage!,
                    style: TextStyle(color: theme.colorScheme.error),
                  ),
                ],

                if (push.lastMessage != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  Text(
                    'Последнее сообщение',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 5),
                  Text(push.lastMessage!.title ?? 'Без заголовка'),
                  if (push.lastMessage!.body != null)
                    Text(
                      push.lastMessage!.body!,
                      style: theme.textTheme.bodyMedium,
                    ),
                ],

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: push.isBusy ? null : push.requestPermission,
                    icon: const Icon(Icons.notifications_outlined),
                    label: Text(
                      push.isEnabled
                          ? 'Проверить разрешение'
                          : 'Разрешить уведомления',
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed:
                        push.isBusy || !push.isEnabled
                            ? null
                            : push.refreshToken,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Обновить FCM token'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed:
                auth.isLoading
                    ? null
                    : () async {
                      await sync.syncNow();

                      if (!context.mounted) {
                        return;
                      }

                      await auth.signOut();
                    },
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Выйти из аккаунта'),
          ),
        ],
      ),
    );
  }
}

class _SyncCard extends StatelessWidget {
  final SyncController sync;

  const _SyncCard({required this.sync});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final status = _statusInfo(sync.status, theme);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child:
                    sync.isSyncing
                        ? Padding(
                          padding: const EdgeInsets.all(13),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: status.color,
                          ),
                        )
                        : Icon(status.icon, color: status.color),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(status.title, style: theme.textTheme.titleMedium),

                    const SizedBox(height: 3),

                    Text(
                      sync.message ?? status.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (sync.lastSyncAt != null) ...[
            const SizedBox(height: 13),

            Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  'Последняя синхронизация: '
                  '${_dateTime(sync.lastSyncAt!)}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: sync.isSyncing ? null : sync.syncNow,
              icon: const Icon(Icons.cloud_sync_outlined),
              label: const Text('Синхронизировать'),
            ),
          ),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              onPressed: sync.isSyncing ? null : sync.refreshFromCloud,
              icon: const Icon(Icons.cloud_download_outlined),
              label: const Text('Получить данные из облака'),
            ),
          ),
        ],
      ),
    );
  }

  _SyncStatusInfo _statusInfo(SyncStatus status, ThemeData theme) {
    switch (status) {
      case SyncStatus.idle:
        return _SyncStatusInfo(
          title: 'Ожидание',
          subtitle: 'Синхронизация не запущена',
          icon: Icons.cloud_outlined,
          color: theme.colorScheme.onSurfaceVariant,
        );

      case SyncStatus.syncing:
        return _SyncStatusInfo(
          title: 'Синхронизация',
          subtitle: 'Обновляем данные',
          icon: Icons.cloud_sync_outlined,
          color: theme.colorScheme.primary,
        );

      case SyncStatus.synced:
        return _SyncStatusInfo(
          title: 'Синхронизировано',
          subtitle: 'Данные сохранены в облаке',
          icon: Icons.cloud_done_outlined,
          color: Colors.green,
        );

      case SyncStatus.offline:
        return _SyncStatusInfo(
          title: 'Офлайн',
          subtitle: 'Работаем с локальными данными',
          icon: Icons.cloud_off_outlined,
          color: Colors.orange,
        );

      case SyncStatus.error:
        return _SyncStatusInfo(
          title: 'Ошибка',
          subtitle: 'Не удалось выполнить синхронизацию',
          icon: Icons.error_outline_rounded,
          color: theme.colorScheme.error,
        );
    }
  }
}

class _SyncStatusInfo {
  final String title;
  final String subtitle;

  final IconData icon;

  final Color color;

  const _SyncStatusInfo({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

String _dateTime(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:'
      '${date.minute.toString().padLeft(2, '0')}';
}
