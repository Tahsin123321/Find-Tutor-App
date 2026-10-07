import 'package:flutter/material.dart';

import 'models/app_user.dart';
import 'role_router.dart';
import 'services/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  // Controllers to capture user input
  final usernameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  // Track the selected role (admins are created manually in Firebase, never here)
  String? selectedRole;
  final List<String> roles = [UserRole.student, UserRole.tutor];

  final AuthService _auth = AuthService.instance;
  bool _isLoading = false;

  static final RegExp _emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final RegExp _phoneRegex = RegExp(r'^\+?[0-9]{7,15}$');

  @override
  void dispose() {
    usernameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  /// Returns an error message, or null when every field is valid.
  String? _validate() {
    final username = usernameController.text.trim();
    final email = emailController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text;

    if (username.isEmpty ||
        email.isEmpty ||
        phone.isEmpty ||
        password.isEmpty ||
        selectedRole == null) {
      return "Please fill all fields and select a role";
    }
    if (username.length < 3) return "Username must be at least 3 characters";
    if (!_emailRegex.hasMatch(email)) return "Please enter a valid email address";
    if (!_phoneRegex.hasMatch(phone)) {
      return "Please enter a valid phone number (7-15 digits)";
    }
    if (password.length < 6) return "Password must be at least 6 characters";
    return null;
  }

  Future<void> _handleSignup() async {
    if (_isLoading) return;

    final error = _validate();
    if (error != null) {
      _showSnack(error);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await _auth.signUp(
        username: usernameController.text,
        email: emailController.text,
        phone: phoneController.text,
        password: passwordController.text,
        role: selectedRole!,
      );

      if (!mounted) return;

      _showSnack("Signup Successful!", color: Colors.green);

      // Firebase signs the new user in automatically, so go straight to their
      // dashboard (this also removes the signup and login screens).
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => screenForUser(user)),
            (route) => false,
      );
    } on AuthException catch (e) {
      _showSnack(e.message, color: Colors.red);
    } catch (_) {
      _showSnack("Something went wrong. Please try again.", color: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
        backgroundColor: Colors.blue[100],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              const Text(
                "Sign up to get started",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 30),

              // Username Field
              TextField(
                controller: usernameController,
                enabled: !_isLoading,
                decoration: const InputDecoration(
                  labelText: "Username",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: 15),

              // Email Field
              TextField(
                controller: emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: "Email",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 15),

              // Phone Number Field
              TextField(
                controller: phoneController,
                enabled: !_isLoading,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone_android),
                ),
              ),
              const SizedBox(height: 15),

              // Role Dropdown Field
              DropdownButtonFormField<String>(
                value: selectedRole,
                hint: const Text("Select Your Role"),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment_ind_outlined),
                ),
                items: roles.map((String role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: _isLoading
                    ? null
                    : (newValue) {
                  setState(() {
                    selectedRole = newValue;
                  });
                },
              ),
              const SizedBox(height: 15),

              // Password Field
              TextField(
                controller: passwordController,
                enabled: !_isLoading,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 30),

              // Sign Up Button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: _isLoading ? null : _handleSignup,
                  child: _isLoading
                      ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Text("Sign Up", style: TextStyle(fontSize: 18)),
                ),
              ),

              const SizedBox(height: 15),

              // Back to Login Link
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text(
                  "Already have an account? Login",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
