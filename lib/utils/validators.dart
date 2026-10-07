// lib/utils/validators.dart

/// Input validation shared by signup, profile editing and the auth service.
/// Each validator returns an error message, or null when the value is valid
/// (the shape `TextFormField.validator` expects).
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');

  /// Key used in the `usernames` collection to keep usernames unique
  /// regardless of upper/lower case.
  static String usernameKey(String username) => username.trim().toLowerCase();

  static bool isValidEmail(String value) => _emailRegex.hasMatch(value.trim());

  static String? username(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter a username';
    if (v.length < 3) return 'Username must be at least 3 characters';
    if (v.length > 30) return 'Username must be 30 characters or fewer';
    // The username doubles as a Firestore document id, so keep it id-safe.
    if (v.contains('/')) return 'Username cannot contain "/"';
    if (v.startsWith('__')) return 'Username cannot start with "__"';
    return null;
  }

  static String? phone(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter a phone number';
    if (!_phoneRegex.hasMatch(v)) {
      return 'Enter a valid phone number (7-15 digits)';
    }
    return null;
  }

  /// Area is optional, but capped so it cannot be abused as free storage.
  static String? area(String? value) {
    final v = value?.trim() ?? '';
    if (v.length > 100) return 'Area must be 100 characters or fewer';
    return null;
  }

  static String? password(String? value) {
    final v = value ?? '';
    if (v.isEmpty) return 'Please enter a password';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }
}
