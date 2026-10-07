// lib/services/user_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../utils/validators.dart';

/// Error with a message that is safe to show directly to the user.
class ProfileException implements Exception {
  final String message;
  const ProfileException(this.message);

  @override
  String toString() => message;
}

/// Reads and edits `users/{uid}` profile documents.
class UserService {
  UserService._();
  static final UserService instance = UserService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  /// Live profile updates (e.g. verification status changed by an admin).
  /// Emits null if the profile document does not exist.
  Stream<AppUser?> watchUser(String uid) {
    return _users.doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return AppUser.fromMap(doc.id, data);
    });
  }

  /// Saves username, phone and area.
  ///
  /// Everything happens in one transaction so a username can never be held
  /// by two accounts: the new name is reserved, the old reservation released
  /// and the profile updated together, or not at all.
  Future<void> updateProfile({
    required AppUser current,
    required String username,
    required String phone,
    required String area,
  }) async {
    final usernameError = Validators.username(username);
    if (usernameError != null) throw ProfileException(usernameError);
    final phoneError = Validators.phone(phone);
    if (phoneError != null) throw ProfileException(phoneError);
    final areaError = Validators.area(area);
    if (areaError != null) throw ProfileException(areaError);

    final newName = username.trim();
    final oldKey = Validators.usernameKey(current.username);
    final newKey = Validators.usernameKey(newName);
    final keyChanged = oldKey != newKey;

    final newNameRef = _usernames.doc(newKey);
    final oldNameRef = _usernames.doc(oldKey);
    final userRef = _users.doc(current.uid);

    try {
      final taken = await _db.runTransaction<bool>((tx) async {
        // Firestore transactions require every read before the first write.
        final newNameDoc = await tx.get(newNameRef);
        final oldNameDoc = (keyChanged && oldKey.isNotEmpty)
            ? await tx.get(oldNameRef)
            : null;

        final ownedByAnotherUser = newNameDoc.exists &&
            newNameDoc.data()?['uid'] != current.uid;
        if (keyChanged && ownedByAnotherUser) return true;

        if (oldNameDoc != null &&
            oldNameDoc.exists &&
            oldNameDoc.data()?['uid'] == current.uid) {
          tx.delete(oldNameRef);
        }
        // Also covers accounts created before usernames were reserved.
        if (!newNameDoc.exists) {
          tx.set(newNameRef, {'uid': current.uid});
        }

        tx.update(userRef, {
          'username': newName,
          'phone': phone.trim(),
          'area': area.trim(),
        });
        return false;
      });

      if (taken) throw const ProfileException('That username is already taken.');
    } on FirebaseException catch (e) {
      throw ProfileException(_message(e));
    }
  }

  /// Saves the profile picture URL (pass an empty string to remove it).
  Future<void> updatePhotoUrl({
    required String uid,
    required String photoUrl,
  }) async {
    try {
      await _users.doc(uid).update({'photoUrl': photoUrl});
    } on FirebaseException catch (e) {
      throw ProfileException(_message(e));
    }
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
