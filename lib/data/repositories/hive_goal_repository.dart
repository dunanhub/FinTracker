import 'package:hive/hive.dart';

import '../../domain/entities/savings_goal.dart';
import '../../domain/repositories/goal_repository.dart';

class HiveGoalRepository implements GoalRepository {
  static const String _legacyBoxName = 'fintracker_goals';

  static const String _goalsKey = 'goals';

  Box<dynamic>? _box;

  String _scope = 'legacy';

  bool get isLegacyScope => _scope == 'legacy';

  bool get hasStoredData {
    return _box?.containsKey(_goalsKey) ?? false;
  }

  Future<void> init({String scope = 'legacy'}) async {
    _scope = scope;

    _box = await Hive.openBox<dynamic>(_boxName(scope));
  }

  Future<void> switchScope(String scope) async {
    if (_scope == scope && _box != null) {
      return;
    }

    _scope = scope;

    _box = await Hive.openBox<dynamic>(_boxName(scope));
  }

  String _boxName(String scope) {
    if (scope == 'legacy') {
      return _legacyBoxName;
    }

    return '${_legacyBoxName}_${_safeScope(scope)}';
  }

  String _safeScope(String value) {
    return value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  Box<dynamic> get _storage {
    final box = _box;

    if (box == null) {
      throw StateError('HiveGoalRepository.init() must be called first.');
    }

    return box;
  }

  @override
  Future<List<SavingsGoal>> load() async {
    final raw = _storage.get(_goalsKey);

    if (raw is! List) {
      return [];
    }

    final result = <SavingsGoal>[];

    for (final item in raw) {
      if (item is! Map) {
        continue;
      }

      try {
        result.add(_fromMap(item));
      } catch (_) {
        // Повреждённую запись пропускаем.
      }
    }

    return result;
  }

  @override
  Future<void> save(List<SavingsGoal> goals) async {
    await _storage.put(_goalsKey, goals.map(_toMap).toList());
  }

  Map<String, dynamic> _toMap(SavingsGoal goal) {
    return {
      'id': goal.id,
      'name': goal.name,
      'targetAmount': goal.targetAmount,
      'currentAmount': goal.currentAmount,
      'deadline': goal.deadline.toIso8601String(),
      'createdAt': goal.createdAt.toIso8601String(),
      'linkedAccountId': goal.linkedAccountId,
    };
  }

  SavingsGoal _fromMap(Map<dynamic, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as String,
      name: map['name'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      currentAmount: (map['currentAmount'] as num).toDouble(),
      deadline: DateTime.parse(map['deadline'] as String),
      createdAt: DateTime.parse(map['createdAt'] as String),
      linkedAccountId: map['linkedAccountId'] as String?,
    );
  }
}
