import 'dart:io';

import 'package:fin_tracker/data/repositories/firebase_receipt_storage_repository.dart';
import 'package:fin_tracker/data/repositories/hive_finance_repository.dart';
import 'package:fin_tracker/domain/entities/finance_transaction.dart';
import 'package:fin_tracker/presentation/controllers/finance_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  test('старый Hive чек загружается без receiptStoragePath', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fintracker-receipt-',
    );
    Hive.init(directory.path);
    try {
      final box = await Hive.openBox<dynamic>(
        'fintracker_finance_receipt_legacy_test',
      );
      await box.put('transactions', [
        {
          'id': 'legacy-1',
          'type': 'expense',
          'amount': 50.0,
          'accountId': 'cash',
          'title': 'Старый чек',
          'date': DateTime(2026, 1, 1).toIso8601String(),
          'receiptPath': '/old/local/receipt.jpg',
        },
      ]);
      await box.put('accounts_v2', <dynamic>[]);

      final repository = HiveFinanceRepository();
      await repository.init(scope: 'receipt_legacy_test');
      final transaction = (await repository.load())!.transactions.single;
      expect(transaction.receiptPath, '/old/local/receipt.jpg');
      expect(transaction.receiptStoragePath, isNull);
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });

  test('Hive сохраняет локальный и облачный пути независимо', () async {
    final directory = await Directory.systemTemp.createTemp(
      'fintracker-receipt-',
    );
    Hive.init(directory.path);
    try {
      final repository = HiveFinanceRepository();
      await repository.init(scope: 'receipt_roundtrip_test');
      await repository.save(
        transactions: [
          FinanceTransaction(
            id: 'transaction-1',
            type: FinanceTransactionType.expense,
            amount: 10,
            accountId: 'cash',
            title: 'Чек',
            date: DateTime(2026, 1, 1),
            receiptPath: '/local/receipt.jpg',
            receiptStoragePath:
                'users/user1/receipts/transaction-1/receipt-123.jpg',
          ),
        ],
        accounts: const [],
      );

      final transaction = (await repository.load())!.transactions.single;
      expect(transaction.receiptPath, '/local/receipt.jpg');
      expect(
        transaction.receiptStoragePath,
        'users/user1/receipts/transaction-1/receipt-123.jpg',
      );
    } finally {
      await Hive.close();
      await directory.delete(recursive: true);
    }
  });

  test(
    'замена и удаление локального чека сбрасывают облачную ссылку',
    () async {
      final finance = FinanceController();
      final id = await finance.addTransaction(
        type: FinanceTransactionType.expense,
        amount: 10,
        accountId: 'cash',
        title: 'Чек',
        date: DateTime(2026, 1, 1),
        receiptPath: '/local/old.jpg',
      );
      await finance.setTransactionReceiptStoragePath(
        transactionId: id,
        expectedLocalPath: '/local/old.jpg',
        storagePath: 'users/user1/receipts/$id/receipt-123.jpg',
      );

      expect(
        await finance.setTransactionReceiptStoragePath(
          transactionId: id,
          expectedLocalPath: '/local/stale.jpg',
          storagePath: 'users/user1/receipts/$id/receipt-999.jpg',
        ),
        isFalse,
      );

      await finance.setTransactionReceipt(
        transactionId: id,
        receiptPath: '/local/new.jpg',
      );
      expect(finance.transactionById(id)!.receiptPath, '/local/new.jpg');
      expect(finance.transactionById(id)!.receiptStoragePath, isNull);

      await finance.setTransactionReceiptStoragePath(
        transactionId: id,
        expectedLocalPath: '/local/new.jpg',
        storagePath: 'users/user1/receipts/$id/receipt-456.jpg',
      );
      await finance.setTransactionReceipt(transactionId: id);
      expect(finance.transactionById(id)!.receiptPath, isNull);
      expect(finance.transactionById(id)!.receiptStoragePath, isNull);
    },
  );

  test('Storage path не допускает чужого пользователя или транзакцию', () {
    expect(
      FirebaseReceiptStorageRepository.ownsPath(
        'user1',
        'users/user1/receipts/transaction-1/receipt-123.jpg',
      ),
      isTrue,
    );
    expect(
      FirebaseReceiptStorageRepository.ownsPath(
        'user2',
        'users/user1/receipts/transaction-1/receipt-123.jpg',
      ),
      isFalse,
    );
    expect(
      FirebaseReceiptStorageRepository.ownsPath(
        'user1',
        'users/user1/receipts/../receipt-123.jpg',
      ),
      isFalse,
    );
  });
}
