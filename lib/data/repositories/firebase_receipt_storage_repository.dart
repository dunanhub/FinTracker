import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/receipt_storage_repository.dart';

class FirebaseReceiptStorageRepository implements ReceiptStorageRepository {
  final FirebaseStorage _storage;

  FirebaseReceiptStorageRepository({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  static final RegExp _safeSegment = RegExp(r'^[a-zA-Z0-9_-]+$');
  static final RegExp _receiptName = RegExp(
    r'^receipt-[0-9]+\.(jpg|jpeg|png|webp|heic|heif|gif|bmp|avif)$',
  );

  static bool ownsPath(String uid, String storagePath) {
    final parts = storagePath.split('/');
    return _safeSegment.hasMatch(uid) &&
        parts.length == 5 &&
        parts[0] == 'users' &&
        parts[1] == uid &&
        parts[2] == 'receipts' &&
        _safeSegment.hasMatch(parts[3]) &&
        _receiptName.hasMatch(parts[4]);
  }

  @override
  Future<String> upload({
    required String uid,
    required String transactionId,
    required String localPath,
  }) async {
    if (!_safeSegment.hasMatch(uid) || !_safeSegment.hasMatch(transactionId)) {
      throw ArgumentError('Invalid receipt owner or transaction ID.');
    }

    final file = File(localPath);
    if (!await file.exists()) {
      throw FileSystemException('Receipt file not found', localPath);
    }

    final extension = _extension(localPath);
    final version = DateTime.now().microsecondsSinceEpoch;
    final path =
        'users/$uid/receipts/$transactionId/receipt-$version.$extension';
    await _storage
        .ref(path)
        .putFile(file, SettableMetadata(contentType: _contentType(extension)));
    return path;
  }

  @override
  Future<String> download({
    required String uid,
    required String transactionId,
    required String storagePath,
  }) async {
    if (!ownsPath(uid, storagePath) ||
        storagePath.split('/')[3] != transactionId) {
      throw ArgumentError('Receipt does not belong to this transaction.');
    }

    final root = await getApplicationDocumentsDirectory();
    final directory = Directory(
      '${root.path}${Platform.pathSeparator}receipts'
      '${Platform.pathSeparator}cloud${Platform.pathSeparator}$uid'
      '${Platform.pathSeparator}$transactionId',
    );
    await directory.create(recursive: true);

    final file = File(
      '${directory.path}${Platform.pathSeparator}${storagePath.split('/').last}',
    );
    if (await file.exists()) {
      return file.path;
    }

    final temporary = File('${file.path}.part');
    try {
      await _storage.ref(storagePath).writeToFile(temporary);
      await temporary.rename(file.path);
      return file.path;
    } catch (_) {
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }

  @override
  Future<void> delete({
    required String uid,
    required String storagePath,
  }) async {
    if (!ownsPath(uid, storagePath)) {
      throw ArgumentError('Receipt does not belong to this user.');
    }

    try {
      await _storage.ref(storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        rethrow;
      }
    }
  }

  static String _extension(String localPath) {
    final name = localPath.split(RegExp(r'[/\\]')).last.toLowerCase();
    final dot = name.lastIndexOf('.');
    final extension = dot == -1 ? '' : name.substring(dot + 1);
    return switch (extension) {
      'jpg' ||
      'jpeg' ||
      'png' ||
      'webp' ||
      'heic' ||
      'heif' ||
      'gif' ||
      'bmp' ||
      'avif' => extension,
      _ => throw ArgumentError('Unsupported receipt image type.'),
    };
  }

  static String _contentType(String extension) => switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'gif' => 'image/gif',
    'bmp' => 'image/bmp',
    'avif' => 'image/avif',
    _ => throw ArgumentError('Unsupported receipt image type.'),
  };
}
