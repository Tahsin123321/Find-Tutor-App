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

class TutorDashboardScreen extends StatefulWidget {
  final String username;
  final String email;

  const TutorDashboardScreen({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<TutorDashboardScreen> createState() => _TutorDashboardScreenState();
}

class _TutorDashboardScreenState extends State<TutorDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  StreamSubscription<List<TuitionPost>>? _subscription;
  List<TuitionPost> _allTutors = [];
  List<TuitionPost> _foundTutors = [];
  PostSearchFilters _filters = const PostSearchFilters();
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = PostService.instance.watchApprovedPosts(PostType.tutor).listen(
          (posts) {
        if (!mounted) return;
        setState(() {
          _allTutors = posts;
          _error = null;
          _loaded = true;
          _runFilter(_searchController.text);
        });
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() {
          _error = 'Could not load tutor posts.';
          _loaded = true;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Free-text search across name/subject, combined (AND) with any
  // structured filters (class/subject/area/fee) chosen via the filter sheet.
  void _runFilter(String enteredKeyword) {
    final keyword = enteredKeyword.toLowerCase();
    final results = _allTutors.where((tutor) {
      final matchesKeyword = keyword.isEmpty ||
          tutor.name.toLowerCase().contains(keyword) ||
          tutor.subject.toLowerCase().contains(keyword);
      return matchesKeyword && _filters.matches(tutor);
    }).toList();

    setState(() => _foundTutors = results);
  }

  Future<void> _openFilterSheet() async {
    final result = await showSearchFilterSheet(
      context,
      initial: _filters,
      includeFee: true, // students searching tutors: fee range applies
    );
    if (result != null) {
      setState(() => _filters = result);
      _runFilter(_searchController.text);
    }
  }

  Future<void> _openDocument(TuitionPost tutor) async {
    if (tutor.documentPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No document uploaded for this listing.")),
      );
      return;
    }
    try {
      final file = await StorageService.instance.downloadDocumentToTemp(tutor.documentPath);
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

  // Function to show the custom details modal dialog matching your reference image
  void _showTutorDetails(BuildContext context, TuitionPost tutor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: const Color(0xffEFEFFF),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.0),
          ),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xffECEFF4),
              borderRadius: BorderRadius.circular(24.0),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tutor.name.isNotEmpty ? tutor.name : 'Unknown Tutor',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildDialogField("Class:", tutor.className),
                  _buildDialogField("Subject:", tutor.subject),
                  _buildDialogField("Area:", tutor.area),
                  _buildDialogField("Tuition Fee:", tutor.fee > 0 ? tutor.fee.toStringAsFixed(0) : 'N/A'),
                  _buildDialogField("Institution:", tutor.institution),
                  _buildDialogField("Phone Number:", tutor.phone),
                  _buildDialogField("Document Name:", tutor.documentName),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (tutor.documentPath.isNotEmpty)
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _openDocument(tutor);
                          },
                          child: const Text("View Document"),
                        )
                      else
                        const SizedBox.shrink(),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Close",
                          style: TextStyle(
                            color: Colors.blue,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDialogField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.isNotEmpty ? value : 'N/A',
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        const Divider(color: Colors.black12, thickness: 1),
        const SizedBox(height: 8),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text(
          'Tutor Dashboard',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
        ],
      ),

      drawer: AppDrawer(
        username: widget.username,
        email: widget.email,
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTutorScreen()),
          );
        },
        backgroundColor: Colors.blue,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => _runFilter(value),
                      decoration: InputDecoration(
                        hintText: 'Search Tutors or Subjects...',
                        prefixIcon: const Icon(Icons.search, color: Colors.blue),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _searchController.clear();
                            _runFilter('');
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: _openFilterSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: _filters.isEmpty ? Colors.white : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _filters.isEmpty ? Colors.black12 : Colors.blue,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.filter_list,
                            color: _filters.isEmpty ? Colors.black54 : Colors.blue, size: 18),
                        const SizedBox(width: 6),
                        Text('Filter',
                            style: TextStyle(
                                color: _filters.isEmpty ? Colors.black54 : Colors.blue)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          Expanded(child: _buildList()),
        ],
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
    if (_foundTutors.isEmpty) {
      return const Center(child: Text('No Tutors Found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: _foundTutors.length,
      itemBuilder: (context, index) {
        final tutor = _foundTutors[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(color: Colors.blue.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: const Icon(Icons.person, color: Colors.blue, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tutor.name.isNotEmpty ? tutor.name : 'Unknown',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.school_outlined, size: 16, color: Colors.blue),
                        const SizedBox(width: 6),
                        Text(
                          tutor.className,
                          style: TextStyle(
                              color: Colors.grey[700], fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.book_outlined, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            tutor.subject,
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.payments_outlined, size: 16, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          tutor.feeDisplay,
                          style: const TextStyle(
                              color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () => _showTutorDetails(context, tutor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      },
    );
  }
}

class AddTutorScreen extends StatefulWidget {
  const AddTutorScreen({super.key});

  @override
  State<AddTutorScreen> createState() => _AddTutorScreenState();
}

class _AddTutorScreenState extends State<AddTutorScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController classController = TextEditingController();
  final TextEditingController subjectController = TextEditingController();
  final TextEditingController areaController = TextEditingController();
  final TextEditingController feeController = TextEditingController();
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

    final fee = double.tryParse(feeController.text.trim()) ?? 0;

    setState(() => _isSubmitting = true);
    try {
      final profile = await AuthService.instance.fetchProfile(uid);
      await PostService.instance.createPost(
        type: PostType.tutor,
        ownerUid: uid,
        ownerUsername: profile?.username ?? '',
        name: nameController.text.trim(),
        className: classController.text.trim(),
        subject: subjectController.text.trim(),
        area: areaController.text.trim(),
        phone: phoneController.text.trim(),
        institution: institutionController.text.trim(),
        fee: fee,
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
    feeController.dispose();
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
          "Create Tutor Post",
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildInputField(hintText: "Tutor Name", controller: nameController, enabled: !_isSubmitting),
              const SizedBox(height: 15),
              _buildInputField(hintText: "Target Classes", controller: classController, enabled: !_isSubmitting),
              const SizedBox(height: 15),
              _buildInputField(hintText: "Subjects", controller: subjectController, enabled: !_isSubmitting),
              const SizedBox(height: 15),
              _buildInputField(hintText: "Preferred Area", controller: areaController, enabled: !_isSubmitting),
              const SizedBox(height: 15),
              _buildInputField(
                hintText: "Tuition Fee (per month)",
                controller: feeController,
                keyboardType: TextInputType.number,
                enabled: !_isSubmitting,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return "Please enter Tuition Fee";
                  final parsed = double.tryParse(value.trim());
                  if (parsed == null || parsed < 0) return "Enter a valid fee amount";
                  return null;
                },
              ),
              const SizedBox(height: 15),
              _buildInputField(
                hintText: "Phone Number",
                controller: phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_isSubmitting,
              ),
              const SizedBox(height: 15),
              _buildInputField(hintText: "Educational Institution", controller: institutionController, enabled: !_isSubmitting),
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
                        width: 1.0),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                )
                    : const Text(
                  "Submit Post",
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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      validator: validator ??
              (value) {
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
