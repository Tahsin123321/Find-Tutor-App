import 'package:flutter/material.dart';

import 'home.dart';
import 'models/app_user.dart';
import 'profile_screen.dart';
import 'services/auth_service.dart';
import 'services/user_service.dart';
import 'student_home.dart';
import 'tutor_home.dart';

class AppDrawer extends StatefulWidget {
  final String username;
  final String email;

  const AppDrawer({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  Stream<AppUser?>? _userStream;

  @override
  void initState() {
    super.initState();
    final uid = AuthService.instance.currentUser?.uid;
    if (uid != null) {
      _userStream = UserService.instance.watchUser(uid);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _userStream,
      builder: (context, snapshot) {
        // Live profile values win; the constructor values are the fallback
        // while loading (or if the stream errors).
        final user = snapshot.data;
        final username = user?.username ?? widget.username;
        final email = user?.email ?? widget.email;
        final photoUrl = user?.photoUrl ?? '';

        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              UserAccountsDrawerHeader(
                decoration: const BoxDecoration(color: Colors.blue),
                accountName: Text(username,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                accountEmail: Text(email),
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  foregroundImage:
                  photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  onForegroundImageError: photoUrl.isNotEmpty ? (e, s) {} : null,
                  child: const Icon(Icons.person, size: 50, color: Colors.blue),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_circle, color: Colors.blue),
                title: const Text("My Profile"),
                onTap: () {
                  Navigator.pop(context); // close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.home, color: Colors.blue),
                title: const Text("Home"),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            HomePage(username: username, email: email)),
                        (route) => false,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.school, color: Colors.blue),
                title: const Text("Student Dashboard"),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            StudentDashboard(username: username, email: email)),
                        (route) => false,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard, color: Colors.blue),
                title: const Text("Tutor Dashboard"),
                onTap: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            TutorDashboardScreen(username: username, email: email)),
                        (route) => false,
                  );
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Logout", style: TextStyle(color: Colors.red)),
                onTap: _logout,
              ),
            ],
          ),
        );
      },
    );
  }
}
