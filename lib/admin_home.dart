// admin_home.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'home.dart';
import 'models/app_user.dart';
import 'models/tuition_post.dart';
import 'models/verification_request.dart';
import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'services/verification_service.dart';
import 'student_home.dart';
import 'tutor_home.dart';

class AdminDashboard extends StatelessWidget {
  final String username;
  final String email;

  const AdminDashboard({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF4F7FC),
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: Colors.indigo.shade800,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Admin Portal",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
      ),
      drawer: AdminDrawer(
        username: username,
        email: email,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome Back, $username!",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade900,
              ),
            ),
            const Text(
              "System Overview & System Control Panel",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 25),
            Text(
              "Users",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade900,
              ),
            ),
            const SizedBox(height: 15),
            _buildActionButton(
              context,
              title: "View All Users",
              subtitle: "Browse every registered student, tutor and admin",
              icon: Icons.people_alt_outlined,
              color: Colors.indigo.shade700,
              targetPage: const UsersListPage(),
            ),
            const SizedBox(height: 25),
            Text(
              "Identity Verification",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade900,
              ),
            ),
            const SizedBox(height: 15),
            _buildActionButton(
              context,
              title: "Review Student Verification Requests",
              subtitle: "Approve or reject student identity documents",
              icon: Icons.person_search_rounded,
              color: Colors.blue.shade700,
              targetPage: const VerificationRequestsPage(role: UserRole.student),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              title: "Review Tutor Verification Requests",
              subtitle: "Verify credentials and teaching documents",
              icon: Icons.badge_outlined,
              color: Colors.teal.shade700,
              targetPage: const VerificationRequestsPage(role: UserRole.tutor),
            ),
            const SizedBox(height: 25),
            Text(
              "Tuition Posts",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade900,
              ),
            ),
            const SizedBox(height: 15),
            _buildActionButton(
              context,
              title: "Review Student Posts",
              subtitle: "Approve or delete pending student requests",
              icon: Icons.assignment_ind_outlined,
              color: Colors.orange.shade700,
              targetPage: const PostsReviewPage(type: PostType.student),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              context,
              title: "Review Tutor Posts",
              subtitle: "Approve or delete pending tutor listings",
              icon: Icons.assignment_turned_in_outlined,
              color: Colors.green.shade700,
              targetPage: const PostsReviewPage(type: PostType.tutor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required Widget targetPage,
      }) {
    return InkWell(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => targetPage));
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.1),
              radius: 24,
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

class AdminDrawer extends StatelessWidget {
  final String username;
  final String email;

  const AdminDrawer({
    super.key,
    required this.username,
    required this.email,
  });

  Future<void> _logout(BuildContext context) async {
    await AuthService.instance.signOut();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Colors.indigo.shade800),
            accountName: Text(
              "$username (Admin)",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(email),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.admin_panel_settings, size: 50, color: Colors.indigo),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 10, bottom: 5),
            child: Text("Management Panel", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.space_dashboard_rounded, color: Colors.indigo),
            title: const Text("Admin Dashboard"),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.people_alt_outlined, color: Colors.indigo),
            title: const Text("All Users"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (context) => const UsersListPage()));
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_ind, color: Colors.blue),
            title: const Text("Student Verification"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const VerificationRequestsPage(role: UserRole.student)),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment_turned_in, color: Colors.green),
            title: const Text("Tutor Verification"),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const VerificationRequestsPage(role: UserRole.tutor)),
              );
            },
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.only(left: 16.0, top: 5, bottom: 5),
            child: Text("Switch Application Views", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.black54),
            title: const Text("Home"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => HomePage(username: username, email: email)),
                    (route) => false,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.school, color: Colors.black54),
            title: const Text("Student Dashboard View"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => StudentDashboard(username: username, email: email)),
                    (route) => false,
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: Colors.black54),
            title: const Text("Tutor Dashboard View"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => TutorDashboardScreen(username: username, email: email)),
                    (route) => false,
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Users list (read-only)
// -----------------------------------------------------------------------------

class UsersListPage extends StatefulWidget {
  const UsersListPage({super.key});

  @override
  State<UsersListPage> createState() => _UsersListPageState();
}

class _UsersListPageState extends State<UsersListPage> {
  static const List<String> _tabs = ['All', UserRole.student, UserRole.tutor, UserRole.admin];
  String _selectedRole = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("All Users"),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.indigo.shade800,
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: _tabs.map((role) {
                final selected = role == _selectedRole;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: ChoiceChip(
                    label: Text(role),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedRole = role),
                    selectedColor: Colors.white,
                    backgroundColor: Colors.indigo.shade600,
                    labelStyle: TextStyle(
                      color: selected ? Colors.indigo.shade800 : Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: AdminService.instance.watchAllUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Could not load users."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final users = _selectedRole == 'All'
              ? snapshot.data!
              : snapshot.data!.where((u) => u.role == _selectedRole).toList();

          if (users.isEmpty) {
            return const Center(child: Text("No users found."));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final statusColor = _statusColor(user.verificationStatus);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xffE2E8F0),
                    foregroundImage:
                    user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
                    onForegroundImageError: user.photoUrl.isNotEmpty ? (e, s) {} : null,
                    child: const Icon(Icons.person, color: Colors.blueGrey),
                  ),
                  title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${user.email}\n${user.role}${user.area.isNotEmpty ? " • ${user.area}" : ""}'),
                  isThreeLine: true,
                  trailing: Chip(
                    label: Text(
                      user.verificationStatus,
                      style: TextStyle(fontSize: 11, color: statusColor),
                    ),
                    backgroundColor: statusColor.withValues(alpha: 0.1),
                    side: BorderSide.none,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case VerificationStatus.approved:
        return Colors.green;
      case VerificationStatus.pending:
        return Colors.orange;
      case VerificationStatus.rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

// -----------------------------------------------------------------------------
// Verification requests review
// -----------------------------------------------------------------------------

class VerificationRequestsPage extends StatefulWidget {
  final String role;

  const VerificationRequestsPage({super.key, required this.role});

  @override
  State<VerificationRequestsPage> createState() => _VerificationRequestsPageState();
}

class _VerificationRequestsPageState extends State<VerificationRequestsPage> {
  final Set<String> _busyUids = {};

  Future<void> _approve(VerificationRequest request) async {
    setState(() => _busyUids.add(request.uid));
    try {
      await AdminService.instance.reviewVerificationRequest(uid: request.uid, approve: true);
      _snack('${request.username} verified successfully.', color: Colors.green);
    } on AdminException catch (e) {
      _snack(e.message, color: Colors.red);
    } catch (_) {
      _snack('Could not approve this request.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _busyUids.remove(request.uid));
    }
  }

  Future<void> _reject(VerificationRequest request) async {
    final reason = await _promptReason(context, title: 'Reject verification');
    if (reason == null) return; // cancelled

    setState(() => _busyUids.add(request.uid));
    try {
      await AdminService.instance.reviewVerificationRequest(
        uid: request.uid,
        approve: false,
        rejectionReason: reason,
      );
      _snack('Request rejected.', color: Colors.orange);
    } on AdminException catch (e) {
      _snack(e.message, color: Colors.red);
    } catch (_) {
      _snack('Could not reject this request.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _busyUids.remove(request.uid));
    }
  }

  Future<void> _openDocument(VerificationRequest request) async {
    try {
      final file = await VerificationService.instance.downloadDocument(request);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _snack('Could not open file: ${result.message}', color: Colors.red);
      }
    } catch (_) {
      _snack('Could not download the document.', color: Colors.red);
    }
  }

  void _snack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.role == UserRole.student;
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.role} Verification Requests"),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<VerificationRequest>>(
        stream: AdminService.instance.watchPendingVerificationRequests(widget.role),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Could not load requests."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final requests = snapshot.data!;
          if (requests.isEmpty) {
            return const Center(
              child: Text("No verification requests pending.", style: TextStyle(fontSize: 16, color: Colors.grey)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final busy = _busyUids.contains(request.uid);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: isStudent ? Colors.blue.shade50 : Colors.teal.shade50,
                            child: Icon(
                              isStudent ? Icons.person : Icons.badge,
                              color: isStudent ? Colors.blue : Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(request.username,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                if (request.submittedAt != null)
                                  Text(
                                    "Submitted: ${_formatDate(request.submittedAt!)}",
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      InkWell(
                        onTap: () => _openDocument(request),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  "View Document (${request.documentName})",
                                  style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w600, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.open_in_new, size: 16, color: Colors.redAccent),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: busy ? null : () => _reject(request),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Text("Reject"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: busy ? null : () => _approve(request),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: busy
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Text("Approve", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// -----------------------------------------------------------------------------
// Posts review (approve or delete)
// -----------------------------------------------------------------------------

class PostsReviewPage extends StatefulWidget {
  final String type;

  const PostsReviewPage({super.key, required this.type});

  @override
  State<PostsReviewPage> createState() => _PostsReviewPageState();
}

class _PostsReviewPageState extends State<PostsReviewPage> {
  final Set<String> _busyIds = {};

  Future<void> _approve(TuitionPost post) async {
    setState(() => _busyIds.add(post.id));
    try {
      await AdminService.instance.approvePost(post.id);
      _snack('Approved post for ${post.name}', color: Colors.green);
    } on AdminException catch (e) {
      _snack(e.message, color: Colors.red);
    } catch (_) {
      _snack('Could not approve this post.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _busyIds.remove(post.id));
    }
  }

  Future<void> _delete(TuitionPost post) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this post?'),
        content: Text('This will permanently remove the post for "${post.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busyIds.add(post.id));
    try {
      await AdminService.instance.deletePost(post);
      _snack('Post deleted.');
    } on AdminException catch (e) {
      _snack(e.message, color: Colors.red);
    } catch (_) {
      _snack('Could not delete this post.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _busyIds.remove(post.id));
    }
  }

  Future<void> _openDocument(TuitionPost post) async {
    if (post.documentPath.isEmpty) {
      _snack('No document uploaded for this request.');
      return;
    }
    try {
      final file = await StorageService.instance.downloadDocumentToTemp(post.documentPath);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _snack('Could not open file: ${result.message}', color: Colors.red);
      }
    } catch (_) {
      _snack('Could not download the document.', color: Colors.red);
    }
  }

  void _snack(String message, {Color? color}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    final isStudent = widget.type == PostType.student;
    return Scaffold(
      appBar: AppBar(
        title: Text("${widget.type} Posts Pending Review"),
        backgroundColor: Colors.indigo.shade800,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<TuitionPost>>(
        stream: AdminService.instance.watchPendingPosts(widget.type),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text("Could not load posts."));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return Center(
              child: Text(
                "No ${widget.type.toLowerCase()} posts pending.",
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final busy = _busyIds.contains(post.id);

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor: isStudent ? Colors.blue.shade50 : Colors.teal.shade50,
                            child: Icon(
                              isStudent ? Icons.person : Icons.badge,
                              color: isStudent ? Colors.blue : Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(post.name.isNotEmpty ? post.name : 'Unknown',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                                if (post.createdAt != null)
                                  Text(
                                    "Submitted: ${_formatDate(post.createdAt!)}",
                                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Text(
                        "Class: ${post.className}\nSubject: ${post.subject}\nArea: ${post.area}\nPhone: ${post.phone}\nInstitution: ${post.institution}",
                        style: TextStyle(color: Colors.grey.shade800, fontSize: 14, height: 1.4),
                      ),
                      const SizedBox(height: 15),
                      InkWell(
                        onTap: () => _openDocument(post),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  post.documentPath.isNotEmpty
                                      ? "View Document (${post.documentName})"
                                      : "No Attachment Provided",
                                  style: TextStyle(
                                    color: post.documentPath.isNotEmpty ? Colors.red.shade700 : Colors.grey,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (post.documentPath.isNotEmpty)
                                const Icon(Icons.open_in_new, size: 16, color: Colors.redAccent),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: busy ? null : () => _delete(post),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: const Text("Delete"),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: busy ? null : () => _approve(post),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              ),
                              child: busy
                                  ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                                  : const Text("Approve", style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

// -----------------------------------------------------------------------------
// Shared: reject-reason prompt
// -----------------------------------------------------------------------------

Future<String?> _promptReason(BuildContext context, {required String title}) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        maxLines: 3,
        decoration: const InputDecoration(
          hintText: 'Reason (optional) — shown to the user',
          border: OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text.trim()),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
          child: const Text('Reject'),
        ),
      ],
    ),
  );
}
