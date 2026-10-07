import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/account.dart';
import '../controllers/finance_controller.dart';

class AddAccountScreen extends StatefulWidget {
  const AddAccountScreen({super.key});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final TextEditingController _nameController = TextEditingController();

  final TextEditingController _bankController = TextEditingController();

  final TextEditingController _balanceController = TextEditingController();

  AccountType _type = AccountType.card;

  bool _includeInTotal = true;

  bool _saving = false;

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
      appBar: AppBar(title: const Text('Новый счёт')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 130),
        children: [
          Text('Тип счёта', style: theme.textTheme.titleMedium),

          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                AccountType.values.map((type) {
                  final selected = _type == type;

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
              hintText: 'Например, Kaspi Gold',
              prefixIcon: Icon(Icons.account_balance_wallet_outlined),
            ),
          ),

          const SizedBox(height: 12),

          if (_type != AccountType.cash)
            TextField(
              controller: _bankController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Банк / организация',
                hintText: 'Необязательно',
                prefixIcon: Icon(Icons.account_balance_outlined),
              ),
            ),

          if (_type != AccountType.cash) const SizedBox(height: 12),

          TextField(
            controller: _balanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Текущий баланс',
              hintText: '0',
              suffixText: '₸',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
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
              subtitle: const Text('Можно отключить для отдельного счёта'),
            ),
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
            onPressed: _saving ? null : _save,
            child:
                _saving
                    ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Text('Добавить счёт'),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      _showError('Введите название счёта');

      return;
    }

    final rawBalance = _balanceController.text
        .trim()
        .replaceAll(',', '.')
        .replaceAll(' ', '');

    final balance = rawBalance.isEmpty ? 0.0 : double.tryParse(rawBalance);

    if (balance == null) {
      _showError('Введите корректный баланс');

      return;
    }

    setState(() {
      _saving = true;
    });

    await context.read<FinanceController>().addAccount(
      name: name,
      type: _type,
      balance: balance,
      bankName: _bankController.text,
      includeInTotal: _includeInTotal,
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context).pop();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }
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
