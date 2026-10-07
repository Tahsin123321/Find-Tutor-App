// lib/services/storage_service.dart
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Error with a message that is safe to show directly to the user.
class StorageException implements Exception {
  final String message;
  const StorageException(this.message);

  @override
  String toString() => message;
}

/// Reference to a stored document. Only the storage path is kept in
/// Firestore (never a public URL), so access stays under the Storage
/// security rules: the owner and admins only.
class UploadedDocument {
  final String storagePath;
  final String fileName;

  const UploadedDocument({required this.storagePath, required this.fileName});
}

/// All Firebase Storage access lives here.
///
/// Layout:
///   profile_pictures/{uid}/avatar_<timestamp>.<ext>  readable by any signed-in user
///   verification_docs/{uid}/<timestamp>_<name>       readable by owner + admins
///   post_documents/{uid}/<timestamp>_<name>          readable by owner + admins
class StorageService {
  StorageService._();
  static final StorageService instance = StorageService._();

  final FirebaseStorage _storage = FirebaseStorage.instance;

  static const int maxProfileImageBytes = 5 * 1024 * 1024;
  static const int maxDocumentBytes = 10 * 1024 * 1024;

  static const Map<String, String> _imageTypes = {
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static const Map<String, String> _documentTypes = {
    ..._imageTypes,
    'pdf': 'application/pdf',
  };

  // ---------------------------------------------------------------------------
  // Profile pictures
  // ---------------------------------------------------------------------------

  /// Uploads a new profile picture and returns its download URL.
  /// A unique file name is used each time so the app never shows a cached
  /// copy of the previous picture.
  Future<String> uploadProfilePicture({
    required String uid,
    required File file,
    void Function(double progress)? onProgress,
  }) async {
    await _checkSize(file, maxProfileImageBytes, '5 MB');

    // The file already comes from the image picker, so fall back to JPEG
    // if the extension is unusual.
    var extension = _extensionOf(file.path);
    if (!_imageTypes.containsKey(extension)) extension = 'jpg';
    final contentType = _imageTypes[extension]!;

    final ref = _storage.ref(
      'profile_pictures/$uid/avatar_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );

    try {
      await _upload(ref, file, contentType, onProgress);
      return await ref.getDownloadURL();
    } on FirebaseException catch (e) {
      throw StorageException(_message(e));
    }
  }

  /// Best-effort delete of a file by its download URL (e.g. an old avatar).
  /// Never throws: a leftover file is harmless, a failed save is not.
  Future<void> deleteByUrl(String url) async {
    if (url.isEmpty) return;
    try {
      await _storage.refFromURL(url).delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Verification documents (ID card, certificates for identity verification)
  // ---------------------------------------------------------------------------

  /// Uploads an ID/document image or PDF for identity verification.
  Future<UploadedDocument> uploadVerificationDocument({
    required String uid,
    required File file,
    String? fileName,
    void Function(double progress)? onProgress,
  }) {
    return _uploadDocument(
      pathPrefix: 'verification_docs',
      uid: uid,
      file: file,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  // ---------------------------------------------------------------------------
  // Post documents (ID card attached to a tuition post)
  // ---------------------------------------------------------------------------

  /// Uploads an ID/document image or PDF attached to a tuition post.
  Future<UploadedDocument> uploadPostDocument({
    required String uid,
    required File file,
    String? fileName,
    void Function(double progress)? onProgress,
  }) {
    return _uploadDocument(
      pathPrefix: 'post_documents',
      uid: uid,
      file: file,
      fileName: fileName,
      onProgress: onProgress,
    );
  }

  // ---------------------------------------------------------------------------
  // Shared document upload/download/delete
  // ---------------------------------------------------------------------------

  Future<UploadedDocument> _uploadDocument({
    required String pathPrefix,
    required String uid,
    required File file,
    String? fileName,
    void Function(double progress)? onProgress,
  }) async {
    final originalName = fileName ?? p.basename(file.path);
    final contentType = _documentTypes[_extensionOf(originalName)];
    if (contentType == null) {
      throw const StorageException('Only PDF, JPG, PNG or WEBP files are allowed.');
    }
    await _checkSize(file, maxDocumentBytes, '10 MB');

    final safeName = originalName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$pathPrefix/$uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = _storage.ref(path);

    try {
      await _upload(ref, file, contentType, onProgress);
      return UploadedDocument(storagePath: path, fileName: originalName);
    } on FirebaseException catch (e) {
      throw StorageException(_message(e));
    }
  }

  /// Downloads a document to a temporary file so it can be opened with
  /// OpenFilex (works for both PDFs and images). Storage rules decide who
  /// may do this: the owner and admins.
  Future<File> downloadDocumentToTemp(String storagePath) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, p.basename(storagePath)));
      await _storage.ref(storagePath).writeToFile(file);
      return file;
    } on FirebaseException catch (e) {
      throw StorageException(_message(e));
    }
  }

  /// Best-effort delete of a stored document by its path.
  Future<void> deleteByPath(String storagePath) async {
    if (storagePath.isEmpty) return;
    try {
      await _storage.ref(storagePath).delete();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _upload(
      Reference ref,
      File file,
      String contentType,
      void Function(double progress)? onProgress,
      ) async {
    final task = ref.putFile(file, SettableMetadata(contentType: contentType));
    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });
    try {
      await task;
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _checkSize(File file, int maxBytes, String label) async {
    if (!await file.exists()) {
      throw const StorageException('The selected file could not be found.');
    }
    if (await file.length() > maxBytes) {
      throw StorageException('File is too large. Maximum size is $label.');
    }
  }

  String _extensionOf(String path) {
    final ext = p.extension(path).toLowerCase();
    return ext.startsWith('.') ? ext.substring(1) : ext;
  }

  String _message(FirebaseException e) {
    switch (e.code) {
      case 'unauthorized':
      case 'permission-denied':
        return 'You do not have permission to do that. Check the Storage rules.';
      case 'canceled':
        return 'Upload cancelled.';
      case 'object-not-found':
        return 'File not found.';
      case 'retry-limit-exceeded':
      case 'network-request-failed':
        return 'Network problem. Please check your connection and try again.';
      case 'quota-exceeded':
        return 'Storage quota exceeded.';
      default:
        return e.message ?? 'Storage error (${e.code}).';
    }
  }
}
