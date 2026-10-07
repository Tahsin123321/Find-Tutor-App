// lib/profile_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/app_user.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/user_service.dart';
import 'utils/validators.dart';
import 'verification_screen.dart';

/// Shows the signed-in user's profile and lets them edit it, change their
/// profile picture and password, and log out.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _areaController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  StreamSubscription<AppUser?>? _subscription;
  AppUser? _user;
  String? _loadError;
  bool _formFilled = false;
  bool _saving = false;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _listenToProfile();
  }

  void _listenToProfile() {
    _subscription?.cancel();
    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      _loadError = 'You are not signed in.';
      return;
    }
    _loadError = null;
    _subscription = UserService.instance.watchUser(uid).listen(
      _onUser,
      onError: (Object _) {
        if (!mounted) return;
        setState(() => _loadError = 'Could not load your profile.');
      },
    );
  }

  void _onUser(AppUser? user) {
    if (!mounted) return;
    if (user == null) {
      setState(() => _loadError = 'Profile not found.');
      return;
    }
    setState(() {
      _user = user;
      _loadError = null;
      // Fill the form once, so live updates never overwrite what is being typed.
      if (!_formFilled) {
        _usernameController.text = user.username;
        _phoneController.text = user.phone;
        _areaController.text = user.area;
        _formFilled = true;
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _usernameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    final user = _user;
    if (user == null || _saving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      await UserService.instance.updateProfile(
        current: user,
        username: _usernameController.text,
        phone: _phoneController.text,
        area: _areaController.text,
      );
      _snack('Profile updated', color: Colors.green);
    } on ProfileException catch (e) {
      _snack(e.message, color: Colors.red);
    } catch (_) {
      _snack('Could not save changes. Please try again.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showPhotoOptions(AppUser user) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _changePhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(sheetContext);
                _changePhoto(ImageSource.gallery);
              },
            ),
            if (user.photoUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('Remove photo',
                    style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _removePhoto();
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changePhoto(ImageSource source) async {
    final user = _user;
    if (user == null || _uploadingPhoto) return;

    try {
      // Resize + compress before upload to save the user's data and quota.
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return; // cancelled
      if (!mounted) return;

      setState(() => _uploadingPhoto = true);

      final oldUrl = user.photoUrl;
      final newUrl = await StorageService.instance.uploadProfilePicture(
        uid: user.uid,
        file: File(picked.path),
      );

      try {
        await UserService.instance.updatePhotoUrl(uid: user.uid, photoUrl: newUrl);
      } catch (_) {
        // Do not leave an unused file behind if the profile save failed.
        await StorageService.instance.deleteByUrl(newUrl);
        rethrow;
      }

      await StorageService.instance.deleteByUrl(oldUrl);
      _snack('Profile picture updated', color: Colors.green);
    } on StorageException catch (e) {
      _snack(e.message, color: Colors.red);
    } on ProfileException catch (e) {
      _snack(e.message, color: Colors.red);
    } catch (_) {
      _snack('Could not update the picture. Please try again.',
          color: Colors.red);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _removePhoto() async {
    final user = _user;
    if (user == null || _uploadingPhoto || user.photoUrl.isEmpty) return;

    setState(() => _uploadingPhoto = true);
    try {
      await UserService.instance.updatePhotoUrl(uid: user.uid, photoUrl: '');
      await StorageService.instance.deleteByUrl(user.photoUrl);
      _snack('Profile picture removed');
    } on ProfileException catch (e) {
      _snack(e.message, color: Colors.red);
    } catch (_) {
      _snack('Could not remove the picture. Please try again.',
          color: Colors.red);
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => const _ChangePasswordDialog(),
    );
    if (changed == true) {
      _snack('Password changed successfully', color: Colors.green);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You will need to log in again to use the app.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _snack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final user = _user;

    if (user == null) {
      if (_loadError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.grey),
                const SizedBox(height: 12),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(_listenToProfile),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(user),
          const SizedBox(height: 20),
          _buildAccountCard(user),
          const SizedBox(height: 20),
          _buildVerificationCard(user),
          const SizedBox(height: 20),
          _buildEditCard(),
          const SizedBox(height: 20),
          _buildSecurityCard(),
        ],
      ),
    );
  }

  Widget _buildAvatar(AppUser user) {
    return SizedBox(
      width: 96,
      height: 96,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: const Color(0xffE2E8F0),
            foregroundImage:
            user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
            onForegroundImageError:
            user.photoUrl.isNotEmpty ? (e, s) {} : null,
            child: Icon(Icons.person, size: 54, color: Colors.blue.shade400),
          ),
          if (_uploadingPhoto)
            Positioned.fill(
              child: ClipOval(
                child: Container(
                  color: Colors.black38,
                  child: const Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: -2,
            right: -2,
            child: Material(
              color: Colors.blue,
              shape: const CircleBorder(
                side: BorderSide(color: Colors.white, width: 2),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _uploadingPhoto ? null : () => _showPhotoOptions(user),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(Icons.camera_alt, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(AppUser user) {
    final status = _statusInfo(user.verificationStatus);
    return Column(
      children: [
        _buildAvatar(user),
        const SizedBox(height: 12),
        Text(
          user.username,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          alignment: WrapAlignment.center,
          children: [
            Chip(
              avatar: const Icon(Icons.badge_outlined, size: 18),
              label: Text(user.role),
              backgroundColor: Colors.blue.withValues(alpha: 0.1),
              side: BorderSide.none,
            ),
            Chip(
              avatar: Icon(status.icon, size: 18, color: status.color),
              label: Text(status.label, style: TextStyle(color: status.color)),
              backgroundColor: status.color.withValues(alpha: 0.1),
              side: BorderSide.none,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAccountCard(AppUser user) {
    return _card(
      title: 'Account',
      child: Column(
        children: [
          _infoRow(Icons.email_outlined, 'Email', user.email),
          const Divider(height: 24),
          _infoRow(Icons.assignment_ind_outlined, 'Role', user.role),
          const Divider(height: 24),
          _infoRow(Icons.calendar_today_outlined, 'Member since',
              user.createdAt == null ? 'N/A' : _formatDate(user.createdAt!)),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(AppUser user) {
    final status = _statusInfo(user.verificationStatus);
    final canAct = user.verificationStatus != VerificationStatus.approved;

    return _card(
      title: 'Identity Verification',
      child: Row(
        children: [
          Icon(status.icon, color: status.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              status.label,
              style: TextStyle(fontWeight: FontWeight.w600, color: status.color),
            ),
          ),
          if (canAct)
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VerificationScreen(user: user),
                  ),
                );
              },
              child: Text(
                user.verificationStatus == VerificationStatus.pending
                    ? 'View'
                    : 'Get Verified',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditCard() {
    return _card(
      title: 'Edit Profile',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            TextFormField(
              controller: _usernameController,
              enabled: !_saving,
              validator: Validators.username,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration('Username', Icons.person_outline),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _phoneController,
              enabled: !_saving,
              validator: Validators.phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: _fieldDecoration('Phone Number', Icons.phone_android),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _areaController,
              enabled: !_saving,
              validator: Validators.area,
              textInputAction: TextInputAction.done,
              decoration:
              _fieldDecoration('Area / Address', Icons.location_on_outlined),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff1E88E5),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityCard() {
    return _card(
      title: 'Security',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _changePassword,
            icon: const Icon(Icons.lock_reset),
            label: const Text('Change Password'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, color: Colors.red),
            label: const Text('Logout', style: TextStyle(color: Colors.red)),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.red),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Small helpers
  // ---------------------------------------------------------------------------

  Widget _card({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.blue.shade400),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value.isEmpty ? 'N/A' : value,
                  style: const TextStyle(fontSize: 15)),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  ({String label, Color color, IconData icon}) _statusInfo(String status) {
    switch (status) {
      case VerificationStatus.approved:
        return (label: 'Verified', color: Colors.green, icon: Icons.verified);
      case VerificationStatus.pending:
        return (
        label: 'Pending review',
        color: Colors.orange,
        icon: Icons.hourglass_top
        );
      case VerificationStatus.rejected:
        return (label: 'Rejected', color: Colors.red, icon: Icons.cancel_outlined);
      default:
        return (
        label: 'Not verified',
        color: Colors.grey,
        icon: Icons.shield_outlined
        );
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// -----------------------------------------------------------------------------
// Change password dialog
// -----------------------------------------------------------------------------

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _loading = false;
  bool _hidePasswords = true;
  String? _error;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await AuthService.instance.changePassword(
        currentPassword: _currentController.text,
        newPassword: _newController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not change password. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        icon: Icon(_hidePasswords ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => _hidePasswords = !_hidePasswords),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Change Password',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentController,
                enabled: !_loading,
                obscureText: _hidePasswords,
                decoration: _decoration('Current password'),
                validator: (v) =>
                (v == null || v.isEmpty) ? 'Enter your current password' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _newController,
                enabled: !_loading,
                obscureText: _hidePasswords,
                decoration: _decoration('New password'),
                validator: (v) {
                  final base = Validators.password(v);
                  if (base != null) return base;
                  if (v == _currentController.text) {
                    return 'New password must be different';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _confirmController,
                enabled: !_loading,
                obscureText: _hidePasswords,
                decoration: _decoration('Confirm new password'),
                validator: (v) =>
                v != _newController.text ? 'Passwords do not match' : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Text('Update'),
        ),
      ],
    );
  }
}
