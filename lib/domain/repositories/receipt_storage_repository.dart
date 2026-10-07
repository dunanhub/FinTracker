abstract class ReceiptStorageRepository {
  Future<String> upload({
    required String uid,
    required String transactionId,
    required String localPath,
  });

  Future<String> download({
    required String uid,
    required String transactionId,
    required String storagePath,
  });

  Future<void> delete({required String uid, required String storagePath});
}
