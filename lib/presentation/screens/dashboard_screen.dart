import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/router/app_routes.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/finance_transaction.dart';
import '../controllers/finance_controller.dart';
import '../controllers/notification_center_controller.dart';
import '../widgets/smooth_line_chart.dart';
import '../widgets/budget_summary_card.dart';
import 'accounts_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;

    final finance = context.watch<FinanceController>();

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          compact ? 16 : 20,
          16,
          compact ? 16 : 20,
          145,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Reveal(
              animation: _animationController,
              start: 0,
              end: 0.35,
              child: const _Header(),
            ),

            SizedBox(height: compact ? 18 : 22),

            _Reveal(
              animation: _animationController,
              start: 0.08,
              end: 0.48,
              child: _BalanceCard(
                totalBalance: finance.totalBalance,
                income: finance.monthlyIncome,
                expense: finance.monthlyExpense,
                savings: finance.monthlySavings,
              ),
            ),

            SizedBox(height: compact ? 24 : 28),

            _Reveal(
              animation: _animationController,
              start: 0.18,
              end: 0.55,
              child: _SectionHeader(
                title: 'Мои счета',
                action: 'Все счета',
                onTap: () {
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: const Duration(milliseconds: 320),
                      reverseTransitionDuration: const Duration(
                        milliseconds: 240,
                      ),
                      pageBuilder: (context, animation, secondaryAnimation) {
                        return const AccountsScreen();
                      },
                      transitionsBuilder: (
                        context,
                        animation,
                        secondaryAnimation,
                        child,
                      ) {
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
                },
              ),
            ),

            const SizedBox(height: 12),

            _Reveal(
              animation: _animationController,
              start: 0.24,
              end: 0.62,
              child: _AccountsList(accounts: finance.accounts),
            ),

            SizedBox(height: compact ? 24 : 28),

            _Reveal(
              animation: _animationController,
              start: 0.28,
              end: 0.68,
              child: const BudgetSummaryCard(),
            ),

            SizedBox(height: compact ? 24 : 28),

            _Reveal(
              animation: _animationController,
              start: 0.32,
              end: 0.72,
              child: _SpendingCard(
                expense: finance.monthlyExpense,
                series: finance.expenseChartSeries(),
              ),
            ),

            SizedBox(height: compact ? 24 : 28),

            _Reveal(
              animation: _animationController,
              start: 0.42,
              end: 0.82,
              child: const _SectionHeader(title: 'Последние операции'),
            ),

            const SizedBox(height: 12),

            _Reveal(
              animation: _animationController,
              start: 0.52,
              end: 1,
              child: _RecentTransactions(
                transactions: finance.recentTransactions,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final compact = MediaQuery.sizeOf(context).width < 360;

    final unreadCount =
        context.watch<NotificationCenterController?>()?.unreadCount ?? 0;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ОБЗОР',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),

              const SizedBox(height: 3),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Мои финансы',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: compact ? 23 : 25,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 16),

        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: compact ? 44 : 48,
              height: compact ? 44 : 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                tooltip: 'Уведомления',
                onPressed: () => context.push(AppRoutes.notifications),
                icon: Icon(Icons.notifications_none_rounded, size: 23),
              ),
            ),
            if (unreadCount > 0)
              Positioned(
                right: -4,
                top: -4,
                child: CircleAvatar(
                  radius: 9,
                  backgroundColor: theme.colorScheme.error,
                  child: Text(
                    '${unreadCount.clamp(0, 9)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: theme.colorScheme.onError,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final double totalBalance;
  final double income;
  final double expense;
  final double savings;

  const _BalanceCard({
    required this.totalBalance,
    required this.income,
    required this.expense,
    required this.savings,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.finColors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 20 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.heroStart, colors.heroEnd],
            ),
            border: Border.all(
              color: colors.heroForeground.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.heroEnd.withValues(alpha: 0.12),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Общий баланс',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.heroForeground.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: colors.heroForeground.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      color: colors.heroForeground,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: totalBalance),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    return Text(
                      '${_formatAmount(value)} ₸',
                      style: TextStyle(
                        color: colors.heroForeground,
                        fontSize: compact ? 32 : 38,
                        letterSpacing: -1,
                        fontWeight: FontWeight.w700,
                      ),
                    );
                  },
                ),
              ),

              SizedBox(height: compact ? 20 : 24),

              Container(
                height: 1,
                color: colors.heroForeground.withValues(alpha: 0.18),
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  Expanded(
                    child: _BalanceStat(
                      compact: compact,
                      icon: Icons.south_west_rounded,
                      title: 'Доходы',
                      amount: '${_formatAmount(income)} ₸',
                      foreground: colors.heroForeground,
                    ),
                  ),

                  Container(
                    width: 1,
                    height: 43,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: colors.heroForeground.withValues(alpha: 0.18),
                  ),

                  Expanded(
                    child: _BalanceStat(
                      compact: compact,
                      icon: Icons.north_east_rounded,
                      title: 'Расходы',
                      amount: '${_formatAmount(expense)} ₸',
                      foreground: colors.heroForeground,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 11 : 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: colors.heroForeground.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      savings >= 0
                          ? Icons.savings_outlined
                          : Icons.trending_down_rounded,
                      color: colors.heroForeground,
                      size: 19,
                    ),

                    const SizedBox(width: 8),

                    Expanded(
                      child: Text(
                        savings >= 0
                            ? 'Сбережено в этом месяце'
                            : 'Расходы выше доходов',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.heroForeground.withValues(alpha: 0.72),
                          fontSize: compact ? 10 : 12,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${savings >= 0 ? '+' : '−'}'
                        '${_formatAmount(savings.abs())} ₸',
                        style: TextStyle(
                          color: colors.heroForeground,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 11 : 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BalanceStat extends StatelessWidget {
  final bool compact;
  final IconData icon;
  final String title;
  final String amount;
  final Color foreground;

  const _BalanceStat({
    required this.compact,
    required this.icon,
    required this.title,
    required this.amount,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: foreground.withValues(alpha: 0.8), size: 16),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground.withValues(alpha: 0.7),
                  fontSize: compact ? 10 : 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            amount,
            style: TextStyle(
              color: foreground,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountsList extends StatefulWidget {
  final List<Account> accounts;

  const _AccountsList({required this.accounts});

  @override
  State<_AccountsList> createState() => _AccountsListState();
}

class _AccountsListState extends State<_AccountsList> {
  final PageController _pageController = PageController(keepPage: false);
  int _currentPage = 0;

  @override
  void didUpdateWidget(covariant _AccountsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selectedId =
        _currentPage < oldWidget.accounts.length
            ? oldWidget.accounts[_currentPage].id
            : null;
    final matchingIndex = widget.accounts.indexWhere(
      (account) => account.id == selectedId,
    );
    final nextPage =
        widget.accounts.isEmpty
            ? 0
            : matchingIndex >= 0
            ? matchingIndex
            : _currentPage.clamp(0, widget.accounts.length - 1);
    if (nextPage != _currentPage) {
      _currentPage = nextPage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(_currentPage);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.accounts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: theme.colorScheme.primary,
              size: 30,
            ),
            const SizedBox(height: 10),
            Text('Добавь первый счёт', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'Карта, наличные, депозит или накопления',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 360;
    final cardHeight = compact ? 160.0 : 168.0;

    if (widget.accounts.length == 1) {
      return SizedBox(
        width: double.infinity,
        height: cardHeight,
        child: _AccountCard(
          key: Key('dashboard_account_${widget.accounts.single.id}'),
          account: widget.accounts.single,
        ),
      );
    }

    return SizedBox(
      height: cardHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final peek = (width * 0.105).clamp(28.0, 44.0).toDouble();
          final cardWidth = width - peek;
          const gap = 10.0;
          final stride = cardWidth + gap;
          final lastIndex = widget.accounts.length - 1;

          return Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              AnimatedBuilder(
                animation: _pageController,
                builder: (context, _) {
                  final page = (_pageController.hasClients &&
                              _pageController.position.hasContentDimensions
                          ? _pageController.page ?? _currentPage.toDouble()
                          : _currentPage.toDouble())
                      .clamp(0.0, lastIndex.toDouble());
                  final lowerPage = page.floor();
                  final upperPage = page.ceil();
                  double anchor(int index) =>
                      index == 0
                          ? 0
                          : index == lastIndex
                          ? peek
                          : peek / 2;
                  final activeLeft =
                      anchor(lowerPage) +
                      (anchor(upperPage) - anchor(lowerPage)) *
                          (page - lowerPage);
                  final firstVisible = (lowerPage - 1).clamp(0, lastIndex);
                  final lastVisible = (upperPage + 1).clamp(0, lastIndex);

                  return IgnorePointer(
                    child: Stack(
                      clipBehavior: Clip.hardEdge,
                      children: [
                        for (
                          var index = firstVisible;
                          index <= lastVisible;
                          index++
                        )
                          Positioned(
                            left: activeLeft + (index - page) * stride,
                            top: 0,
                            width: cardWidth,
                            height: cardHeight,
                            child: ExcludeSemantics(
                              excluding: index != page.round(),
                              child: _AccountCard(
                                key: Key(
                                  'dashboard_account_${widget.accounts[index].id}',
                                ),
                                account: widget.accounts[index],
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
              PageView.builder(
                controller: _pageController,
                physics: const BouncingScrollPhysics(),
                itemCount: widget.accounts.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) => const SizedBox.expand(),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final Account account;

  const _AccountCard({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.finColors;
    final comparison = context
        .read<FinanceController>()
        .accountExpenseComparison(account.id);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 280;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(compact ? 14 : 17),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: colors.softAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _accountIcon(account.type),
                      size: 19,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (!account.includeInTotal) ...[
                    const SizedBox(width: 4),
                    Tooltip(
                      message: 'Не учитывается в общем балансе',
                      child: Icon(
                        Icons.visibility_off_outlined,
                        color: theme.colorScheme.onSurfaceVariant,
                        size: 17,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 9),
              Text(
                _accountSubtitle(account),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 11),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    flex: 2,
                    child: _AccountExpenseBadge(comparison: comparison),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Баланс',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${_formatAmount(account.balance)} ₸',
                            maxLines: 1,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AccountExpenseBadge extends StatelessWidget {
  final AccountExpenseComparison comparison;

  const _AccountExpenseBadge({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.finColors;
    final change = comparison.percentChange;
    final color =
        change == null || change == 0
            ? theme.colorScheme.onSurfaceVariant
            : change < 0
            ? colors.income
            : colors.expense;
    final icon =
        change == null || change == 0
            ? Icons.remove_rounded
            : change < 0
            ? Icons.south_rounded
            : Icons.north_rounded;
    final value =
        change == null
            ? '—'
            : change == 0
            ? '0%'
            : '${change.abs().toStringAsFixed(1)}%';
    final explanation =
        change == null
            ? 'Нет расходов за те же дни прошлого месяца'
            : 'Расходы: ${_formatAmount(comparison.currentExpense)} ₸ сейчас, '
                '${_formatAmount(comparison.previousExpense)} ₸ за те же дни прошлого месяца';

    return Tooltip(
      message: explanation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Расходы',
            maxLines: 1,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 2),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    maxLines: 1,
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpendingCard extends StatelessWidget {
  final double expense;
  final ExpenseChartSeries series;

  const _SpendingCard({required this.expense, required this.series});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 320;

        return Container(
          padding: EdgeInsets.fromLTRB(
            compact ? 18 : 20,
            compact ? 18 : 20,
            compact ? 18 : 20,
            18,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Расходы за месяц',
                          style: theme.textTheme.bodyMedium,
                        ),

                        const SizedBox(height: 4),

                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${_formatAmount(expense)} ₸',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontSize: 23,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _monthName(DateTime.now().month),
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: compact ? 10 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              SmoothLineChart(
                values: series.values,
                dates: series.dates,
                lineColor: theme.colorScheme.primary,
                height: compact ? 100 : 115,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RecentTransactions extends StatelessWidget {
  final List<FinanceTransaction> transactions;

  const _RecentTransactions({required this.transactions});

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Text(
          'Пока нет операций',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var index = 0; index < transactions.length; index++) ...[
            _TransactionRow(transaction: transactions[index]),
            if (index != transactions.length - 1)
              Divider(
                height: 1,
                indent: 18,
                endIndent: 18,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  final FinanceTransaction transaction;

  const _TransactionRow({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.finColors;

    final finance = context.read<FinanceController>();

    final appearance = _transactionAppearance(transaction.type, colors);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 330;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 14 : 18,
            vertical: compact ? 13 : 15,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 40 : 44,
                height: compact ? 40 : 44,
                decoration: BoxDecoration(
                  color: appearance.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  appearance.icon,
                  color: appearance.color,
                  size: compact ? 19 : 21,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      transaction.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: compact ? 13 : 14,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _transactionSubtitle(transaction, finance),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontSize: compact ? 10 : 11,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: compact ? 82 : 110),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    _transactionAmount(transaction),
                    style: TextStyle(
                      color: appearance.color,
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 11 : 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionAppearance {
  final IconData icon;
  final Color color;

  const _TransactionAppearance({required this.icon, required this.color});
}

_TransactionAppearance _transactionAppearance(
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

String _transactionSubtitle(
  FinanceTransaction transaction,
  FinanceController finance,
) {
  if (transaction.type == FinanceTransactionType.transfer) {
    return '${finance.accountName(transaction.accountId)}'
        ' → '
        '${finance.accountName(transaction.destinationAccountId ?? '')}';
  }

  return '${finance.categoryName(transaction.categoryId)}'
      ' · '
      '${finance.accountName(transaction.accountId)}';
}

String _transactionAmount(FinanceTransaction transaction) {
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onTap;

  const _SectionHeader({required this.title, this.action, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 19),
          ),
        ),

        if (action != null && onTap != null) ...[
          const SizedBox(width: 8),
          TextButton(onPressed: onTap, child: Text(action!, maxLines: 1)),
        ],
      ],
    );
  }
}

class _Reveal extends StatelessWidget {
  final Animation<double> animation;

  final double start;
  final double end;

  final Widget child;

  const _Reveal({
    required this.animation,
    required this.start,
    required this.end,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

IconData _accountIcon(AccountType type) {
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

String _accountSubtitle(Account account) {
  final type = switch (account.type) {
    AccountType.card => 'Карта',
    AccountType.cash => 'Наличные',
    AccountType.deposit => 'Депозит',
    AccountType.savings => 'Накопления',
    AccountType.other => 'Другой счёт',
  };

  if (account.bankName == null || account.bankName!.trim().isEmpty) {
    return type;
  }

  return '$type · ${account.bankName}';
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

  return '${negative ? '−' : ''}${buffer.toString()}';
}

String _monthName(int month) {
  const names = [
    'Январь',
    'Февраль',
    'Март',
    'Апрель',
    'Май',
    'Июнь',
    'Июль',
    'Август',
    'Сентябрь',
    'Октябрь',
    'Ноябрь',
    'Декабрь',
  ];

  return names[month - 1];
}
