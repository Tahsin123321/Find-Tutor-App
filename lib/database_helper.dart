import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await initDB();
    return _database!;
  }

  Future<Database> initDB() async {
    String path = join(await getDatabasesPath(), 'user.db');

    return await openDatabase(
      path,
      version: 5, // 1. Bumped version to 5 for the new pdf_documents table
      onCreate: (db, version) async {
        // Users Table
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE NOT NULL,
            email TEXT UNIQUE NOT NULL,
            phone TEXT UNIQUE,
            password TEXT NOT NULL,
            role TEXT NOT NULL DEFAULT 'Student'
          )
        ''');

        // 2. Ensure new database installations also create the PDF table
        await db.execute('''
          CREATE TABLE pdf_documents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            file_path TEXT NOT NULL,
            date_added TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _migrateToVersion3(db);
        }
        if (oldVersion < 4) {
          await db.execute("ALTER TABLE users ADD COLUMN role TEXT NOT NULL DEFAULT 'Student'");
        }
        // 3. Upgrade logic for existing users transitioning to version 5
        if (oldVersion < 5) {
          await db.execute('''
            CREATE TABLE pdf_documents (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              file_path TEXT NOT NULL,
              date_added TEXT NOT NULL
            )
          ''');
        }
      },
    );
  }

  // Older migration: handles creating new structural unique constraints
  Future<void> _migrateToVersion3(Database db) async {
    await db.execute("ALTER TABLE users RENAME TO users_old");

    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        phone TEXT UNIQUE,
        password TEXT NOT NULL
      )
    ''');

    await db.execute('''
      INSERT INTO users (id, username, email, phone, password)
      SELECT id, email, email, NULL, password FROM users_old
    ''');

    await db.execute("DROP TABLE users_old");
  }

  // ==========================================
  // NEW METHODS FOR HANDLING PDF STORAGE
  // ==========================================

  // Insert a record mapping a PDF name to its saved path
  Future<int> insertPdfRecord(String title, String filePath) async {
    final db = await database;
    return await db.insert('pdf_documents', {
      'title': title,
      'file_path': filePath,
      'date_added': DateTime.now().toIso8601String(),
    });
  }

  // Fetch all saved PDFs
  Future<List<Map<String, dynamic>>> fetchAllPdfs() async {
    final db = await database;
    return await db.query('pdf_documents', orderBy: 'date_added DESC');
  }

  // ==========================================
  // EXISTING AUTHENTICATION METHODS
  // ==========================================

  Future<int> signup(
      String username,
      String email,
      String phone,
      String password,
      String role,
      ) async {
    final db = await database;

    try {
      return await db.insert('users', {
        'username': username.trim(),
        'email': email.trim(),
        'phone': phone.trim().isEmpty ? null : phone.trim(),
        'password': password,
        'role': role,
      });
    } catch (e) {
      if (e.toString().contains('UNIQUE constraint failed')) {
        throw Exception('Username or Email already exists');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserData(String email, String password) async {
    final db = await database;

    var result = await db.query(
      'users',
      where: "email = ? AND password = ?",
      whereArgs: [email.trim(), password],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  Future<Map<String, dynamic>?> getUserDataWithUsername(String username, String password) async {
    final db = await database;

    var result = await db.query(
      'users',
      where: "username = ? AND password = ?",
      whereArgs: [username.trim(), password],
    );

    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }
}