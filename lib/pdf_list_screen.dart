import 'package:flutter/material.dart';
import 'database_helper.dart';
import 'package:open_filex/open_filex.dart'; // Make sure to add open_filex: ^4.5.0 to pubspec

class PdfListScreen extends StatefulWidget {
  @override
  _PdfListScreenState createState() => _PdfListScreenState();
}

class _PdfListScreenState extends State<PdfListScreen> {
  final dbHelper = DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("My Saved PDFs")),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        // Calls the method we added in Step 2
        future: dbHelper.fetchAllPdfs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text("Error loading PDFs"));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text("No PDFs saved yet."));
          }

          final pdfList = snapshot.data!;

          return ListView.builder(
            itemCount: pdfList.length,
            itemBuilder: (context, index) {
              final pdfItem = pdfList[index];

              return ListTile(
                leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(pdfItem['title']),
                subtitle: Text("Added: ${pdfItem['date_added'].toString().substring(0, 10)}"),
                onTap: () {
                  // Part B: Handle Opening the PDF when tapped
                  _openPdfFile(pdfItem['file_path']);
                },
              );
            },
          );
        },
      ),
    );
  }

  // Part B: The Opening Engine
  void _openPdfFile(String filePath) async {
    // OpenFilex automatically detects it's a PDF and hands it off
    // to the Android/iOS native default PDF viewer.
    final result = await OpenFilex.open(filePath);
    print("Open file status: ${result.message}");
  }
}