import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/account.dart';
import '../../domain/entities/savings_goal.dart';
import '../controllers/finance_controller.dart';
import '../controllers/goal_controller.dart';

class AddGoalScreen extends StatefulWidget {
  final SavingsGoal? goal;

  const AddGoalScreen({super.key, this.goal});

  bool get editing => goal != null;

  @override
  State<AddGoalScreen> createState() => _AddGoalScreenState();
}

class _AddGoalScreenState extends State<AddGoalScreen> {
  late final TextEditingController _nameController;

  late final TextEditingController _targetController;

  late final TextEditingController _currentController;

  late DateTime _deadline;

  String? _linkedAccountId;

  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();

    final goal = widget.goal;

    _nameController = TextEditingController(text: goal?.name ?? '');

    _targetController = TextEditingController(
      text: goal == null ? '' : _numberText(goal.targetAmount),
    );

    _currentController = TextEditingController(
      text: goal == null ? '' : _numberText(goal.currentAmount),
    );

    _deadline = goal?.deadline ?? DateTime.now().add(const Duration(days: 365));

    _linkedAccountId = goal?.linkedAccountId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _currentController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final finance = context.watch<FinanceController>();

    final linkableAccounts =
        finance.accounts
            .where(
              (account) =>
                  account.type == AccountType.deposit ||
                  account.type == AccountType.savings,
            )
            .toList();

    if (_linkedAccountId != null &&
        !linkableAccounts.any((account) => account.id == _linkedAccountId)) {
      _linkedAccountId = null;
    }

    final target = _parseAmount(_targetController.text) ?? 0;

    final current = _parseAmount(_currentController.text) ?? 0;

    final previewProgress =
        target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Редактировать цель' : 'Новая цель'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 150),
        children: [
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Название цели',
              hintText: 'Например, Квартира',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) {
              setState(() {});
            },
            decoration: const InputDecoration(
              labelText: 'Нужно накопить',
              hintText: '5000000',
              suffixText: '₸',
              prefixIcon: Icon(Icons.track_changes_rounded),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _currentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            onChanged: (_) {
              setState(() {});
            },
            decoration: const InputDecoration(
              labelText: 'Уже накоплено',
              hintText: '0',
              suffixText: '₸',
              prefixIcon: Icon(Icons.savings_outlined),
            ),
          ),

          const SizedBox(height: 24),

          Text('Связанный счёт', style: theme.textTheme.titleMedium),

          const SizedBox(height: 5),

          Text(
            'Если привязать депозит или накопительный счёт, '
            'пополнение цели будет переводить деньги на него.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 10,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: DropdownButtonFormField<String?>(
              initialValue: _linkedAccountId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Счёт',
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Без привязки'),
                ),
                ...linkableAccounts.map((account) {
                  return DropdownMenuItem<String?>(
                    value: account.id,
                    child: Row(
                      children: [
                        Icon(
                          account.type == AccountType.deposit
                              ? Icons.account_balance_outlined
                              : Icons.savings_outlined,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            account.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _linkedAccountId = value;
                });
              },
            ),
          ),

          if (linkableAccounts.isEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Для привязки сначала создай счёт типа '
              '«Депозит» или «Накопления».',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],

          const SizedBox(height: 24),

          Text('Дедлайн', style: theme.textTheme.titleMedium),

          const SizedBox(height: 10),

          Material(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: _pickDeadline,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.calendar_today_outlined,
                        size: 19,
                        color: theme.colorScheme.primary,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Text(
                        _dateText(_deadline),
                        style: theme.textTheme.titleMedium,
                      ),
                    ),

                    Icon(
                      Icons.chevron_right_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(18),
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
                    Expanded(
                      child: Text(
                        'Прогресс',
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    Text(
                      '${(previewProgress * 100).round()}%',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: previewProgress,
                    minHeight: 8,
                    backgroundColor: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.35),
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  target <= 0
                      ? 'Укажи сумму цели'
                      : current > target
                      ? 'Накопленная сумма больше цели'
                      : 'Осталось накопить '
                          '${_formatAmount(target - current)} ₸',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          if (widget.editing) ...[
            const SizedBox(height: 34),

            Text('Опасная зона', style: theme.textTheme.titleMedium),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _saving || _deleting ? null : _requestDelete,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.35),
                ),
                minimumSize: const Size.fromHeight(54),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Удалить цель'),
            ),
          ],
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(color: theme.colorScheme.outlineVariant),
          ),
        ),
        child: SafeArea(
          top: false,
          child: FilledButton.icon(
            onPressed: _saving || _deleting ? null : _save,
            icon:
                _saving
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.check_rounded),
            label: Text(
              _saving
                  ? 'Сохраняем...'
                  : widget.editing
                  ? 'Сохранить изменения'
                  : 'Создать цель',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _deadline = selected;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    final target = _parseAmount(_targetController.text);

    final current = _parseAmount(_currentController.text) ?? 0;

    if (name.isEmpty) {
      _showMessage('Введите название цели');
      return;
    }

    if (target == null || target <= 0) {
      _showMessage('Введите сумму цели');
      return;
    }

    if (current < 0) {
      _showMessage('Накопленная сумма не может быть отрицательной');
      return;
    }

    if (current > target) {
      _showMessage('Накопленная сумма не может быть больше цели');
      return;
    }

    setState(() {
      _saving = true;
    });

    final controller = context.read<GoalController>();

    final success =
        widget.editing
            ? await controller.updateGoal(
              id: widget.goal!.id,
              name: name,
              targetAmount: target,
              currentAmount: current,
              deadline: _deadline,
              linkedAccountId: _linkedAccountId,
            )
            : await controller.addGoal(
              name: name,
              targetAmount: target,
              currentAmount: current,
              deadline: _deadline,
              linkedAccountId: _linkedAccountId,
            );

    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _saving = false;
      });

      _showMessage('Не удалось сохранить цель');

      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _requestDelete() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);

        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.delete_outline_rounded,
                  size: 36,
                  color: theme.colorScheme.error,
                ),
                const SizedBox(height: 14),
                Text('Удалить цель?', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                const Text(
                  'Эту цель нельзя будет восстановить.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Удалить'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _deleting = true;
    });

    await context.read<GoalController>().deleteGoal(widget.goal!.id);

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

double? _parseAmount(String value) {
  final normalized = value.replaceAll(',', '.').replaceAll(' ', '');

  return double.tryParse(normalized);
}

String _numberText(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }

  return value.toString();
}

String _dateText(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _formatAmount(double value) {
  final rounded = value.round();

  final digits = rounded.abs().toString();

  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;

    buffer.write(digits[i]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }

  return buffer.toString();
}
