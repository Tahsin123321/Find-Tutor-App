// lib/models/tuition_post.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Which side of the marketplace a post belongs to.
///   student -> a student's request, shown in the Student Dashboard
///   tutor   -> a tutor's listing, shown in the Tutor Dashboard
class PostType {
  PostType._();
  static const String student = 'Student';
  static const String tutor = 'Tutor';
}

/// Lifecycle of a post, mirroring the admin approve/delete flow.
class PostStatus {
  PostStatus._();
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// A single tuition listing, either a student looking for a tutor or a
/// tutor offering lessons. Stored in the `posts` collection.
class TuitionPost {
  final String id;
  final String type;
  final String ownerUid;
  final String ownerUsername;
  final String name;
  final String className;
  final String subject;
  final String area;
  final String phone;
  final String institution;
  final double fee;
  final String documentPath;
  final String documentName;
  final String status;
  final String rejectionReason;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const TuitionPost({
    required this.id,
    required this.type,
    required this.ownerUid,
    required this.ownerUsername,
    required this.name,
    required this.className,
    required this.subject,
    this.area = '',
    this.phone = '',
    this.institution = '',
    this.fee = 0,
    this.documentPath = '',
    this.documentName = '',
    this.status = PostStatus.pending,
    this.rejectionReason = '',
    this.createdAt,
    this.reviewedAt,
  });

  bool get isPending => status == PostStatus.pending;
  bool get isApproved => status == PostStatus.approved;
  bool get isRejected => status == PostStatus.rejected;

  /// Single line combining subject and area, used by the dashboard cards.
  String get displayDetails =>
      area.isNotEmpty ? '$subject ($area)' : subject;

  /// Only meaningful for tutor listings; student posts leave fee at 0.
  String get feeDisplay => fee > 0 ? 'Fee: ৳${fee.toStringAsFixed(0)}' : 'Fee: N/A';

  factory TuitionPost.fromMap(String id, Map<String, dynamic> data) {
    final created = data['createdAt'];
    final reviewed = data['reviewedAt'];
    final feeValue = data['fee'];
    return TuitionPost(
      id: id,
      type: (data['type'] as String?) ?? PostType.student,
      ownerUid: (data['ownerUid'] as String?) ?? '',
      ownerUsername: (data['ownerUsername'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      className: (data['className'] as String?) ?? '',
      subject: (data['subject'] as String?) ?? '',
      area: (data['area'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      institution: (data['institution'] as String?) ?? '',
      fee: feeValue is num ? feeValue.toDouble() : 0,
      documentPath: (data['documentPath'] as String?) ?? '',
      documentName: (data['documentName'] as String?) ?? '',
      status: (data['status'] as String?) ?? PostStatus.pending,
      rejectionReason: (data['rejectionReason'] as String?) ?? '',
      createdAt: created is Timestamp ? created.toDate() : null,
      reviewedAt: reviewed is Timestamp ? reviewed.toDate() : null,
    );
  }

  /// Map written when a post is first created. Always starts pending.
  Map<String, dynamic> toCreateMap() {
    return {
      'type': type,
      'ownerUid': ownerUid,
      'ownerUsername': ownerUsername,
      'name': name,
      'className': className,
      'subject': subject,
      'area': area,
      'phone': phone,
      'institution': institution,
      'fee': fee,
      'documentPath': documentPath,
      'documentName': documentName,
      'status': PostStatus.pending,
      'rejectionReason': '',
      'createdAt': FieldValue.serverTimestamp(),
    };
  }
}
