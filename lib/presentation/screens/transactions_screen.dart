import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/finance_transaction.dart';
import '../controllers/finance_controller.dart';
import 'transaction_details_screen.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  FinanceTransactionType? _filter;

  final TextEditingController _searchController = TextEditingController();

  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final finance = context.watch<FinanceController>();

    final width = MediaQuery.sizeOf(context).width;

    final compact = width < 360;

    final filteredTransactions =
        finance.transactions.where((transaction) {
          if (_filter != null && transaction.type != _filter) {
            return false;
          }

          if (_query.trim().isEmpty) {
            return true;
          }

          final query = _query.toLowerCase();

          final searchable =
              [
                transaction.title,
                transaction.person ?? '',
                finance.accountName(transaction.accountId),
                finance.categoryName(transaction.categoryId),
              ].join(' ').toLowerCase();

          return searchable.contains(query);
        }).toList();

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 20,
              18,
              compact ? 16 : 20,
              0,
            ),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Операции', style: theme.textTheme.headlineMedium),

                  const SizedBox(height: 5),

                  Text(
                    'Все движения твоих денег',
                    style: theme.textTheme.bodyMedium,
                  ),

                  const SizedBox(height: 22),

                  TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (value) {
                      setState(() {
                        _query = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Поиск по операциям',
                      prefixIcon: const Icon(Icons.search_rounded),
                      suffixIcon:
                          _query.isEmpty
                              ? null
                              : IconButton(
                                onPressed: () {
                                  _searchController.clear();

                                  setState(() {
                                    _query = '';
                                  });
                                },
                                icon: const Icon(Icons.close_rounded),
                              ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    height: 42,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _FilterChip(
                          title: 'Все',
                          selected: _filter == null,
                          onTap: () {
                            setState(() {
                              _filter = null;
                            });
                          },
                        ),

                        const SizedBox(width: 8),

                        _FilterChip(
                          title: 'Расходы',
                          icon: Icons.north_east_rounded,
                          selected: _filter == FinanceTransactionType.expense,
                          onTap: () {
                            setState(() {
                              _filter = FinanceTransactionType.expense;
                            });
                          },
                        ),

                        const SizedBox(width: 8),

                        _FilterChip(
                          title: 'Доходы',
                          icon: Icons.south_west_rounded,
                          selected: _filter == FinanceTransactionType.income,
                          onTap: () {
                            setState(() {
                              _filter = FinanceTransactionType.income;
                            });
                          },
                        ),

                        const SizedBox(width: 8),

                        _FilterChip(
                          title: 'Переводы',
                          icon: Icons.swap_horiz_rounded,
                          selected: _filter == FinanceTransactionType.transfer,
                          onTap: () {
                            setState(() {
                              _filter = FinanceTransactionType.transfer;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          if (filteredTransactions.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyState(
                searching: _query.trim().isNotEmpty || _filter != null,
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 20,
                0,
                compact ? 16 : 20,
                150,
              ),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final transaction = filteredTransactions[index];

                  final showDateHeader =
                      index == 0 ||
                      !_sameDay(
                        transaction.date,
                        filteredTransactions[index - 1].date,
                      );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDateHeader) ...[
                        if (index != 0) const SizedBox(height: 18),
                        Padding(
                          padding: const EdgeInsets.only(left: 3, bottom: 10),
                          child: Text(
                            _dateTitle(transaction.date),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],

                      TweenAnimationBuilder<double>(
                        key: ValueKey(transaction.id),
                        tween: Tween(begin: 0, end: 1),
                        duration: Duration(
                          milliseconds: 280 + index.clamp(0, 5).toInt() * 45,
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return Opacity(
                            opacity: value,
                            child: Transform.translate(
                              offset: Offset(0, 12 * (1 - value)),
                              child: child,
                            ),
                          );
                        },
                        child: _TransactionCard(
                          transaction: transaction,
                          onTap: () {
                            if (transaction.categoryId ==
                                FinanceController.debtPaymentCategoryId) {
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Выплаты долга изменяются в разделе «Долги».',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );

                              return;
                            }

                            _openTransaction(context, transaction);
                          },
                        ),
                      ),

                      const SizedBox(height: 10),
                    ],
                  );
                }, childCount: filteredTransactions.length),
              ),
            ),
        ],
      ),
    );
  }

  void _openTransaction(BuildContext context, FinanceTransaction transaction) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return TransactionDetailsScreen(transactionId: transaction.id);
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
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String title;
  final IconData? icon;

  final bool selected;

  final VoidCallback onTap;

  const _FilterChip({
    required this.title,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color:
                selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
                  selected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color:
                      selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                title,
                style: TextStyle(
                  color:
                      selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final FinanceTransaction transaction;
  final VoidCallback onTap;

  const _TransactionCard({required this.transaction, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = context.finColors;

    final finance = context.read<FinanceController>();

    final appearance = _appearance(transaction.type, colors);

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: appearance.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(appearance.icon, color: appearance.color, size: 21),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            transaction.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 14,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _amountText(transaction),
                            style: TextStyle(
                              color: appearance.color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _subtitle(transaction, finance),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 11,
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        Text(
                          _timeText(transaction.date),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 10,
                          ),
                        ),

                        const SizedBox(width: 3),

                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),

                    if (transaction.receiptPath != null ||
                        transaction.receiptStoragePath != null ||
                        (transaction.latitude != null &&
                            transaction.longitude != null)) ...[
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (transaction.receiptPath != null ||
                              transaction.receiptStoragePath != null)
                            const _MetaBadge(
                              icon: Icons.receipt_long_outlined,
                              label: 'Чек',
                            ),
                          if (transaction.latitude != null &&
                              transaction.longitude != null)
                            const _MetaBadge(
                              icon: Icons.location_on_outlined,
                              label: 'Место',
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MetaBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionAppearance {
  final IconData icon;
  final Color color;

  const _TransactionAppearance({required this.icon, required this.color});
}

_TransactionAppearance _appearance(
  FinanceTransactionType type,
  FinThemeColors colors,
) {
  switch (type) {
    case FinanceTransactionType.expense:
      return _TransactionAppearance(
        icon: Icons.north_east_rounded,
        color: colors.expense,
      );

    case FinanceTransactionType.income:
      return _TransactionAppearance(
        icon: Icons.south_west_rounded,
        color: colors.income,
      );

    case FinanceTransactionType.transfer:
      return _TransactionAppearance(
        icon: Icons.swap_horiz_rounded,
        color: colors.transfer,
      );
  }
}

String _subtitle(FinanceTransaction transaction, FinanceController finance) {
  if (transaction.type == FinanceTransactionType.transfer) {
    return '${finance.accountName(transaction.accountId)}'
        ' → '
        '${finance.accountName(transaction.destinationAccountId ?? '')}';
  }

  return '${finance.categoryName(transaction.categoryId)}'
      ' · '
      '${finance.accountName(transaction.accountId)}';
}

String _amountText(FinanceTransaction transaction) {
  final amount = _formatAmount(transaction.amount);

  switch (transaction.type) {
    case FinanceTransactionType.expense:
      return '-$amount ₸';

    case FinanceTransactionType.income:
      return '+$amount ₸';

    case FinanceTransactionType.transfer:
      return '$amount ₸';
  }
}

class _EmptyState extends StatelessWidget {
  final bool searching;

  const _EmptyState({required this.searching});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 20, 30, 140),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching
                  ? Icons.search_off_rounded
                  : Icons.receipt_long_outlined,
              color: theme.colorScheme.primary,
              size: 34,
            ),
            const SizedBox(height: 14),
            Text(
              searching ? 'Ничего не найдено' : 'Пока нет операций',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 5),
            Text(
              searching
                  ? 'Измени поиск или фильтр'
                  : 'Нажми +, чтобы добавить операцию',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _dateTitle(DateTime date) {
  final now = DateTime.now();

  final today = DateTime(now.year, now.month, now.day);

  final value = DateTime(date.year, date.month, date.day);

  final difference = today.difference(value).inDays;

  if (difference == 0) {
    return 'Сегодня';
  }

  if (difference == 1) {
    return 'Вчера';
  }

  const months = [
    'января',
    'февраля',
    'марта',
    'апреля',
    'мая',
    'июня',
    'июля',
    'августа',
    'сентября',
    'октября',
    'ноября',
    'декабря',
  ];

  return '${date.day} '
      '${months[date.month - 1]}';
}

String _timeText(DateTime date) {
  final hour = date.hour.toString().padLeft(2, '0');

  final minute = date.minute.toString().padLeft(2, '0');

  return '$hour:$minute';
}

String _formatAmount(double value) {
  final integer = value.round().toString();

  final buffer = StringBuffer();

  for (var i = 0; i < integer.length; i++) {
    final remaining = integer.length - i;

    buffer.write(integer[i]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }

  return buffer.toString();
}
