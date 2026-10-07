import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/budget.dart';
import '../controllers/budget_controller.dart';
import '../controllers/finance_controller.dart';

class AddBudgetScreen extends StatefulWidget {
  final Budget? budget;

  const AddBudgetScreen({super.key, this.budget});

  bool get editing => budget != null;

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  late String _categoryId;

  late final TextEditingController _limitController;

  bool _enabled = true;
  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();

    final budget = widget.budget;

    _categoryId =
        budget?.categoryId ?? FinanceController.expenseCategories.keys.first;

    _limitController = TextEditingController(
      text: budget == null ? '' : _numberText(budget.monthlyLimit),
    );

    _enabled = budget?.enabled ?? true;
  }

  @override
  void dispose() {
    _limitController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final budgetController = context.watch<BudgetController>();

    final currentBudget = widget.budget;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing ? 'Редактировать бюджет' : 'Новый бюджет'),
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
        children: [
          Text('Категория расходов', style: theme.textTheme.titleMedium),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: DropdownButtonFormField<String>(
              initialValue: _categoryId,
              isExpanded: true,
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                labelText: 'Категория',
              ),
              items:
                  FinanceController.expenseCategories.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Row(
                        children: [
                          Icon(
                            _categoryIcon(entry.key),
                            size: 19,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Text(entry.value),
                        ],
                      ),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _categoryId = value;
                });
              },
            ),
          ),

          if (budgetController.hasBudgetForCategory(
            _categoryId,
            exceptBudgetId: currentBudget?.id,
          )) ...[
            const SizedBox(height: 8),
            Text(
              'Для этой категории бюджет уже создан.',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 11),
            ),
          ],

          const SizedBox(height: 24),

          Text('Месячный лимит', style: theme.textTheme.titleMedium),

          const SizedBox(height: 12),

          TextField(
            controller: _limitController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Лимит',
              hintText: 'Например, 100000',
              suffixText: '₸',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ),

          const SizedBox(height: 18),

          Material(
            color: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: SwitchListTile(
              value: _enabled,
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                });
              },
              secondary: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.notifications_active_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: const Text('Бюджет активен'),
              subtitle: const Text('Будет учитываться в общей статистике'),
            ),
          ),

          if (widget.editing) ...[
            const SizedBox(height: 34),

            Text('Опасная зона', style: theme.textTheme.titleMedium),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _deleting || _saving ? null : _delete,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
                side: BorderSide(
                  color: theme.colorScheme.error.withValues(alpha: 0.35),
                ),
                minimumSize: const Size.fromHeight(54),
              ),
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Удалить бюджет'),
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
                  : 'Создать бюджет',
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final normalized = _limitController.text
        .replaceAll(',', '.')
        .replaceAll(' ', '');

    final limit = double.tryParse(normalized);

    if (limit == null || limit <= 0) {
      _showMessage('Введите корректный лимит');

      return;
    }

    final controller = context.read<BudgetController>();

    if (controller.hasBudgetForCategory(
      _categoryId,
      exceptBudgetId: widget.budget?.id,
    )) {
      _showMessage('Для этой категории бюджет уже существует');

      return;
    }

    setState(() {
      _saving = true;
    });

    final success =
        widget.editing
            ? await controller.updateBudget(
              id: widget.budget!.id,
              categoryId: _categoryId,
              monthlyLimit: limit,
              enabled: _enabled,
            )
            : await controller.addBudget(
              categoryId: _categoryId,
              monthlyLimit: limit,
            );

    if (!mounted) {
      return;
    }

    if (!success) {
      setState(() {
        _saving = false;
      });

      _showMessage('Не удалось сохранить бюджет');

      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
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
                Text('Удалить бюджет?', style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'История операций останется без изменений.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
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

    await context.read<BudgetController>().deleteBudget(widget.budget!.id);

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

String _numberText(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }

  return value.toString();
}

IconData _categoryIcon(String id) {
  switch (id) {
    case 'food':
      return Icons.restaurant_rounded;

    case 'housing':
      return Icons.home_outlined;

    case 'transport':
      return Icons.directions_car_outlined;

    case 'subscriptions':
      return Icons.subscriptions_outlined;

    case 'shopping':
      return Icons.shopping_bag_outlined;

    case 'health':
      return Icons.favorite_border_rounded;

    case 'entertainment':
      return Icons.movie_outlined;

    default:
      return Icons.category_outlined;
  }
}
