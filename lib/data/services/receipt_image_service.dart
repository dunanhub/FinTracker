import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

enum ReceiptImageSource { camera, gallery }

class ReceiptImageService {
  final ImagePicker _picker;

  ReceiptImageService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  Future<String?> pick(ReceiptImageSource source) async {
    final image = await _picker.pickImage(
      source:
          source == ReceiptImageSource.camera
              ? ImageSource.camera
              : ImageSource.gallery,
      imageQuality: 88,
      maxWidth: 2200,
    );

    if (image == null) {
      return null;
    }

    final root = await getApplicationDocumentsDirectory();

    final receiptsDirectory = Directory(
      '${root.path}${Platform.pathSeparator}receipts',
    );

    if (!await receiptsDirectory.exists()) {
      await receiptsDirectory.create(recursive: true);
    }

    final extension = _extensionFromName(image.name);

    final targetPath =
        '${receiptsDirectory.path}${Platform.pathSeparator}'
        'receipt-${DateTime.now().microsecondsSinceEpoch}$extension';

    final copied = await File(image.path).copy(targetPath);

    return copied.path;
  }

  Future<void> delete(String? path) async {
    if (path == null || path.isEmpty) {
      return;
    }

    final file = File(path);
    if (!await file.exists()) return;

    final root = await getApplicationDocumentsDirectory();
    final receiptsDirectory = Directory(
      '${root.path}${Platform.pathSeparator}receipts',
    );
    if (!await receiptsDirectory.exists()) return;
    final managedRoot = await receiptsDirectory.absolute.resolveSymbolicLinks();
    final resolvedFile = await file.absolute.resolveSymbolicLinks();
    if (resolvedFile.startsWith('$managedRoot${Platform.pathSeparator}')) {
      await file.delete();
    }
  }

  Future<bool> existsLocally(String? path) async {
    if (path == null || path.isEmpty) return false;
    final file = File(path);
    if (!await file.exists()) return false;

    final root = await getApplicationDocumentsDirectory();
    final receiptsDirectory = Directory(
      '${root.path}${Platform.pathSeparator}receipts',
    );
    if (!await receiptsDirectory.exists()) return false;
    final managedRoot = await receiptsDirectory.absolute.resolveSymbolicLinks();
    final resolvedFile = await file.absolute.resolveSymbolicLinks();
    return resolvedFile.startsWith('$managedRoot${Platform.pathSeparator}');
  }

  String _extensionFromName(String name) {
    final dot = name.lastIndexOf('.');

    if (dot == -1 || dot == name.length - 1) {
      return '.jpg';
    }

    final extension = name.substring(dot).toLowerCase();

    if (extension.length > 6) {
      return '.jpg';
    }

    return extension;
  }
}
