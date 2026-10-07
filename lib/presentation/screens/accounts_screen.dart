import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/account.dart';
import '../controllers/finance_controller.dart';
import 'add_account_screen.dart';
import 'edit_account_screen.dart';

class AccountsScreen extends StatelessWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final finance = context.watch<FinanceController>();

    final accounts = finance.accounts;

    return Scaffold(
      appBar: AppBar(title: const Text('Счета')),
      body: SafeArea(
        top: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
          children: [
            Text('Общий баланс', style: theme.textTheme.bodyMedium),

            const SizedBox(height: 5),

            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '${_formatAmount(finance.totalBalance)} ₸',
                style: theme.textTheme.headlineLarge,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '${accounts.length} '
              '${_accountsWord(accounts.length)}',
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 26),

            if (accounts.isEmpty)
              const _EmptyAccounts()
            else
              ...List.generate(accounts.length, (index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Duration(
                      milliseconds: 350 + index.clamp(0, 5) * 50,
                    ),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 14 * (1 - value)),
                          child: child,
                        ),
                      );
                    },
                    child: _AccountItem(
                      account: accounts[index],
                      onTap: () {
                        _openEdit(context, accounts[index]);
                      },
                    ),
                  ),
                );
              }),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openAdd(context);
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Добавить'),
      ),
    );
  }

  void _openAdd(BuildContext context) {
    Navigator.of(context).push(_pageRoute(const AddAccountScreen()));
  }

  void _openEdit(BuildContext context, Account account) {
    Navigator.of(context).push(_pageRoute(EditAccountScreen(account: account)));
  }

  PageRouteBuilder<void> _pageRoute(Widget page) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 330),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) {
        return page;
      },
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );

        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _AccountItem extends StatelessWidget {
  final Account account;
  final VoidCallback onTap;

  const _AccountItem({required this.account, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finColors = context.finColors;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: finColors.softAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _typeIcon(account.type),
                  color: theme.colorScheme.primary,
                  size: 23,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),

                    const SizedBox(height: 4),

                    Text(
                      _subtitle(account),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
                    ),

                    if (!account.includeInTotal) ...[
                      const SizedBox(height: 5),
                      Text(
                        'Не входит в общий баланс',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 10),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '${_formatAmount(account.balance)} ₸',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 5),

                  Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: theme.colorScheme.primary,
            size: 34,
          ),

          const SizedBox(height: 13),

          Text('Пока нет счетов', style: theme.textTheme.titleMedium),

          const SizedBox(height: 5),

          Text(
            'Добавь карту, наличные или депозит.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

String _subtitle(Account account) {
  final type = _typeName(account.type);

  final bank = account.bankName;

  if (bank == null || bank.trim().isEmpty) {
    return type;
  }

  return '$type · $bank';
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
      return 'Другой счёт';
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

String _accountsWord(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;

  if (mod10 == 1 && mod100 != 11) {
    return 'счёт';
  }

  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'счёта';
  }

  return 'счетов';
}

String _formatAmount(double value) {
  final rounded = value.round();
  final negative = rounded < 0;
  final digits = rounded.abs().toString();

  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;

    buffer.write(digits[i]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }

  return '${negative ? '−' : ''}'
      '${buffer.toString()}';
}
