import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/account.dart';
import '../controllers/finance_controller.dart';

class EditAccountScreen extends StatefulWidget {
  final Account account;

  const EditAccountScreen({super.key, required this.account});

  @override
  State<EditAccountScreen> createState() => _EditAccountScreenState();
}

class _EditAccountScreenState extends State<EditAccountScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _bankController;
  late final TextEditingController _balanceController;

  late AccountType _type;
  late bool _includeInTotal;

  bool _saving = false;
  bool _deleting = false;

  @override
  void initState() {
    super.initState();

    final account = widget.account;

    _nameController = TextEditingController(text: account.name);

    _bankController = TextEditingController(text: account.bankName ?? '');

    _balanceController = TextEditingController(
      text: _balanceText(account.balance),
    );

    _type = account.type;
    _includeInTotal = account.includeInTotal;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bankController.dispose();
    _balanceController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать счёт')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
        children: [
          Text('Тип счёта', style: theme.textTheme.titleMedium),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                AccountType.values.map((type) {
                  final selected = type == _type;

                  return ChoiceChip(
                    selected: selected,
                    label: Text(_typeName(type)),
                    avatar: Icon(
                      _typeIcon(type),
                      size: 18,
                      color:
                          selected
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.primary,
                    ),
                    onSelected: (_) {
                      setState(() {
                        _type = type;
                      });
                    },
                  );
                }).toList(),
          ),

          const SizedBox(height: 26),

          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Название',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ),

          const SizedBox(height: 12),

          if (_type != AccountType.cash) ...[
            TextField(
              controller: _bankController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Банк / организация',
                hintText: 'Необязательно',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[-0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Текущий баланс',
              suffixText: '₸',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),

          const SizedBox(height: 7),

          Text(
            'Изменение этой суммы корректирует текущий баланс '
            'без создания новой операции.',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
          ),

          const SizedBox(height: 18),

          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: SwitchListTile(
              value: _includeInTotal,
              onChanged: (value) {
                setState(() {
                  _includeInTotal = value;
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
                  Icons.calculate_outlined,
                  color: theme.colorScheme.primary,
                ),
              ),
              title: const Text('Учитывать в общем балансе'),
              subtitle: const Text('Влияет на общий капитал на главной'),
            ),
          ),

          const SizedBox(height: 34),

          Text('Опасная зона', style: theme.textTheme.titleMedium),

          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _deleting ? null : _requestDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.35),
              ),
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            icon:
                _deleting
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.delete_outline_rounded),
            label: const Text('Удалить счёт'),
          ),
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
          child: FilledButton(
            onPressed: _saving || _deleting ? null : _save,
            child:
                _saving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Сохранить изменения'),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showMessage('Введите название счёта');

      return;
    }

    final normalized = _balanceController.text
        .replaceAll(',', '.')
        .replaceAll(' ', '');

    final balance = double.tryParse(normalized);

    if (balance == null) {
      _showMessage('Введите корректный баланс');

      return;
    }

    setState(() {
      _saving = true;
    });

    await context.read<FinanceController>().updateAccount(
      id: widget.account.id,
      name: name,
      type: _type,
      balance: balance,
      bankName: _type == AccountType.cash ? null : _bankController.text,
      includeInTotal: _includeInTotal,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  Future<void> _requestDelete() async {
    final finance = context.read<FinanceController>();

    if (finance.accountHasTransactions(widget.account.id)) {
      await showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Нельзя удалить счёт'),
            content: const Text(
              'У этого счёта уже есть операции. '
              'Сначала нужно удалить или перенести связанные операции.',
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Понятно'),
              ),
            ],
          );
        },
      );

      return;
    }

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
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: theme.colorScheme.error,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'Удалить «${widget.account.name}»?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),

                const SizedBox(height: 7),

                Text(
                  'Это действие нельзя отменить.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),

                const SizedBox(height: 22),

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

                const SizedBox(height: 8),

                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Отмена'),
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

    final result = await finance.deleteAccount(widget.account.id);

    if (!mounted) {
      return;
    }

    if (result == AccountDeleteResult.success) {
      Navigator.of(context).pop();

      return;
    }

    setState(() {
      _deleting = false;
    });

    if (result == AccountDeleteResult.hasTransactions) {
      _showMessage('Счёт связан с операциями');
    } else {
      _showMessage('Счёт не найден');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
}

String _balanceText(double value) {
  if (value == value.roundToDouble()) {
    return value.round().toString();
  }

  return value.toString();
}

String _typeName(AccountType type) {
  switch (type) {
    case AccountType.card:
      return 'Карта';
    case AccountType.cash:
      return 'Наличные';
    case AccountType.deposit:
      return 'Депозит';
    case AccountType.savings:
      return 'Накопления';
    case AccountType.other:
      return 'Другое';
  }
}

IconData _typeIcon(AccountType type) {
  switch (type) {
    case AccountType.card:
      return Icons.credit_card_rounded;
    case AccountType.cash:
      return Icons.payments_outlined;
    case AccountType.deposit:
      return Icons.account_balance_outlined;
    case AccountType.savings:
      return Icons.savings_outlined;
    case AccountType.other:
      return Icons.wallet_outlined;
  }
}
