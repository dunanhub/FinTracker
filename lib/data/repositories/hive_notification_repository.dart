import 'package:hive/hive.dart';

import '../../domain/entities/app_notification.dart';

class HiveNotificationRepository {
  Box<dynamic>? _box;

  Future<void> switchScope(String uid) async {
    final safe = uid.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    _box = await Hive.openBox<dynamic>('fintracker_notifications_$safe');
  }

  Future<List<AppNotification>> load() async {
    final raw = _box?.get('items');
    if (raw is! List) return [];
    final result = <AppNotification>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        result.add(
          AppNotification(
            id: item['id'] as String,
            kind: AppNotificationKind.values.byName(item['kind'] as String),
            title: item['title'] as String,
            body: item['body'] as String,
            entityId: item['entityId'] as String?,
            scheduledAt: DateTime.parse(item['scheduledAt'] as String),
            isRead: item['isRead'] == true,
          ),
        );
      } catch (_) {
        // Skip only the damaged notification.
      }
    }
    return result;
  }

  Future<void> save(List<AppNotification> items) async {
    final box = _box;
    if (box == null) return;
    await box.put('items', [
      for (final item in items)
        {
          'id': item.id,
          'kind': item.kind.name,
          'title': item.title,
          'body': item.body,
          'entityId': item.entityId,
          'scheduledAt': item.scheduledAt.toIso8601String(),
          'isRead': item.isRead,
        },
    ]);
  }
}
