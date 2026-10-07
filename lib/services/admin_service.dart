// lib/services/admin_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/tuition_post.dart';
import '../models/verification_request.dart';
import 'post_service.dart';

/// Error with a message that is safe to show directly to the user.
class AdminException implements Exception {
  final String message;
  const AdminException(this.message);

  @override
  String toString() => message;
}

/// Everything the Admin Portal needs: browsing users, reviewing
/// verification requests, and reviewing tuition posts.
///
/// The Firestore security rules already restrict every read and write here
/// to signed-in admins (see firestore.rules) — this class does not
/// re-check the caller's role, Firestore does.
class AdminService {
  AdminService._();
  static final AdminService instance = AdminService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _requests =>
      _db.collection('verification_requests');
  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');

  // ---------------------------------------------------------------------------
  // Users
  // ---------------------------------------------------------------------------

  /// Every registered user, alphabetical by username.
  Stream<List<AppUser>> watchAllUsers() {
    return _users.orderBy('username').snapshots().map(
          (snap) => snap.docs.map((d) => AppUser.fromMap(d.id, d.data())).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Verification requests
  // ---------------------------------------------------------------------------

  /// Pending identity-verification requests for [role] ('Student' or
  /// 'Tutor'), newest first. Sorted in memory so no composite index is
  /// needed for what is normally a short admin queue.
  Stream<List<VerificationRequest>> watchPendingVerificationRequests(String role) {
    return _requests
        .where('role', isEqualTo: role)
        .where('status', isEqualTo: VerificationStatus.pending)
        .snapshots()
        .map((snap) {
      final requests =
      snap.docs.map((d) => VerificationRequest.fromMap(d.id, d.data())).toList();
      requests.sort((a, b) => (b.submittedAt ?? DateTime(0))
          .compareTo(a.submittedAt ?? DateTime(0)));
      return requests;
    });
  }

  /// Approves or rejects a verification request, keeping the request and
  /// the user's profile status in sync in a single batch.
  Future<void> reviewVerificationRequest({
    required String uid,
    required bool approve,
    String rejectionReason = '',
  }) async {
    final status = approve ? VerificationStatus.approved : VerificationStatus.rejected;
    try {
      final batch = _db.batch();
      batch.update(_requests.doc(uid), {
        'status': status,
        'rejectionReason': approve ? '' : rejectionReason.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
      });
      batch.update(_users.doc(uid), {'verificationStatus': status});
      await batch.commit();
    } on FirebaseException catch (e) {
      throw AdminException(_message(e));
    }
  }

  // ---------------------------------------------------------------------------
  // Tuition posts
  // ---------------------------------------------------------------------------

  /// Pending posts of [type] ('Student' or 'Tutor'), newest first.
  Stream<List<TuitionPost>> watchPendingPosts(String type) {
    return _posts
        .where('type', isEqualTo: type)
        .where('status', isEqualTo: PostStatus.pending)
        .snapshots()
        .map((snap) {
      final posts = snap.docs.map((d) => TuitionPost.fromMap(d.id, d.data())).toList();
      posts.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return posts;
    });
  }

  /// Approves a post so it appears in the public dashboards.
  Future<void> approvePost(String postId) async {
    try {
      await _posts.doc(postId).update({
        'status': PostStatus.approved,
        'rejectionReason': '',
        'reviewedAt': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      throw AdminException(_message(e));
    }
  }

  /// Permanently removes a post and its attached document.
  Future<void> deletePost(TuitionPost post) {
    return PostService.instance.deletePost(post.id, documentPath: post.documentPath);
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
