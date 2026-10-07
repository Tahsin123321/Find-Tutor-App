import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'app_drawer.dart';
import 'models/post_search_filters.dart';
import 'models/tuition_post.dart';
import 'search_filter_sheet.dart';
import 'services/auth_service.dart';
import 'services/post_service.dart';
import 'services/storage_service.dart';

class StudentDashboard extends StatefulWidget {
  final String username;
  final String email;

  const StudentDashboard({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final TextEditingController searchController = TextEditingController();

  StreamSubscription<List<TuitionPost>>? _subscription;
  List<TuitionPost> _allPosts = [];
  List<TuitionPost> _filteredPosts = [];
  PostSearchFilters _filters = const PostSearchFilters();
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = PostService.instance.watchApprovedPosts(PostType.student).listen(
          (posts) {
        if (!mounted) return;
        setState(() {
          _allPosts = posts;
          _error = null;
          _loaded = true;
          _applyFilter();
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not load student posts.';
          _loaded = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    searchController.dispose();
    super.dispose();
  }

  // Free-text search across name/area/subject, combined (AND) with any
  // structured filters (class/subject/area) chosen via the filter sheet.
  void searchStudent(String query) {
    setState(_applyFilter);
  }

  void _applyFilter() {
    final searchLower = searchController.text.toLowerCase();
    _filteredPosts = _allPosts.where((post) {
      final matchesKeyword = searchLower.isEmpty ||
          post.name.toLowerCase().contains(searchLower) ||
          post.area.toLowerCase().contains(searchLower) ||
          post.subject.toLowerCase().contains(searchLower);
      return matchesKeyword && _filters.matches(post);
    }).toList();
  }

  Future<void> _openFilterSheet() async {
    final result = await showSearchFilterSheet(
      context,
      initial: _filters,
      includeFee: false, // tutors searching students: no fee criterion
    );
    if (result != null) {
      setState(() {
        _filters = result;
        _applyFilter();
      });
    }
  }

  Future<void> _openDocument(TuitionPost post) async {
    if (post.documentPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No document uploaded for this request.")),
      );
      return;
    }
    try {
      final file = await StorageService.instance.downloadDocumentToTemp(post.documentPath);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not open file: ${result.message}")),
        );
      }
    } on StorageException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not download the document.")),
        );
      }
    }
  }

  void _showStudentDetails(TuitionPost post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          post.name.isNotEmpty ? post.name : 'Unknown Student',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow("Class:", post.className),
              _buildDetailRow("Subject:", post.subject),
              _buildDetailRow("Area:", post.area),
              _buildDetailRow("Institution:", post.institution),
              _buildDetailRow("Phone Number:", post.phone),
              _buildDetailRow("Document Name:", post.documentName),
            ],
          ),
        ),
        actions: [
          if (post.documentPath.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openDocument(post);
              },
              child: const Text("View Document"),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 2),
          Text(value?.toString().isNotEmpty == true ? value.toString() : 'N/A',
              style: const TextStyle(fontSize: 16, color: Colors.black87)),
          const Divider(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      drawer: AppDrawer(
        username: widget.username,
        email: widget.email,
      ),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: const Text(
          "Student Dashboard",
          style: TextStyle(
            color: Colors.black,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xffF1F5FA),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: searchStudent,
                      decoration: const InputDecoration(
                        hintText: "Search Students, Subjects or Area...",
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.search, color: Colors.blue),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _openFilterSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _filters.isEmpty ? Colors.white : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _filters.isEmpty ? Colors.grey.shade300 : Colors.blue,
                      ),
                    ),
                    child: Icon(
                      Icons.filter_list,
                      color: _filters.isEmpty ? Colors.grey : Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xff2196F3),
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddStudentPage()),
          );
          // No manual refresh needed: the dashboard listens to Firestore and
          // updates itself once an admin approves the new post.
        },
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildList() {
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(child: Text(_error!, style: const TextStyle(color: Colors.grey)));
    }
    if (_filteredPosts.isEmpty) {
      return const Center(child: Text("No Students Found"));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _filteredPosts.length,
      itemBuilder: (context, index) {
        final post = _filteredPosts[index];
        final bool isOnline = index % 3 != 2; // decorative only, as before

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: const Color(0xffE2E8F0),
                      child: Icon(Icons.person, size: 35, color: Colors.blue.shade400),
                    ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.name.isNotEmpty ? post.name : 'Unknown',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.school_outlined, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              "Class: ${post.className}",
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.book_outlined, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              post.displayDetails,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => _showStudentDetails(post),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff2196F3),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "View",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AddStudentPage extends StatefulWidget {
  const AddStudentPage({super.key});

  @override
  State<AddStudentPage> createState() => _AddStudentPageState();
}

class _AddStudentPageState extends State<AddStudentPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController classController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController institutionController = TextEditingController();

  String? selectedPdfName;
  File? selectedPdfFile;
  bool _isSubmitting = false;

  Future<void> _pickAndOpenPDF() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (!mounted) return;

      if (result != null && result.files.single.path != null) {
        setState(() {
          selectedPdfFile = File(result.files.single.path!);
          selectedPdfName = result.files.single.name;
        });
        await OpenFilex.open(selectedPdfFile!.path);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No file selected")),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking file: $e")),
      );
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    final uid = AuthService.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You are not signed in.")),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final profile = await AuthService.instance.fetchProfile(uid);
      await PostService.instance.createPost(
        type: PostType.student,
        ownerUid: uid,
        ownerUsername: profile?.username ?? '',
        name: nameController.text.trim(),
        className: classController.text.trim(),
        subject: subjectController.text.trim(),
        area: areaController.text.trim(),
        phone: phoneController.text.trim(),
        institution: institutionController.text.trim(),
        document: selectedPdfFile,
        documentName: selectedPdfName,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Submitted to Admin for Approval")),
      );
      Navigator.pop(context);
    } on PostException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not submit. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    classController.dispose();
    subjectController.dispose();
    areaController.dispose();
    phoneController.dispose();
    institutionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffEAF3FF),
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Add Student",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputField(hintText: "Student Name", controller: nameController, enabled: !_isSubmitting),
              const SizedBox(height: 15),
              _buildInputField(hintText: "Class", controller: classController, enabled: !_isSubmitting),
              const SizedBox(height: 15),
              _buildInputField(hintText: "Subject", controller: subjectController, enabled: !_isSubmitting),
              const SizedBox(height: 15),
              _buildInputField(hintText: "Area", controller: areaController, enabled: !_isSubmitting),
              const SizedBox(height: 15),
              _buildInputField(
                hintText: "Phone Number",
                controller: phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 15),
              _buildInputField(hintText: "Institution Name", controller: institutionController, enabled: !_isSubmitting),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: _isSubmitting ? null : _pickAndOpenPDF,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: const Color(0xffF1F5FA),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selectedPdfName != null ? Colors.blue : Colors.grey,
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          selectedPdfName ?? "Select ID Card (PDF)",
                          style: TextStyle(
                            color: selectedPdfName != null ? Colors.blue.shade700 : Colors.grey.shade700,
                            fontSize: 16,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff1E88E5),
                  elevation: 2,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
                    : const Text(
                  "Add Student",
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String hintText,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return "Please enter $hintText";
        }
        return null;
      },
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
        filled: true,
        fillColor: const Color(0xffF1F5FA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.grey, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.blue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.red, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
      ),
    );
  }
}
