// lib/verification_screen.dart
import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import 'models/app_user.dart';
import 'models/verification_request.dart';
import 'services/auth_service.dart';
import 'services/verification_service.dart';

/// Lets the signed-in user submit an ID/document for identity verification,
/// and shows the live status of their request (pending, approved, rejected).
class VerificationScreen extends StatefulWidget {
  final AppUser user;

  const VerificationScreen({super.key, required this.user});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  StreamSubscription<VerificationRequest?>? _subscription;
  VerificationRequest? _request;
  bool _loaded = false;

  File? _pickedFile;
  String? _pickedFileName;
  bool _submitting = false;
  bool _opening = false;

  static const List<String> _allowedExtensions = ['pdf', 'jpg', 'jpeg', 'png', 'webp'];

  @override
  void initState() {
    super.initState();
    _subscription = VerificationService.instance
        .watchRequest(widget.user.uid)
        .listen((request) {
      if (!mounted) return;
      setState(() {
        _request = request;
        _loaded = true;
      });
    }, onError: (Object _) {
      if (!mounted) return;
      setState(() => _loaded = true);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
      );
      if (result == null || result.files.single.path == null) return;
      setState(() {
        _pickedFile = File(result.files.single.path!);
        _pickedFileName = result.files.single.name;
      });
    } catch (e) {
      _snack('Could not open the file picker: $e', color: Colors.red);
    }
  }

  Future<void> _submit() async {
    final file = _pickedFile;
    final fileName = _pickedFileName;
    if (file == null || fileName == null) {
      _snack('Please select a document first');
      return;
    }
    if (_submitting) return;

    setState(() => _submitting = true);
    try {
      await VerificationService.instance.submitRequest(
        uid: widget.user.uid,
        username: widget.user.username,
        role: widget.user.role,
        document: file,
        fileName: fileName,
      );
      if (!mounted) return;
      setState(() {
        _pickedFile = null;
        _pickedFileName = null;
      });
      _snack('Verification request submitted', color: Colors.green);
    } on VerificationException catch (e) {
      _snack(e.message, color: Colors.red);
    } catch (_) {
      _snack('Could not submit your request. Please try again.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openSubmittedDocument(VerificationRequest request) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final file = await VerificationService.instance.downloadDocument(request);
      final result = await OpenFilex.open(file.path);
      if (result.type != ResultType.done) {
        _snack('Could not open file: ${result.message}', color: Colors.red);
      }
    } catch (_) {
      _snack('Could not download the document.', color: Colors.red);
    } finally {
      if (mounted) setState(() => _opening = false);
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
    return Scaffold(
      backgroundColor: const Color(0xffF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        centerTitle: true,
        title: const Text(
          'Get Verified',
          style: TextStyle(
              color: Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 20),
            if (_canSubmit()) _buildSubmitCard(),
          ],
        ),
      ),
    );
  }

  bool _canSubmit() {
    final request = _request;
    if (request == null) return true; // never submitted
    return request.isRejected;
  }

  Widget _buildStatusCard() {
    final request = _request;

    final ({String label, String description, Color color, IconData icon}) info;
    if (request == null) {
      info = (
      label: 'Not verified',
      description:
      'Submit a valid ID or certificate so students and tutors know your profile is genuine.',
      color: Colors.grey,
      icon: Icons.shield_outlined,
      );
    } else {
      switch (request.status) {
        case VerificationStatus.approved:
          info = (
          label: 'Verified',
          description: 'Your identity has been verified. No action needed.',
          color: Colors.green,
          icon: Icons.verified,
          );
          break;
        case VerificationStatus.rejected:
          info = (
          label: 'Rejected',
          description: request.rejectionReason.isNotEmpty
              ? request.rejectionReason
              : 'Your request was rejected. Please submit a clearer document.',
          color: Colors.red,
          icon: Icons.cancel_outlined,
          );
          break;
        default:
          info = (
          label: 'Pending review',
          description:
          'Your document was submitted and is waiting for admin review.',
          color: Colors.orange,
          icon: Icons.hourglass_top,
          );
      }
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(info.icon, color: info.color, size: 26),
              const SizedBox(width: 10),
              Text(info.label,
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold, color: info.color)),
            ],
          ),
          const SizedBox(height: 10),
          Text(info.description, style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
          if (request != null && request.documentPath.isNotEmpty) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: _opening ? null : () => _openSubmittedDocument(request),
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Colors.blueAccent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        request.documentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (_opening)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.open_in_new, size: 16, color: Colors.blueAccent),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSubmitCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _request == null ? 'Submit a document' : 'Resubmit a document',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Accepted formats: PDF, JPG, PNG, WEBP. Maximum size 10 MB.',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _submitting ? null : _pickFile,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xffF1F5FA),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _pickedFileName != null ? Colors.blue : Colors.grey,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _pickedFileName ?? 'Select Document',
                      style: TextStyle(
                        color: _pickedFileName != null
                            ? Colors.blue.shade700
                            : Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.upload_file, color: Colors.redAccent),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xff1E88E5),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: _submitting
                  ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
                  : const Text('Submit for Review',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
