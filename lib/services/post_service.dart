// lib/services/post_service.dart
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as p;

import '../models/tuition_post.dart';
import 'storage_service.dart';

/// Error with a message that is safe to show directly to the user.
class PostException implements Exception {
  final String message;
  const PostException(this.message);

  @override
  String toString() => message;
}

/// Creates and reads tuition posts (student requests and tutor listings)
/// in the `posts` collection.
class PostService {
  PostService._();
  static final PostService instance = PostService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _posts => _db.collection('posts');

  /// Uploads the optional ID document, then creates a pending post.
  /// If the Firestore write fails, the just-uploaded file is removed again.
  /// [fee] only matters for tutor listings; leave it at 0 for student posts.
  Future<void> createPost({
    required String type,
    required String ownerUid,
    required String ownerUsername,
    required String name,
    required String className,
    required String subject,
    String area = '',
    String phone = '',
    String institution = '',
    double fee = 0,
    File? document,
    String? documentName,
  }) async {
    if (type != PostType.student && type != PostType.tutor) {
      throw const PostException('Invalid post type.');
    }
    if (name.trim().isEmpty) throw const PostException('Please enter a name.');
    if (className.trim().isEmpty) throw const PostException('Please enter a class.');
    if (subject.trim().isEmpty) throw const PostException('Please enter a subject.');
    if (fee < 0) throw const PostException('Fee cannot be negative.');

    String documentPath = '';
    String storedDocumentName = '';
    if (document != null) {
      final uploaded = await StorageService.instance.uploadPostDocument(
        uid: ownerUid,
        file: document,
        fileName: documentName ?? p.basename(document.path),
      );
      documentPath = uploaded.storagePath;
      storedDocumentName = uploaded.fileName;
    }

    final post = TuitionPost(
      id: '', // assigned by Firestore
      type: type,
      ownerUid: ownerUid,
      ownerUsername: ownerUsername,
      name: name.trim(),
      className: className.trim(),
      subject: subject.trim(),
      area: area.trim(),
      phone: phone.trim(),
      institution: institution.trim(),
      fee: fee,
      documentPath: documentPath,
      documentName: storedDocumentName,
    );

    try {
      await _posts.add(post.toCreateMap());
    } on FirebaseException catch (e) {
      if (documentPath.isNotEmpty) {
        await StorageService.instance.deleteByPath(documentPath);
      }
      throw PostException(_message(e));
    }
  }

  /// Approved posts of [type], newest first. Used by the Student/Tutor
  /// Dashboards, which then apply free-text and structured search filters
  /// (class/subject/area/fee) on this live snapshot. Requires a Firestore
  /// composite index the first time it runs — Firestore's error message
  /// includes a direct link to create it.
  Stream<List<TuitionPost>> watchApprovedPosts(String type) {
    return _posts
        .where('type', isEqualTo: type)
        .where('status', isEqualTo: PostStatus.approved)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => TuitionPost.fromMap(d.id, d.data())).toList());
  }

  /// All posts owned by [uid] regardless of status, newest first.
  /// Not shown anywhere yet — kept ready for a future "My Posts" screen.
  Stream<List<TuitionPost>> watchMyPosts(String uid) {
    return _posts
        .where('ownerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
        snap.docs.map((d) => TuitionPost.fromMap(d.id, d.data())).toList());
  }

  /// Deletes a post the caller owns while it is still pending, and removes
  /// its attached document. Approved/rejected posts require an admin — the
  /// Firestore rules enforce this either way.
  Future<void> deletePost(String postId, {String documentPath = ''}) async {
    try {
      await _posts.doc(postId).delete();
    } on FirebaseException catch (e) {
      throw PostException(_message(e));
    }
    if (documentPath.isNotEmpty) {
      await StorageService.instance.deleteByPath(documentPath);
    }
  }

  String _message(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to do that.';
      case 'unavailable':
        return 'Service unavailable. Please check your connection.';
      case 'failed-precondition':
        return 'This search needs a one-time index setup. Check the debug console for a link.';
      default:
        return e.message ?? 'Database error (${e.code}).';
    }
  }
}
