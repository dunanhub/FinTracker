class CurrencyRate {
  final String code;
  final String name;
  final String symbol;

  /// Стоимость одной единицы валюты в тенге.
  ///
  /// Например:
  /// 1 USD = 540 KZT
  /// rateToKzt = 540
  final double rateToKzt;

  final DateTime date;

  const CurrencyRate({
    required this.code,
    required this.name,
    required this.symbol,
    required this.rateToKzt,
    required this.date,
  });
}
