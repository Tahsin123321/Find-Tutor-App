import 'package:flutter/material.dart';

import 'role_router.dart';
import 'services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final AuthService _auth = AuthService.instance;

  bool _isLoading = false;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  @override
  void initState() {
    super.initState();
    // Reaching this screen always means "no active session". Every existing
    // Logout button pushes '/login', so ending the Firebase session here keeps
    // them all working without changing those files yet.
    _auth.signOut();
  }

  Future<void> _handleLogin() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    final password = _passController.text;

    if (email.isEmpty || password.isEmpty) {
      _showMsg("Please fill in all fields");
      return;
    }
    if (!_emailRegex.hasMatch(email)) {
      _showMsg("Please enter a valid email address");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _auth.signIn(email: email, password: password);
      if (!mounted) return;

      // Role-based routing (Student / Tutor / Admin) from the Firestore profile.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => screenForUser(user)),
            (route) => false,
      );
    } on AuthException catch (e) {
      _showMsg(e.message);
    } catch (_) {
      _showMsg("Something went wrong. Please try again.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 80),
              const Icon(
                Icons.menu_book_rounded,
                size: 85,
                color: Colors.blueAccent,
              ),
              const SizedBox(height: 10),
              const Text(
                "Tuition Manager",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                    labelText: "Email", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _passController,
                obscureText: true,
                enabled: !_isLoading,
                onSubmitted: (_) => _handleLogin(),
                decoration: const InputDecoration(
                    labelText: "Password", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                      : const Text("Login"),
                ),
              ),
              TextButton(
                onPressed:
                _isLoading ? null : () => Navigator.pushNamed(context, '/signup'),
                child: const Text("Don't have an account? Sign Up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
