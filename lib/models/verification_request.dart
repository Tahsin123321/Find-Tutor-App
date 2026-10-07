// lib/models/verification_request.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import 'app_user.dart';

/// One identity-verification request. The document id in
/// `verification_requests` is always the requester's uid, so each user has
/// at most one request: submitting again overwrites the previous one.
class VerificationRequest {
  final String uid;
  final String username;
  final String role;
  final String documentPath;
  final String documentName;
  final String status;
  final String rejectionReason;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;

  const VerificationRequest({
    required this.uid,
    required this.username,
    required this.role,
    required this.documentPath,
    required this.documentName,
    required this.status,
    this.rejectionReason = '',
    this.submittedAt,
    this.reviewedAt,
  });

  bool get isPending => status == VerificationStatus.pending;
  bool get isApproved => status == VerificationStatus.approved;
  bool get isRejected => status == VerificationStatus.rejected;

  factory VerificationRequest.fromMap(String uid, Map<String, dynamic> data) {
    final submitted = data['submittedAt'];
    final reviewed = data['reviewedAt'];
    return VerificationRequest(
      uid: uid,
      username: (data['username'] as String?) ?? '',
      role: (data['role'] as String?) ?? UserRole.student,
      documentPath: (data['documentPath'] as String?) ?? '',
      documentName: (data['documentName'] as String?) ?? '',
      status: (data['status'] as String?) ?? VerificationStatus.pending,
      rejectionReason: (data['rejectionReason'] as String?) ?? '',
      submittedAt: submitted is Timestamp ? submitted.toDate() : null,
      reviewedAt: reviewed is Timestamp ? reviewed.toDate() : null,
    );
  }

  /// Map written when a user submits or resubmits their request.
  Map<String, dynamic> toSubmitMap() {
    return {
      'uid': uid,
      'username': username,
      'role': role,
      'documentPath': documentPath,
      'documentName': documentName,
      'status': VerificationStatus.pending,
      'rejectionReason': '',
      'submittedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
    };
  }
}
