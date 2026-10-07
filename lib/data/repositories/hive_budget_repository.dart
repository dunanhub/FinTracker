import 'package:hive/hive.dart';

import '../../domain/entities/budget.dart';
import '../../domain/repositories/budget_repository.dart';

class HiveBudgetRepository implements BudgetRepository {
  static const String _legacyBoxName = 'fintracker_budgets';

  static const String _budgetsKey = 'budgets';

  Box<dynamic>? _box;

  String _scope = 'legacy';

  bool get isLegacyScope => _scope == 'legacy';

  bool get hasStoredData {
    return _box?.containsKey(_budgetsKey) ?? false;
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
      throw StateError('HiveBudgetRepository.init() must be called first.');
    }

    return box;
  }

  @override
  Future<List<Budget>> load() async {
    final raw = _storage.get(_budgetsKey);

    if (raw is! List) {
      return [];
    }

    final result = <Budget>[];

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
  Future<void> save(List<Budget> budgets) async {
    await _storage.put(_budgetsKey, budgets.map(_toMap).toList());
  }

  Map<String, dynamic> _toMap(Budget budget) {
    return {
      'id': budget.id,
      'categoryId': budget.categoryId,
      'monthlyLimit': budget.monthlyLimit,
      'enabled': budget.enabled,
      'createdAt': budget.createdAt.toIso8601String(),
    };
  }

  Budget _fromMap(Map<dynamic, dynamic> map) {
    return Budget(
      id: map['id'] as String,
      categoryId: map['categoryId'] as String,
      monthlyLimit: (map['monthlyLimit'] as num).toDouble(),
      enabled: map['enabled'] as bool? ?? true,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
