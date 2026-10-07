// lib/role_router.dart
import 'package:flutter/material.dart';

import 'admin_home.dart';
import 'models/app_user.dart';
import 'student_home.dart';
import 'tutor_home.dart';

/// Returns the landing screen for a signed-in user, based on their role.
Widget screenForUser(AppUser user) {
  switch (user.role) {
    case UserRole.admin:
      return AdminDashboard(username: user.username, email: user.email);
    case UserRole.tutor:
      return TutorDashboardScreen(username: user.username, email: user.email);
    default:
      return StudentDashboard(username: user.username, email: user.email);
  }
}
