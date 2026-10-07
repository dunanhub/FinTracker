import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/frankfurter_currency_repository.dart';
import '../../domain/entities/currency_rate.dart';
import '../../domain/repositories/currency_repository.dart';

final currencyRepositoryProvider = Provider<CurrencyRepository>(
  (ref) => FrankfurterCurrencyRepository(),
);

final currencyRatesProvider = AsyncNotifierProvider.autoDispose<
  CurrencyRatesNotifier,
  List<CurrencyRate>
>(CurrencyRatesNotifier.new, retry: (retryCount, error) => null);

class CurrencyRatesNotifier extends AsyncNotifier<List<CurrencyRate>> {
  @override
  Future<List<CurrencyRate>> build() =>
      ref.watch(currencyRepositoryProvider).fetchRates();

  Future<void> refresh() async {
    if (state.isLoading) return;

    state = const AsyncLoading();
    final result = await AsyncValue.guard(
      () => ref.read(currencyRepositoryProvider).fetchRates(),
    );
    if (ref.mounted) state = result;
  }

  DateTime? get rateDate {
    final rates = state.value;
    return rates == null || rates.isEmpty ? null : rates.first.date;
  }

  CurrencyRate? rateByCode(String code) {
    for (final rate in state.value ?? <CurrencyRate>[]) {
      if (rate.code == code) return rate;
    }
    return null;
  }

  double convertForeignToKzt({
    required String currencyCode,
    required double amount,
  }) {
    final rate = rateByCode(currencyCode);
    if (rate == null || amount <= 0) return 0;
    return amount * rate.rateToKzt;
  }

  double convertKztToForeign({
    required String currencyCode,
    required double amount,
  }) {
    final rate = rateByCode(currencyCode);
    if (rate == null || amount <= 0 || rate.rateToKzt <= 0) return 0;
    return amount / rate.rateToKzt;
  }
}
