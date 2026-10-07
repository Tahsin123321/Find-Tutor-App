import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'database_helper.dart';

class PdfService {
  // Reusable helper to save a file permanently to App Documents Directory
  static Future<File> saveFilePermanently(String sourcePath, String fileName) async {
    final appStorageDir = await getApplicationDocumentsDirectory();
    final targetPath = p.join(appStorageDir.path, fileName);
    return File(sourcePath).copy(targetPath);
  }

  // Your original method for PdfListScreen
  Future<void> pickAndSavePdf() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      String fileName = result.files.single.name;

      // Use the helper method here
      File savedFile = await saveFilePermanently(result.files.single.path!, fileName);

      await DatabaseHelper().insertPdfRecord(fileName, savedFile.path);
    }
  }
}