import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';

enum SavingsCalculatorMode { contribution, deadline }

enum SavingsPeriodUnit { months, years }

class SavingsCalculatorScreen extends StatefulWidget {
  const SavingsCalculatorScreen({super.key});

  @override
  State<SavingsCalculatorScreen> createState() =>
      _SavingsCalculatorScreenState();
}

class _SavingsCalculatorScreenState extends State<SavingsCalculatorScreen> {
  final _targetController = TextEditingController(text: '5000000');

  final _currentController = TextEditingController(text: '500000');

  final _periodController = TextEditingController(text: '24');

  final _monthlyController = TextEditingController(text: '150000');

  SavingsCalculatorMode _mode = SavingsCalculatorMode.contribution;

  SavingsPeriodUnit _periodUnit = SavingsPeriodUnit.months;

  @override
  void initState() {
    super.initState();

    _targetController.addListener(_refresh);
    _currentController.addListener(_refresh);
    _periodController.addListener(_refresh);
    _monthlyController.addListener(_refresh);
  }

  @override
  void dispose() {
    _targetController
      ..removeListener(_refresh)
      ..dispose();

    _currentController
      ..removeListener(_refresh)
      ..dispose();

    _periodController
      ..removeListener(_refresh)
      ..dispose();

    _monthlyController
      ..removeListener(_refresh)
      ..dispose();

    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.finColors;

    final target = _parseAmount(_targetController.text);

    final current = _parseAmount(_currentController.text);

    final remaining = math.max(0.0, target - current).toDouble();

    final progress =
        target <= 0 ? 0.0 : (current / target).clamp(0.0, 1.0).toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Калькулятор накоплений')),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(17),
                  ),
                  child: Icon(
                    Icons.calculate_outlined,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 18),
                Text('План накоплений', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Посчитай, сколько нужно откладывать '
                  'или когда получится накопить нужную сумму.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _ModeSelector(
            mode: _mode,
            onChanged: (value) {
              setState(() {
                _mode = value;
              });
            },
          ),

          const SizedBox(height: 28),

          Text('Цель', style: theme.textTheme.titleLarge),

          const SizedBox(height: 12),

          TextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Нужная сумма',
              suffixText: '₸',
              prefixIcon: Icon(Icons.flag_outlined),
            ),
          ),

          const SizedBox(height: 14),

          TextField(
            controller: _currentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
            ],
            decoration: const InputDecoration(
              labelText: 'Уже накоплено',
              suffixText: '₸',
              prefixIcon: Icon(Icons.savings_outlined),
            ),
          ),

          const SizedBox(height: 18),

          _ProgressCard(
            target: target,
            current: current,
            remaining: remaining,
            progress: progress,
          ),

          const SizedBox(height: 28),

          if (_mode == SavingsCalculatorMode.contribution)
            _ContributionMode(
              periodController: _periodController,
              unit: _periodUnit,
              onUnitChanged: (value) {
                setState(() {
                  _periodUnit = value;
                });
              },
              remaining: remaining,
            )
          else
            _DeadlineMode(
              monthlyController: _monthlyController,
              remaining: remaining,
            ),

          const SizedBox(height: 28),

          if (target <= 0)
            const _HintCard(
              icon: Icons.info_outline_rounded,
              text: 'Укажи сумму цели, чтобы выполнить расчёт.',
            )
          else if (current >= target)
            _CompletedCard(color: colors.income),
        ],
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final SavingsCalculatorMode mode;

  final ValueChanged<SavingsCalculatorMode> onChanged;

  const _ModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeItem(
              title: 'Сколько откладывать',
              icon: Icons.payments_outlined,
              selected: mode == SavingsCalculatorMode.contribution,
              onTap: () {
                onChanged(SavingsCalculatorMode.contribution);
              },
            ),
          ),
          Expanded(
            child: _ModeItem(
              title: 'Когда накоплю',
              icon: Icons.event_available_outlined,
              selected: mode == SavingsCalculatorMode.deadline,
              onTap: () {
                onChanged(SavingsCalculatorMode.deadline);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeItem({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      selected
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final double target;
  final double current;
  final double remaining;
  final double progress;

  const _ProgressCard({
    required this.target,
    required this.current,
    required this.remaining,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.finColors;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _SmallMetric(
                  title: 'Накоплено',
                  value: '${_formatAmount(current)} ₸',
                  color: colors.income,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _SmallMetric(
                  title: 'Осталось',
                  value: '${_formatAmount(remaining)} ₸',
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: theme.colorScheme.outlineVariant.withValues(
                alpha: 0.35,
              ),
              valueColor: AlwaysStoppedAnimation<Color>(
                theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${(progress * 100).toStringAsFixed(1)}%',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
              ),
              Text(
                'Цель ${_formatAmount(target)} ₸',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallMetric extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SmallMetric({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9)),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: color,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContributionMode extends StatelessWidget {
  final TextEditingController periodController;

  final SavingsPeriodUnit unit;

  final ValueChanged<SavingsPeriodUnit> onUnitChanged;

  final double remaining;

  const _ContributionMode({
    required this.periodController,
    required this.unit,
    required this.onUnitChanged,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final rawPeriod = int.tryParse(periodController.text.trim()) ?? 0;

    final months =
        unit == SavingsPeriodUnit.months ? rawPeriod : rawPeriod * 12;

    final monthly = months <= 0 ? 0.0 : remaining / months;

    final weekly = monthly <= 0 ? 0.0 : monthly * 12 / 52;

    final daily = monthly <= 0 ? 0.0 : monthly * 12 / 365;

    final yearly = monthly * 12;

    final deadline =
        months <= 0
            ? null
            : DateTime(
              DateTime.now().year,
              DateTime.now().month + months,
              DateTime.now().day,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('За какой срок?', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: periodController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText:
                      unit == SavingsPeriodUnit.months
                          ? 'Количество месяцев'
                          : 'Количество лет',
                  prefixIcon: const Icon(Icons.schedule_outlined),
                ),
              ),
            ),
            const SizedBox(width: 9),
            _UnitSelector(unit: unit, onChanged: onUnitChanged),
          ],
        ),
        const SizedBox(height: 22),
        Text('Нужно откладывать', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        _ResultMainCard(
          title: 'Каждый месяц',
          value: '${_formatAmount(monthly)} ₸',
          subtitle:
              deadline == null
                  ? 'Укажи срок'
                  : 'Цель примерно к ${_dateText(deadline)}',
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _ResultSmallCard(title: 'В неделю', amount: weekly),
            ),
            const SizedBox(width: 10),
            Expanded(child: _ResultSmallCard(title: 'В день', amount: daily)),
          ],
        ),
        const SizedBox(height: 10),
        _ResultSmallCard(title: 'За год', amount: yearly),
      ],
    );
  }
}

class _DeadlineMode extends StatelessWidget {
  final TextEditingController monthlyController;

  final double remaining;

  const _DeadlineMode({
    required this.monthlyController,
    required this.remaining,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final monthly = _parseAmount(monthlyController.text);

    final months = monthly <= 0 ? 0 : (remaining / monthly).ceil();

    final deadline =
        months <= 0
            ? null
            : DateTime(
              DateTime.now().year,
              DateTime.now().month + months,
              DateTime.now().day,
            );

    final years = months / 12;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Сколько можешь откладывать?', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        TextField(
          controller: monthlyController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
          ],
          decoration: const InputDecoration(
            labelText: 'В месяц',
            suffixText: '₸',
            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
          ),
        ),
        const SizedBox(height: 22),
        Text('Прогноз', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        _ResultMainCard(
          title: 'До достижения цели',
          value: months <= 0 ? '—' : '$months ${_monthWord(months)}',
          subtitle:
              deadline == null
                  ? 'Укажи ежемесячную сумму'
                  : 'Примерно ${_dateText(deadline)}',
        ),
        if (months > 0) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _TextResultCard(
                  title: 'Это примерно',
                  value:
                      years < 1
                          ? '$months мес.'
                          : '${years.toStringAsFixed(1)} года',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TextResultCard(
                  title: 'За год',
                  value: '${_formatAmount(monthly * 12)} ₸',
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _UnitSelector extends StatelessWidget {
  final SavingsPeriodUnit unit;

  final ValueChanged<SavingsPeriodUnit> onChanged;

  const _UnitSelector({required this.unit, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 100,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          _UnitButton(
            title: 'Мес.',
            selected: unit == SavingsPeriodUnit.months,
            onTap: () {
              onChanged(SavingsPeriodUnit.months);
            },
          ),
          const SizedBox(height: 3),
          _UnitButton(
            title: 'Лет',
            selected: unit == SavingsPeriodUnit.years,
            onTap: () {
              onChanged(SavingsPeriodUnit.years);
            },
          ),
        ],
      ),
    );
  }
}

class _UnitButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _UnitButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color:
                selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ResultMainCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _ResultMainCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
          ),
        ],
      ),
    );
  }
}

class _ResultSmallCard extends StatelessWidget {
  final String title;
  final double amount;

  const _ResultSmallCard({required this.title, required this.amount});

  @override
  Widget build(BuildContext context) {
    return _TextResultCard(title: title, value: '${_formatAmount(amount)} ₸');
  }
}

class _TextResultCard extends StatelessWidget {
  final String title;
  final String value;

  const _TextResultCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: theme.textTheme.titleMedium?.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintCard({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(21),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _CompletedCard extends StatelessWidget {
  final Color color;

  const _CompletedCard({required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline_rounded, color: color),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Цель уже достигнута', style: theme.textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  'Текущая сумма уже равна или больше цели.',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

double _parseAmount(String value) {
  return double.tryParse(
        value.replaceAll(' ', '').replaceAll(',', '.').trim(),
      ) ??
      0;
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

String _dateText(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _monthWord(int months) {
  final lastTwo = months % 100;

  if (lastTwo >= 11 && lastTwo <= 14) {
    return 'месяцев';
  }

  switch (months % 10) {
    case 1:
      return 'месяц';

    case 2:
    case 3:
    case 4:
      return 'месяца';

    default:
      return 'месяцев';
  }
}
