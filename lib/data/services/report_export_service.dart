import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

class ReportExportSummary {
  final String periodLabel;

  final int operationCount;

  final double income;
  final double expense;
  final double net;

  final double debtIncome;
  final double debtExpense;

  final double transfers;

  const ReportExportSummary({
    required this.periodLabel,
    required this.operationCount,
    required this.income,
    required this.expense,
    required this.net,
    required this.debtIncome,
    required this.debtExpense,
    required this.transfers,
  });
}

class ReportExportRow {
  final DateTime date;

  final String type;
  final String title;
  final String category;

  final String account;
  final String destinationAccount;

  final String person;
  final String description;

  final double amount;

  const ReportExportRow({
    required this.date,
    required this.type,
    required this.title,
    required this.category,
    required this.account,
    required this.destinationAccount,
    required this.person,
    required this.description,
    required this.amount,
  });
}

class ReportExportService {
  ReportExportService._();

  static Future<void> shareCsv({
    required ReportExportSummary summary,
    required List<ReportExportRow> rows,
    required String fileName,
  }) async {
    final buffer = StringBuffer();

    buffer.writeln(_csvRow(['FinTracker', 'Финансовый отчёт']));

    buffer.writeln(_csvRow(['Период', summary.periodLabel]));

    buffer.writeln(
      _csvRow(['Количество операций', summary.operationCount.toString()]),
    );

    buffer.writeln(_csvRow(['Доходы', summary.income.toStringAsFixed(2)]));

    buffer.writeln(_csvRow(['Расходы', summary.expense.toStringAsFixed(2)]));

    buffer.writeln(
      _csvRow(['Чистый результат', summary.net.toStringAsFixed(2)]),
    );

    buffer.writeln(
      _csvRow(['Возврат долгов', summary.debtIncome.toStringAsFixed(2)]),
    );

    buffer.writeln(
      _csvRow(['Выплата долгов', summary.debtExpense.toStringAsFixed(2)]),
    );

    buffer.writeln(_csvRow(['Переводы', summary.transfers.toStringAsFixed(2)]));

    buffer.writeln();

    buffer.writeln(
      _csvRow([
        'Дата',
        'Тип',
        'Название',
        'Категория',
        'Счёт',
        'Счёт назначения',
        'Человек',
        'Комментарий',
        'Сумма',
      ]),
    );

    for (final row in rows) {
      buffer.writeln(
        _csvRow([
          _dateTimeText(row.date),
          row.type,
          row.title,
          row.category,
          row.account,
          row.destinationAccount,
          row.person,
          row.description,
          row.amount.toStringAsFixed(2),
        ]),
      );
    }

    final csvBytes = Uint8List.fromList([
      // UTF-8 BOM — чтобы Excel корректно
      // открывал русский текст.
      0xEF,
      0xBB,
      0xBF,
      ...utf8.encode(buffer.toString()),
    ]);

    await _shareBytes(
      bytes: csvBytes,
      mimeType: 'text/csv;charset=utf-8',
      fileName: '$fileName.csv',
    );
  }

  static Future<void> shareExcel({
    required ReportExportSummary summary,
    required List<ReportExportRow> rows,
    required String fileName,
  }) async {
    final excel = Excel.createExcel();

    final defaultSheetName = excel.getDefaultSheet() ?? 'Sheet1';

    final sheet = excel[defaultSheetName];

    sheet.appendRow([TextCellValue('FinTracker — Финансовый отчёт')]);

    sheet.appendRow([
      TextCellValue('Период'),
      TextCellValue(summary.periodLabel),
    ]);

    sheet.appendRow([
      TextCellValue('Количество операций'),
      IntCellValue(summary.operationCount),
    ]);

    sheet.appendRow([TextCellValue('Доходы'), DoubleCellValue(summary.income)]);

    sheet.appendRow([
      TextCellValue('Расходы'),
      DoubleCellValue(summary.expense),
    ]);

    sheet.appendRow([
      TextCellValue('Чистый результат'),
      DoubleCellValue(summary.net),
    ]);

    sheet.appendRow([
      TextCellValue('Возврат долгов'),
      DoubleCellValue(summary.debtIncome),
    ]);

    sheet.appendRow([
      TextCellValue('Выплата долгов'),
      DoubleCellValue(summary.debtExpense),
    ]);

    sheet.appendRow([
      TextCellValue('Переводы'),
      DoubleCellValue(summary.transfers),
    ]);

    sheet.appendRow([]);

    sheet.appendRow([
      TextCellValue('Дата'),
      TextCellValue('Тип'),
      TextCellValue('Название'),
      TextCellValue('Категория'),
      TextCellValue('Счёт'),
      TextCellValue('Счёт назначения'),
      TextCellValue('Человек'),
      TextCellValue('Комментарий'),
      TextCellValue('Сумма'),
    ]);

    for (final row in rows) {
      sheet.appendRow([
        TextCellValue(_dateTimeText(row.date)),
        TextCellValue(row.type),
        TextCellValue(row.title),
        TextCellValue(row.category),
        TextCellValue(row.account),
        TextCellValue(row.destinationAccount),
        TextCellValue(row.person),
        TextCellValue(row.description),
        DoubleCellValue(row.amount),
      ]);
    }

    final saved = excel.save();

    if (saved == null) {
      throw StateError('Не удалось сформировать Excel-файл.');
    }

    await _shareBytes(
      bytes: Uint8List.fromList(saved),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      fileName: '$fileName.xlsx',
    );
  }

  static Future<void> sharePdf({
    required ReportExportSummary summary,
    required List<ReportExportRow> rows,
    required String fileName,
  }) async {
    final regular = await PdfGoogleFonts.openSansRegular();

    final bold = await PdfGoogleFonts.openSansBold();

    final theme = pw.ThemeData.withFont(base: regular, bold: bold);

    final document = pw.Document(
      theme: theme,
      title: 'FinTracker — Финансовый отчёт',
      author: 'FinTracker',
      creator: 'FinTracker',
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        maxPages: 100,
        header: (context) {
          return pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            margin: const pw.EdgeInsets.only(bottom: 12),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300),
              ),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'FinTracker',
                  style: pw.TextStyle(font: bold, fontSize: 14),
                ),
                pw.Text(
                  'Финансовый отчёт',
                  style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          );
        },
        footer: (context) {
          return pw.Container(
            margin: const pw.EdgeInsets.only(top: 12),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  summary.periodLabel,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Text(
                  'Страница '
                  '${context.pageNumber} / '
                  '${context.pagesCount}',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          );
        },
        build: (context) {
          return [
            pw.Text(
              'Финансовый отчёт',
              style: pw.TextStyle(font: bold, fontSize: 24),
            ),

            pw.SizedBox(height: 5),

            pw.Text(
              summary.periodLabel,
              style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
            ),

            pw.SizedBox(height: 22),

            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _pdfMetric(
                  title: 'Доходы',
                  value: '${_money(summary.income)} ₸',
                  bold: bold,
                ),
                _pdfMetric(
                  title: 'Расходы',
                  value: '${_money(summary.expense)} ₸',
                  bold: bold,
                ),
                _pdfMetric(
                  title: 'Чистый результат',
                  value: '${_money(summary.net)} ₸',
                  bold: bold,
                ),
                _pdfMetric(
                  title: 'Операции',
                  value: summary.operationCount.toString(),
                  bold: bold,
                ),
              ],
            ),

            if (summary.debtIncome > 0 || summary.debtExpense > 0) ...[
              pw.SizedBox(height: 18),
              pw.Text('Долги', style: pw.TextStyle(font: bold, fontSize: 13)),
              pw.SizedBox(height: 5),
              pw.Text(
                'Мне вернули: '
                '${_money(summary.debtIncome)} ₸   '
                '•   Я выплатил: '
                '${_money(summary.debtExpense)} ₸',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],

            if (summary.transfers > 0) ...[
              pw.SizedBox(height: 7),
              pw.Text(
                'Переводы между счетами: '
                '${_money(summary.transfers)} ₸',
                style: const pw.TextStyle(fontSize: 9),
              ),
            ],

            pw.SizedBox(height: 24),

            pw.Text('Операции', style: pw.TextStyle(font: bold, fontSize: 15)),

            pw.SizedBox(height: 10),

            if (rows.isEmpty)
              pw.Text('За выбранный период операций нет.')
            else
              pw.TableHelper.fromTextArray(
                headers: ['Дата', 'Тип', 'Описание', 'Счёт', 'Сумма'],
                data:
                    rows
                        .map(
                          (row) => [
                            _dateText(row.date),
                            row.type,
                            row.title,
                            row.destinationAccount.isEmpty
                                ? row.account
                                : '${row.account}\n→ ${row.destinationAccount}',
                            '${_money(row.amount)} ₸',
                          ],
                        )
                        .toList(),
                headerStyle: pw.TextStyle(font: bold, fontSize: 8),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.grey200,
                ),
                cellPadding: const pw.EdgeInsets.all(5),
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FlexColumnWidth(1.2),
                  1: const pw.FlexColumnWidth(1.3),
                  2: const pw.FlexColumnWidth(2.2),
                  3: const pw.FlexColumnWidth(1.8),
                  4: const pw.FlexColumnWidth(1.3),
                },
              ),
          ];
        },
      ),
    );

    final bytes = await document.save();

    await _shareBytes(
      bytes: bytes,
      mimeType: 'application/pdf',
      fileName: '$fileName.pdf',
    );
  }

  static pw.Widget _pdfMetric({
    required String title,
    required String value,
    required pw.Font bold,
  }) {
    return pw.Container(
      width: 120,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(7)),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 4),
          pw.Text(value, style: pw.TextStyle(font: bold, fontSize: 11)),
        ],
      ),
    );
  }

  static Future<void> _shareBytes({
    required Uint8List bytes,
    required String mimeType,
    required String fileName,
  }) async {
    final file = XFile.fromData(bytes, mimeType: mimeType);

    await SharePlus.instance.share(
      ShareParams(
        files: [file],
        fileNameOverrides: [fileName],
        text: 'Финансовый отчёт FinTracker',
        subject: 'FinTracker — отчёт',
      ),
    );
  }

  static String _csvRow(List<String> values) {
    return values.map(_escapeCsv).join(';');
  }

  static String _escapeCsv(String value) {
    var result = value;

    if (result.contains('"')) {
      result = result.replaceAll('"', '""');
    }

    if (result.contains(';') || result.contains('"') || result.contains('\n')) {
      return '"$result"';
    }

    return result;
  }

  static String _dateText(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  static String _dateTimeText(DateTime date) {
    return '${_dateText(date)} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  static String _money(double value) {
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
}
