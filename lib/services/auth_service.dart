// lib/services/auth_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';
import '../utils/validators.dart';

/// Error with a message that is safe to show directly to the user.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}

/// Single place for registration, login, logout, password change and
/// profile lookup.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _usernames =>
      _db.collection('usernames');

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  /// Returns the profile for [uid], or null if no profile document exists.
  Future<AppUser?> fetchProfile(String uid) async {
    try {
      final doc = await _users.doc(uid).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return AppUser.fromMap(doc.id, data);
    } on FirebaseException catch (e) {
      throw AuthException(_firestoreMessage(e));
    }
  }

  /// Creates the Firebase Auth account, then - in one transaction - reserves
  /// the username and writes the `users/{uid}` profile.
  /// If anything after account creation fails, the Auth account is removed
  /// again so no half-registered account is left behind.
  Future<AppUser> signUp({
    required String username,
    required String email,
    required String phone,
    required String password,
    required String role,
  }) async {
    if (role != UserRole.student && role != UserRole.tutor) {
      throw const AuthException('Please select a valid role.');
    }
    final usernameError = Validators.username(username);
    if (usernameError != null) throw AuthException(usernameError);

    final UserCredential credential;
    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authMessage(e));
    }

    final firebaseUser = credential.user;
    if (firebaseUser == null) {
      throw const AuthException('Could not create the account. Please try again.');
    }

    final profile = AppUser(
      uid: firebaseUser.uid,
      username: username.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
      role: role,
    );

    final nameRef = _usernames.doc(Validators.usernameKey(profile.username));
    final userRef = _users.doc(firebaseUser.uid);

    try {
      final taken = await _db.runTransaction<bool>((tx) async {
        final existing = await tx.get(nameRef);
        if (existing.exists) return true;
        tx.set(nameRef, {'uid': firebaseUser.uid});
        tx.set(userRef, profile.toCreateMap());
        return false;
      });

      if (taken) {
        await _rollbackAccount(firebaseUser);
        throw const AuthException('That username is already taken.');
      }
    } on FirebaseException catch (e) {
      await _rollbackAccount(firebaseUser);
      throw AuthException(_firestoreMessage(e));
    }

    // Nice-to-have only; never fail registration because of it.
    try {
      await firebaseUser.updateDisplayName(profile.username);
    } catch (_) {}

    return profile;
  }

  /// Signs in and returns the matching profile.
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_authMessage(e));
    }

    final uid = credential.user?.uid;
    if (uid == null) {
      throw const AuthException('Login failed. Please try again.');
    }

    try {
      final profile = await fetchProfile(uid);
      if (profile == null) {
        await _auth.signOut();
        throw const AuthException(
            'No profile found for this account. Please contact the administrator.');
      }
      return profile;
    } on AuthException {
      await _auth.signOut();
      rethrow;
    }
  }

  /// Re-authenticates with the current password, then sets the new one.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;
    if (user == null || email == null) {
      throw const AuthException('You are not signed in.');
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        throw const AuthException('Your current password is incorrect.');
      }
      throw AuthException(_authMessage(e));
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> _rollbackAccount(User user) async {
    try {
      await user.delete();
    } catch (_) {
      await _auth.signOut();
    }
  }

  // ---------------------------------------------------------------------------
  // Error mapping
  // ---------------------------------------------------------------------------

  String _authMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled in Firebase.';
      case 'requires-recent-login':
        return 'Please log in again before doing that.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  String _firestoreMessage(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'You do not have permission to do that. Check the Firestore rules.';
      case 'unavailable':
        return 'Service unavailable. Please check your connection.';
      default:
        return e.message ?? 'Database error (${e.code}).';
    }
  }
}
