import 'package:dio/dio.dart';

import '../../domain/entities/currency_rate.dart';
import '../../domain/repositories/currency_repository.dart';

class CurrencyRepositoryException implements Exception {
  final String message;

  const CurrencyRepositoryException(this.message);

  @override
  String toString() => message;
}

class FrankfurterCurrencyRepository implements CurrencyRepository {
  final Dio _dio;

  FrankfurterCurrencyRepository({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://api.frankfurter.dev/v2',
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 10),
              headers: const {'Accept': 'application/json'},
            ),
          );

  static const List<String> _currencyOrder = [
    'USD',
    'EUR',
    'RUB',
    'CNY',
    'GBP',
    'TRY',
    'AED',
    'KRW',
  ];

  static const Map<String, String> _currencyNames = {
    'USD': 'Доллар США',
    'EUR': 'Евро',
    'RUB': 'Российский рубль',
    'CNY': 'Китайский юань',
    'GBP': 'Фунт стерлингов',
    'TRY': 'Турецкая лира',
    'AED': 'Дирхам ОАЭ',
    'KRW': 'Южнокорейская вона',
  };

  static const Map<String, String> _currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'RUB': '₽',
    'CNY': '¥',
    'GBP': '£',
    'TRY': '₺',
    'AED': 'د.إ',
    'KRW': '₩',
  };

  @override
  Future<List<CurrencyRate>> fetchRates() async {
    try {
      final response = await _dio.get<dynamic>(
        '/providers/nbk/rates',
        queryParameters: {'base': 'KZT', 'quotes': _currencyOrder.join(',')},
      );

      if (response.statusCode != 200) {
        throw const CurrencyRepositoryException(
          'Сервис курсов валют временно недоступен.',
        );
      }

      final data = response.data;

      if (data is! List) {
        throw const CurrencyRepositoryException(
          'Получен неизвестный формат данных.',
        );
      }

      final rates = <CurrencyRate>[];

      for (final item in data) {
        if (item is! Map) {
          continue;
        }

        final map = Map<String, dynamic>.from(item);

        final base = map['base']?.toString().toUpperCase();

        final quote = map['quote']?.toString().toUpperCase();

        final rawRate = map['rate'];

        final rawDate = map['date']?.toString();

        if (base != 'KZT' ||
            quote == null ||
            rawRate is! num ||
            rawRate <= 0 ||
            rawDate == null) {
          continue;
        }

        final date = DateTime.tryParse(rawDate);

        if (date == null) {
          continue;
        }

        // API возвращает:
        //
        // 1 KZT = X USD
        //
        // Пользователю удобнее:
        //
        // 1 USD = X KZT
        //
        // Поэтому инвертируем курс.
        final rateToKzt = 1.0 / rawRate.toDouble();

        rates.add(
          CurrencyRate(
            code: quote,
            name: _currencyNames[quote] ?? quote,
            symbol: _currencySymbols[quote] ?? quote,
            rateToKzt: rateToKzt,
            date: date,
          ),
        );
      }

      rates.sort((a, b) {
        final first = _currencyOrder.indexOf(a.code);

        final second = _currencyOrder.indexOf(b.code);

        return first.compareTo(second);
      });

      return rates;
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;

      if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.sendTimeout) {
        throw const CurrencyRepositoryException(
          'Сервер слишком долго отвечает. Попробуй ещё раз.',
        );
      }

      if (error.type == DioExceptionType.connectionError) {
        throw const CurrencyRepositoryException('Нет подключения к интернету.');
      }

      if (statusCode == 400 || statusCode == 404 || statusCode == 422) {
        throw const CurrencyRepositoryException(
          'Не удалось получить выбранные валюты.',
        );
      }

      throw const CurrencyRepositoryException(
        'Не удалось загрузить курсы валют.',
      );
    } on CurrencyRepositoryException {
      rethrow;
    } catch (_) {
      throw const CurrencyRepositoryException(
        'Произошла ошибка при загрузке курсов.',
      );
    }
  }
}
