enum AppNotificationKind { debt, goal, push }

class AppNotification {
  final String id;
  final AppNotificationKind kind;
  final String title;
  final String body;
  final String? entityId;
  final DateTime scheduledAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.scheduledAt,
    this.entityId,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    entityId: entityId,
    scheduledAt: scheduledAt,
    isRead: isRead ?? this.isRead,
  );
}
