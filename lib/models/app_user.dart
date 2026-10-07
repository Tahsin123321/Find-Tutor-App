// lib/models/app_user.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Role names stored in Firestore (`users/{uid}.role`).
/// These match the strings the app already used with SQLite.
class UserRole {
  UserRole._();

  static const String student = 'Student';
  static const String tutor = 'Tutor';
  static const String admin = 'Admin';
}

/// Verification lifecycle stored in `users/{uid}.verificationStatus`.
class VerificationStatus {
  VerificationStatus._();

  static const String unverified = 'unverified';
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

/// A registered user. The document id in Firestore is the Firebase Auth uid.
class AppUser {
  final String uid;
  final String username;
  final String email;
  final String phone;
  final String role;
  final String area;
  final String photoUrl;
  final String verificationStatus;
  final DateTime? createdAt;

  const AppUser({
    required this.uid,
    required this.username,
    required this.email,
    required this.phone,
    required this.role,
    this.area = '',
    this.photoUrl = '',
    this.verificationStatus = VerificationStatus.unverified,
    this.createdAt,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isTutor => role == UserRole.tutor;
  bool get isStudent => role == UserRole.student;
  bool get isVerified => verificationStatus == VerificationStatus.approved;

  /// Builds a user from a Firestore document, tolerating missing fields.
  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final created = data['createdAt'];
    return AppUser(
      uid: uid,
      username: (data['username'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      role: (data['role'] as String?) ?? UserRole.student,
      area: (data['area'] as String?) ?? '',
      photoUrl: (data['photoUrl'] as String?) ?? '',
      verificationStatus:
      (data['verificationStatus'] as String?) ?? VerificationStatus.unverified,
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }

  /// Map written when the account is first created.
  /// The key set here must match the `create` rule in firestore.rules.
  Map<String, dynamic> toCreateMap() {
    return {
      'username': username,
      'email': email,
      'phone': phone,
      'role': role,
      'area': area,
      'photoUrl': photoUrl,
      'verificationStatus': verificationStatus,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  AppUser copyWith({
    String? username,
    String? phone,
    String? area,
    String? photoUrl,
    String? verificationStatus,
  }) {
    return AppUser(
      uid: uid,
      username: username ?? this.username,
      email: email,
      phone: phone ?? this.phone,
      role: role,
      area: area ?? this.area,
      photoUrl: photoUrl ?? this.photoUrl,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      createdAt: createdAt,
    );
  }
}
