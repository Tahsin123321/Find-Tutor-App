// lib/auth_gate.dart
import 'package:flutter/material.dart';

import 'login.dart';
import 'role_router.dart';
import 'services/auth_service.dart';

/// Decides the first screen when the app starts:
/// signed in -> role dashboard, otherwise -> login.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late Future<Widget> _destination;

  @override
  void initState() {
    super.initState();
    _destination = _resolve();
  }

  Future<Widget> _resolve() async {
    final auth = AuthService.instance;

    final firebaseUser = await auth.authStateChanges().first;
    if (firebaseUser == null) return const LoginPage();

    final profile = await auth.fetchProfile(firebaseUser.uid);
    if (profile == null) {
      await auth.signOut();
      return const LoginPage();
    }
    return screenForUser(profile);
  }

  void _retry() {
    setState(() => _destination = _resolve());
  }

  Future<void> _signOutAndRetry() async {
    await AuthService.instance.signOut();
    if (!mounted) return;
    _retry();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destination,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          final message = snapshot.error?.toString() ?? 'Something went wrong.';
          return Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.cloud_off, size: 60, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    ElevatedButton(onPressed: _retry, child: const Text('Retry')),
                    TextButton(
                      onPressed: _signOutAndRetry,
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return snapshot.data!;
      },
    );
  }
}
