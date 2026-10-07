// data_repository.dart
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DataRepository {
  // --- Student Data Arrays ---
  static List<Map<String, dynamic>> studentRequests = [];
  static List<Map<String, dynamic>> verifiedStudents = [];

  // --- New Tutor Data Arrays ---
  static List<Map<String, dynamic>> tutorRequests = [];
  static List<Map<String, dynamic>> verifiedTutors = [];

  // Call this function in your main.dart before runApp() to load saved data!
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Prepare a real sample file in local storage for mock data fallback
    String samplePdfPath = await _createMockPdfFileIfNeeded();

    // ==========================================
    // 1. LOAD STUDENT DATA
    // ==========================================
    final String? requestsRaw = prefs.getString('student_requests');
    if (requestsRaw != null) {
      final List<dynamic> decoded = jsonDecode(requestsRaw);
      studentRequests = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      // Assigned samplePdfPath instead of an empty string for seamless out-of-the-box UI testing
      studentRequests = [
        {
          "name": "Arif Rahman",
          "details": "Needs Help in Math (Class 9)",
          "time": "2 hours ago",
          "pdfPath": samplePdfPath,
          "pdfName": "Math_Syllabus.pdf"
        },
        {
          "name": "Sadia Islam",
          "details": "Looking for Chemistry Tutor (Class 12)",
          "time": "5 hours ago",
          "pdfPath": samplePdfPath,
          "pdfName": "Chemistry_Requirements.pdf"
        },
      ];
    }

    final String? verifiedRaw = prefs.getString('verified_students');
    if (verifiedRaw != null) {
      final List<dynamic> decoded = jsonDecode(verifiedRaw);
      verifiedStudents = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      verifiedStudents = [
        {"name": "Rahim Ahmed", "class": "Class 10", "subject": "Mathematics"},
        {"name": "Karim Hasan", "class": "Class 9", "subject": "Physics"},
        {"name": "Nusrat Jahan", "class": "Class 8", "subject": "English"},
        {"name": "Sabbir Hossain", "class": "Class 7", "subject": "Science"},
        {"name": "Mim Akter", "class": "Class 6", "subject": "ICT"},
      ];
    }

    // ==========================================
    // 2. LOAD TUTOR DATA
    // ==========================================
    final String? tutorRequestsRaw = prefs.getString('tutor_requests');
    if (tutorRequestsRaw != null) {
      final List<dynamic> decoded = jsonDecode(tutorRequestsRaw);
      tutorRequests = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      tutorRequests = [
        {
          "name": "Mehedi Hasan",
          "details": "Class: Class 11 - 12 | Subject: Math\nArea: Mirpur\nPhone: 01712345678",
          "time": "1 hour ago",
          "pdfPath": samplePdfPath,
          "pdfName": "CV.pdf"
        },
      ];
    }

    final String? verifiedTutorsRaw = prefs.getString('verified_tutors');
    if (verifiedTutorsRaw != null) {
      final List<dynamic> decoded = jsonDecode(verifiedTutorsRaw);
      verifiedTutors = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      verifiedTutors = [
        {"name": "Sharif Uddin", "class": "Class 11 - 12", "subjects": "ICT, Software Engineering", "isAvailable": true},
        {"name": "Suresh Sinha", "class": "Class 9 - 10", "subjects": "Mathematics, Higher Math", "isAvailable": true},
        {"name": "Ishita Rao", "class": "Class 6 - 8", "subjects": "General Science, English", "isAvailable": false},
        {"name": "Suraj Mallik", "class": "Class 11 - 12", "subjects": "Physics, Chemistry", "isAvailable": true},
        {"name": "Aarav Mehta", "class": "Class 9 - 10", "subjects": "Biology, General Science", "isAvailable": true},
        {"name": "Priya Deshmukh", "class": "Class 1 - 5", "subjects": "All Subjects", "isAvailable": false},
        {"name": "Rohan Bhatia", "class": "Class 11 - 12", "subjects": "Accounting, Finance", "isAvailable": true},
        {"name": "Ananya Sen", "class": "Class 9 - 10", "subjects": "English Literature, Grammar", "isAvailable": true},
        {"name": "Zayan Ahmed", "class": "Class 6 - 8", "subjects": "Mathematics, BGS", "isAvailable": true},
        {"name": "Nabila Islam", "class": "Class 11 - 12", "subjects": "Chemistry, Biology", "isAvailable": false},
        {"name": "Asif Rahman", "class": "Class 9 - 10", "subjects": "Physics, Higher Math", "isAvailable": true},
        {"name": "Tanvir Hasan", "class": "Class 6 - 8", "subjects": "English, ICT", "isAvailable": true},
      ];
    }
  }

  // Helper method to save current memory arrays down to persistence disk storage
  static Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();

    // Save student collections
    await prefs.setString('student_requests', jsonEncode(studentRequests));
    await prefs.setString('verified_students', jsonEncode(verifiedStudents));

    // Save tutor collections
    await prefs.setString('tutor_requests', jsonEncode(tutorRequests));
    await prefs.setString('verified_tutors', jsonEncode(verifiedTutors));
  }

  /// Generates a simple text file renamed as a .pdf inside app storage.
  /// This prevents OpenFilex from failing due to empty string paths during initial testing.
  static Future<String> _createMockPdfFileIfNeeded() async {
    try {
      final appStorageDir = await getApplicationDocumentsDirectory();
      final file = File(p.join(appStorageDir.path, 'Mock_Verification_Document.pdf'));

      if (!await file.exists()) {
        // Creates a dummy file so OpenFilex points to an actual physical storage entity
        await file.writeAsString("Mock verification file content generated for system demonstration.");
      }
      return file.path;
    } catch (e) {
      print("Error creating fallback mock file: $e");
      return "";
    }
  }
}