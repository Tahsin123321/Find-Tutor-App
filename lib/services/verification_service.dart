// lib/services/verification_service.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/verification_request.dart';
import 'storage_service.dart';

/// Error with a message that is safe to show directly to the user.
class VerificationException implements Exception {
  final String message;
  const VerificationException(this.message);

  @override
  String toString() => message;
}

/// Submits and tracks identity-verification requests.
///
/// A request lives at `verification_requests/{uid}` — one per user — and a
/// successful submission also sets `users/{uid}.verificationStatus` to
/// `pending`, which the profile screen already displays live.
class VerificationService {
  VerificationService._();
  static final VerificationService instance = VerificationService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('verification_requests');
  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  /// Live status of the caller's own request. Emits null if none exists yet.
  Stream<VerificationRequest?> watchRequest(String uid) {
    return _requests.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return VerificationRequest.fromMap(doc.id, data);
    });
  }

  /// Uploads [document] and submits (or resubmits) a verification request
  /// for [uid]. Resubmitting only makes sense from `unverified` or
  /// `rejected` — the caller should not offer this action while `pending`
  /// or `approved` (the Firestore rules enforce this either way).
  Future<void> submitRequest({
    required String uid,
    required String username,
    required String role,
    required File document,
    required String fileName,
  }) async {
    if (role != UserRole.student && role != UserRole.tutor) {
      throw const VerificationException('Only students and tutors can request verification.');
    }

    // Keep the previous file's path so it can be cleaned up after the new
    // one is safely recorded, and to fail fast if it can't be read.
    String? previousPath;
    try {
      final existing = await _requests.doc(uid).get();
      previousPath = existing.data()?['documentPath'] as String?;
    } on FirebaseException {
      previousPath = null; // not critical: worst case an old file lingers
    }

    final uploaded = await StorageService.instance.uploadVerificationDocument(
      uid: uid,
      file: document,
      fileName: fileName,
    );

    final request = VerificationRequest(
      uid: uid,
      username: username,
      role: role,
      documentPath: uploaded.storagePath,
      documentName: uploaded.fileName,
      status: VerificationStatus.pending,
    );

    try {
      final batch = _db.batch();
      batch.set(_requests.doc(uid), request.toSubmitMap());
      batch.update(_users.doc(uid), {'verificationStatus': VerificationStatus.pending});
      await batch.commit();
    } on FirebaseException catch (e) {
      // Roll back the just-uploaded file since no request references it.
      await StorageService.instance.deleteByPath(uploaded.storagePath);
      throw VerificationException(_message(e));
    }

    if (previousPath != null &&
        previousPath.isNotEmpty &&
        previousPath != uploaded.storagePath) {
      await StorageService.instance.deleteByPath(previousPath);
    }
  }

  /// Downloads the document for [request] so it can be opened locally.
  /// Delegates to [StorageService]; owner and admins only, per Storage rules.
  Future<File> downloadDocument(VerificationRequest request) {
    return StorageService.instance.downloadDocumentToTemp(request.documentPath);
  }

  String _message(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
        return 'Service unavailable. Please check your connection.';
      default:
        return e.message ?? 'Database error (${e.code}).';
    }
  }
}
