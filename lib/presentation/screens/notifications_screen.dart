import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/router/app_routes.dart';
import '../../domain/entities/app_notification.dart';
import '../controllers/debt_controller.dart';
import '../controllers/goal_controller.dart';
import '../controllers/notification_center_controller.dart';
import '../controllers/push_notification_controller.dart';

class NotificationsScreen extends StatefulWidget {
  final String? openId;

  const NotificationsScreen({super.key, this.openId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.openId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openId(widget.openId!);
      });
    }
  }

  Future<void> _openId(String id) async {
    final center = context.read<NotificationCenterController?>();
    if (center == null) return;
    final item = center.byId(id);
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Уведомление больше не найдено')),
      );
      return;
    }
    await center.markRead(id);
    if (!mounted) return;
    if (item.kind == AppNotificationKind.debt && item.entityId != null) {
      if (context.read<DebtController>().debtById(item.entityId!) == null) {
        _missing();
      } else {
        context.push('/debts/${Uri.encodeComponent(item.entityId!)}');
      }
    } else if (item.kind == AppNotificationKind.goal && item.entityId != null) {
      if (context.read<GoalController>().goalById(item.entityId!) == null) {
        _missing();
      } else {
        context.push(AppRoutes.goals);
      }
    }
  }

  void _missing() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Запись уже удалена')));
  }

  @override
  Widget build(BuildContext context) {
    final center = context.watch<NotificationCenterController?>();
    final push = context.watch<PushNotificationController>();
    final theme = Theme.of(context);
    final items = center?.items ?? const <AppNotification>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          if (!push.isEnabled) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Уведомления на телефоне отключены'),
                    const SizedBox(height: 8),
                    const Text(
                      'Разрешите уведомления, чтобы получать напоминания о сроках.',
                    ),
                    TextButton(
                      onPressed: push.requestPermission,
                      child: const Text('Разрешить'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (center?.error != null) ...[
            Text(
              center!.error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            const SizedBox(height: 12),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 72),
              child: Column(
                children: [
                  Icon(
                    Icons.notifications_none_rounded,
                    size: 56,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Пока нет уведомлений',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Напоминания появятся здесь после срока отправки.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            )
          else
            for (final item in items) ...[
              Material(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  borderRadius: BorderRadius.circular(22),
                  onTap: () => _openId(item.id),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          item.kind == AppNotificationKind.debt
                              ? Icons.account_balance_wallet_outlined
                              : item.kind == AppNotificationKind.goal
                              ? Icons.flag_outlined
                              : Icons.notifications_outlined,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: theme.textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.body,
                                style: theme.textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _dateLabel(item.scheduledAt),
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} '
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}
