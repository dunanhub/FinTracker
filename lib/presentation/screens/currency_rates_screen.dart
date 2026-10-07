import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/currency_rate.dart';
import '../providers/currency_rates_provider.dart';

enum _ConversionDirection { foreignToKzt, kztToForeign }

class CurrencyRatesPage extends StatelessWidget {
  const CurrencyRatesPage({super.key});

  @override
  Widget build(BuildContext context) => const CurrencyRatesScreen();
}

class CurrencyRatesScreen extends ConsumerStatefulWidget {
  const CurrencyRatesScreen({super.key});

  @override
  ConsumerState<CurrencyRatesScreen> createState() =>
      _CurrencyRatesScreenState();
}

class _CurrencyRatesScreenState extends ConsumerState<CurrencyRatesScreen> {
  final TextEditingController _amountController = TextEditingController(
    text: '100',
  );

  String _selectedCode = 'USD';

  _ConversionDirection _direction = _ConversionDirection.foreignToKzt;

  @override
  void initState() {
    super.initState();

    _amountController.addListener(_refresh);
  }

  @override
  void dispose() {
    _amountController
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
    final ratesState = ref.watch(currencyRatesProvider);
    final controller = ref.read(currencyRatesProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Курсы валют'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed:
                ratesState.isLoading
                    ? null
                    : () {
                      controller.refresh();
                    },
            icon:
                ratesState.isLoading
                    ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _buildBody(context, ratesState),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<CurrencyRate>> ratesState,
  ) {
    final controller = ref.read(currencyRatesProvider.notifier);
    return ratesState.when(
      skipLoadingOnRefresh: false,
      loading: () => const _LoadingView(),
      error:
          (error, stackTrace) => _ErrorView(
            message: error.toString(),
            onRetry: controller.refresh,
          ),
      data:
          (rates) =>
              rates.isEmpty
                  ? _EmptyView(onRetry: controller.refresh)
                  : _buildContent(context, rates, controller),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<CurrencyRate> rates,
    CurrencyRatesNotifier controller,
  ) {
    final theme = Theme.of(context);

    final selectedRate = controller.rateByCode(_selectedCode) ?? rates.first;

    final amount = _parseAmount(_amountController.text);

    final converted =
        _direction == _ConversionDirection.foreignToKzt
            ? controller.convertForeignToKzt(
              currencyCode: selectedRate.code,
              amount: amount,
            )
            : controller.convertKztToForeign(
              currencyCode: selectedRate.code,
              amount: amount,
            );

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          _HeaderCard(date: controller.rateDate),

          const SizedBox(height: 26),

          Text('Конвертер', style: theme.textTheme.titleLarge),

          const SizedBox(height: 12),

          _ConverterCard(
            rates: rates,
            selectedRate: selectedRate,
            selectedCode: selectedRate.code,
            amountController: _amountController,
            direction: _direction,
            converted: converted,
            onCurrencyChanged: (value) {
              if (value == null) {
                return;
              }

              setState(() {
                _selectedCode = value;
              });
            },
            onSwap: () {
              setState(() {
                _selectedCode = selectedRate.code;

                _direction =
                    _direction == _ConversionDirection.foreignToKzt
                        ? _ConversionDirection.kztToForeign
                        : _ConversionDirection.foreignToKzt;
              });
            },
          ),

          const SizedBox(height: 28),

          Row(
            children: [
              Expanded(
                child: Text('Курсы НБК', style: theme.textTheme.titleLarge),
              ),
              Text(
                '${rates.length} валют',
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
              ),
            ],
          ),

          const SizedBox(height: 12),

          ...rates.map((rate) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _CurrencyRateCard(rate: rate),
            );
          }),

          const SizedBox(height: 15),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Курсы используются для '
                    'информационного расчёта. '
                    'Курс банка при покупке или продаже '
                    'валюты может отличаться.',
                    style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final DateTime? date;

  const _HeaderCard({required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.currency_exchange_rounded,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Курс валют', style: theme.textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  date == null
                      ? 'Национальный Банк Казахстана'
                      : 'НБК · ${_dateText(date!)}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              'KZT',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConverterCard extends StatelessWidget {
  final List<CurrencyRate> rates;

  final CurrencyRate selectedRate;

  final String selectedCode;

  final TextEditingController amountController;

  final _ConversionDirection direction;

  final double converted;

  final ValueChanged<String?> onCurrencyChanged;

  final VoidCallback onSwap;

  const _ConverterCard({
    required this.rates,
    required this.selectedRate,
    required this.selectedCode,
    required this.amountController,
    required this.direction,
    required this.converted,
    required this.onCurrencyChanged,
    required this.onSwap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final colors = context.finColors;

    final foreignToKzt = direction == _ConversionDirection.foreignToKzt;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedCode,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Валюта',
              prefixIcon: Icon(Icons.language_rounded),
            ),
            items:
                rates
                    .map(
                      (rate) => DropdownMenuItem<String>(
                        value: rate.code,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 34,
                              child: Text(
                                rate.code,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                rate.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                    .toList(),
            onChanged: onCurrencyChanged,
          ),

          const SizedBox(height: 14),

          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9., ]')),
            ],
            decoration: InputDecoration(
              labelText:
                  foreignToKzt
                      ? 'Сумма в ${selectedRate.code}'
                      : 'Сумма в тенге',
              suffixText: foreignToKzt ? selectedRate.symbol : '₸',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
              const SizedBox(width: 10),
              Material(
                color: theme.colorScheme.primary.withValues(alpha: 0.10),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSwap,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      Icons.swap_vert_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Divider(color: theme.colorScheme.outlineVariant)),
            ],
          ),

          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: colors.softAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  foreignToKzt
                      ? 'Получится в тенге'
                      : 'Получится в ${selectedRate.code}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
                ),

                const SizedBox(height: 5),

                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    foreignToKzt
                        ? '${_formatMoney(converted)} ₸'
                        : '${_formatForeign(converted)} ${selectedRate.symbol}',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  '1 ${selectedRate.code} = '
                  '${_formatRate(selectedRate.rateToKzt)} ₸',
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

class _CurrencyRateCard extends StatelessWidget {
  final CurrencyRate rate;

  const _CurrencyRateCard({required this.rate});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              rate.symbol,
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(rate.code, style: theme.textTheme.titleMedium),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        rate.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 4),

                Text(
                  '1 ${rate.code}',
                  style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${_formatRate(rate.rateToKzt)} ₸',
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 3),
              Text(
                _dateText(rate.date),
                style: theme.textTheme.bodyMedium?.copyWith(fontSize: 8),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  final Future<void> Function() onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          children: [
            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: theme.colorScheme.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.wifi_off_rounded,
                color: theme.colorScheme.error,
              ),
            ),

            const SizedBox(height: 18),

            Text('Не удалось загрузить', style: theme.textTheme.titleLarge),

            const SizedBox(height: 7),

            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),

            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: () {
                onRetry();
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Повторить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _EmptyView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.currency_exchange_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 15),
            Text('Курсы не найдены', style: theme.textTheme.titleLarge),
            const SizedBox(height: 7),
            Text(
              'Сервис вернул пустой список валют.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () {
                onRetry();
              },
              child: const Text('Обновить'),
            ),
          ],
        ),
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

String _dateText(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.'
      '${date.month.toString().padLeft(2, '0')}.'
      '${date.year}';
}

String _formatRate(double value) {
  if (value >= 100) {
    return _formatNumber(value, 2);
  }

  if (value >= 1) {
    return _formatNumber(value, 2);
  }

  return _formatNumber(value, 4);
}

String _formatMoney(double value) {
  return _formatNumber(value, 2);
}

String _formatForeign(double value) {
  return _formatNumber(value, 2);
}

String _formatNumber(double value, int decimals) {
  final negative = value < 0;

  final absolute = value.abs();

  final parts = absolute.toStringAsFixed(decimals).split('.');

  final digits = parts.first;

  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    final remaining = digits.length - i;

    buffer.write(digits[i]);

    if (remaining > 1 && remaining % 3 == 1) {
      buffer.write(' ');
    }
  }

  if (decimals == 0) {
    return '${negative ? '−' : ''}'
        '${buffer.toString()}';
  }

  return '${negative ? '−' : ''}'
      '${buffer.toString()},'
      '${parts.last}';
}
