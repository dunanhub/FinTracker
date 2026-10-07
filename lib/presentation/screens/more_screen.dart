import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_routes.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 150),
        children: [
          Text('Ещё', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 5),
          Text(
            'Управление финансами и приложением',
            style: theme.textTheme.bodyMedium,
          ),

          const SizedBox(height: 30),

          const _SectionTitle(title: 'Финансы'),

          const SizedBox(height: 10),

          _MenuGroup(
            children: [
              _MenuItem(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Счета',
                subtitle: 'Карты, наличные и депозиты',
                onTap: () {
                  context.push(AppRoutes.accounts);
                },
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.pie_chart_outline_rounded,
                title: 'Бюджеты',
                subtitle: 'Лимиты расходов по категориям',
                onTap: () {
                  context.push(AppRoutes.budgets);
                },
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.flag_outlined,
                title: 'Финансовые цели',
                subtitle: 'Накопления и планы',
                onTap: () {
                  context.push(AppRoutes.goals);
                },
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.handshake_outlined,
                title: 'Долги',
                subtitle: 'Мне должны и я должен',
                onTap: () {
                  context.push(AppRoutes.debts);
                },
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.description_outlined,
                title: 'Отчёты',
                subtitle: 'CSV, Excel и PDF',
                onTap: () {
                  context.push(AppRoutes.reports);
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          const _SectionTitle(title: 'Инструменты'),

          const SizedBox(height: 10),

          _MenuGroup(
            children: [
              _MenuItem(
                icon: Icons.currency_exchange_rounded,
                title: 'Курсы валют',
                subtitle: 'Курсы НБК и конвертер',
                onTap: () {
                  context.push(AppRoutes.currencyRates);
                },
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.calculate_outlined,
                title: 'Калькулятор накоплений',
                subtitle: 'Срок и сумма ежемесячных накоплений',
                onTap: () {
                  context.push(AppRoutes.calculator);
                },
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.map_outlined,
                title: 'Карта операций',
                subtitle: 'Покупки и места на карте',
                onTap: () {
                  context.push(AppRoutes.transactionMap);
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          const _SectionTitle(title: 'Приложение'),

          const SizedBox(height: 10),

          _MenuGroup(
            children: [
              _MenuItem(
                icon: Icons.person_outline_rounded,
                title: 'Аккаунт',
                subtitle: 'Профиль и синхронизация',
                onTap: () {
                  context.push(AppRoutes.account);
                },
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.settings_outlined,
                title: 'Настройки',
                subtitle: 'Тема, оформление и параметры',
                onTap: () {
                  context.push(AppRoutes.settings);
                },
              ),
              const _MenuDivider(),
              _MenuItem(
                icon: Icons.monitor_heart_outlined,
                title: 'Диагностика устройства',
                subtitle: 'Батарея и сведения об Android',
                onTap: () {
                  context.push(AppRoutes.deviceDiagnostics);
                },
              ),
            ],
          ),

          const SizedBox(height: 28),

          Center(
            child: Text(
              'FinTracker',
              style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
            ),
          ),

          const SizedBox(height: 3),

          Center(
            child: Text(
              'Personal Finance Manager',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 9,
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 12),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  final List<Widget> children;

  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, size: 20, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
                    ),
                  ],
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
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 70, right: 14),
      child: Divider(
        height: 1,
        thickness: 1,
        color: Theme.of(
          context,
        ).colorScheme.outlineVariant.withValues(alpha: 0.7),
      ),
    );
  }
}
