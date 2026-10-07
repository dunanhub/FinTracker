import 'dart:async';

import 'package:fin_tracker/data/repositories/frankfurter_currency_repository.dart';
import 'package:fin_tracker/domain/entities/currency_rate.dart';
import 'package:fin_tracker/domain/repositories/currency_repository.dart';
import 'package:fin_tracker/presentation/providers/currency_rates_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCurrencyRepository implements CurrencyRepository {
  int calls = 0;
  Future<List<CurrencyRate>> Function()? response;

  @override
  Future<List<CurrencyRate>> fetchRates() {
    calls++;
    return response?.call() ?? Future.value([_rate(540)]);
  }
}

CurrencyRate _rate(double rateToKzt) => CurrencyRate(
  code: 'USD',
  name: 'Доллар США',
  symbol: r'$',
  rateToKzt: rateToKzt,
  date: DateTime(2026, 10, 5),
);

ProviderContainer _container(_FakeCurrencyRepository repository) {
  final container = ProviderContainer.test(
    overrides: [currencyRepositoryProvider.overrideWithValue(repository)],
  );
  final subscription = container.listen(currencyRatesProvider, (_, _) {});
  addTearDown(subscription.close);
  return container;
}

void main() {
  test('initial state loads rates and exposes AsyncLoading', () async {
    final pending = Completer<List<CurrencyRate>>();
    final repository =
        _FakeCurrencyRepository()..response = () => pending.future;
    final container = _container(repository);

    expect(container.read(currencyRatesProvider).isLoading, isTrue);
    expect(repository.calls, 1);

    pending.complete([_rate(540)]);
    await container.read(currencyRatesProvider.future);
    expect(container.read(currencyRatesProvider).hasValue, isTrue);
  });

  test('successful response becomes AsyncData', () async {
    final repository = _FakeCurrencyRepository();
    final container = _container(repository);

    final rates = await container.read(currencyRatesProvider.future);

    expect(rates.single.rateToKzt, 540);
    expect(
      container.read(currencyRatesProvider),
      isA<AsyncData<List<CurrencyRate>>>(),
    );
    expect(
      container.read(currencyRatesProvider.notifier).rateDate,
      DateTime(2026, 10, 5),
    );
  });

  test('repository exception becomes AsyncError', () async {
    final repository =
        _FakeCurrencyRepository()
          ..response =
              () async => throw const CurrencyRepositoryException('Нет сети');
    final container = _container(repository);

    await expectLater(
      container.read(currencyRatesProvider.future),
      throwsA(isA<CurrencyRepositoryException>()),
    );

    expect(
      container.read(currencyRatesProvider),
      isA<AsyncError<List<CurrencyRate>>>(),
    );
    expect(repository.calls, 1);
  });

  test('refresh calls repository again and replaces rates', () async {
    final repository = _FakeCurrencyRepository();
    final container = _container(repository);
    await container.read(currencyRatesProvider.future);

    repository.response = () async => [_rate(550)];
    await container.read(currencyRatesProvider.notifier).refresh();

    expect(repository.calls, 2);
    expect(container.read(currencyRatesProvider).value?.single.rateToKzt, 550);
  });

  test('retry after error can transition to data', () async {
    final repository =
        _FakeCurrencyRepository()
          ..response =
              () async => throw const CurrencyRepositoryException('Нет сети');
    final container = _container(repository);
    await expectLater(
      container.read(currencyRatesProvider.future),
      throwsA(isA<CurrencyRepositoryException>()),
    );

    repository.response = () async => [_rate(545)];
    await container.read(currencyRatesProvider.notifier).refresh();

    expect(repository.calls, 2);
    expect(
      container.read(currencyRatesProvider),
      isA<AsyncData<List<CurrencyRate>>>(),
    );
  });

  test('repository provider can be overridden with a fake', () async {
    final repository = _FakeCurrencyRepository();
    final container = _container(repository);

    expect(
      identical(container.read(currencyRepositoryProvider), repository),
      isTrue,
    );
    await container.read(currencyRatesProvider.future);
    expect(repository.calls, 1);
  });

  test('conversion keeps existing KZT calculations', () async {
    final container = _container(_FakeCurrencyRepository());
    await container.read(currencyRatesProvider.future);
    final notifier = container.read(currencyRatesProvider.notifier);

    expect(notifier.convertForeignToKzt(currencyCode: 'USD', amount: 2), 1080);
    expect(notifier.convertKztToForeign(currencyCode: 'USD', amount: 1080), 2);
    expect(notifier.convertForeignToKzt(currencyCode: 'EUR', amount: 2), 0);
  });
}
