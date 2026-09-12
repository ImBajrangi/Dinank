import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/student_model.dart';
import '../models/google_sheet_source.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  static void setDatabase(Database? db) {
    _database = db;
  }

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDB('birthdays.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDB,
      onUpgrade: _onUpgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE students (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        roll_no TEXT,
        group_class TEXT,
        phone TEXT,
        parent_phone TEXT,
        email TEXT,
        dob TEXT NOT NULL,
        dob_month INTEGER NOT NULL,
        dob_day INTEGER NOT NULL,
        notes TEXT,
        avatar_color TEXT,
        source_sheet_id INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE google_sheet_sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        url TEXT NOT NULL,
        sheet_id TEXT NOT NULL,
        gid TEXT NOT NULL,
        last_synced_at TEXT,
        last_student_count INTEGER NOT NULL DEFAULT 0,
        auto_sync INTEGER NOT NULL DEFAULT 1,
        last_error TEXT,
        cached_file_path TEXT
      )
    ''');

    await db.execute('CREATE INDEX idx_dob_month_day ON students (dob_month, dob_day)');
    await db.execute('CREATE INDEX idx_group_class ON students (group_class)');
    await db.execute('CREATE INDEX idx_name ON students (name)');
    await db.execute('CREATE INDEX idx_source_sheet_id ON students (source_sheet_id)');
  }

  Future<void> _onUpgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add source_sheet_id column to students if not exists
      try {
        await db.execute('ALTER TABLE students ADD COLUMN source_sheet_id INTEGER');
      } catch (_) {}

      // Create google_sheet_sources table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS google_sheet_sources (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          url TEXT NOT NULL,
          sheet_id TEXT NOT NULL,
          gid TEXT NOT NULL,
          last_synced_at TEXT,
          last_student_count INTEGER NOT NULL DEFAULT 0,
          auto_sync INTEGER NOT NULL DEFAULT 1,
          last_error TEXT,
          cached_file_path TEXT
        )
      ''');

      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_source_sheet_id ON students (source_sheet_id)');
      } catch (_) {}
    }
  }

  Future<int> insertStudent(StudentModel student) async {
    final db = await database;
    return await db.insert('students', student.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<int>> insertBatchStudents(List<StudentModel> students) async {
    final db = await database;
    final List<int> ids = [];
    final batch = db.batch();
    for (final student in students) {
      batch.insert('students', student.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    }
    final results = await batch.commit(noResult: false);
    for (final r in results) {
      if (r is int) ids.add(r);
    }
    return ids;
  }

  Future<int> updateStudent(StudentModel student) async {
    final db = await database;
    return await db.update(
      'students',
      student.toMap(),
      where: 'id = ?',
      whereArgs: [student.id],
    );
  }

  Future<int> deleteStudent(int id) async {
    final db = await database;
    return await db.delete(
      'students',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteAllStudents() async {
    final db = await database;
    return await db.delete('students');
  }

  Future<List<StudentModel>> getAllStudents() async {
    final db = await database;
    final result = await db.query(
      'students',
      orderBy: 'name ASC',
    );
    return result.map((json) => StudentModel.fromMap(json)).toList();
  }

  Future<List<StudentModel>> getTodayBirthdays(int month, int day) async {
    final db = await database;
    final result = await db.query(
      'students',
      where: 'dob_month = ? AND dob_day = ?',
      whereArgs: [month, day],
      orderBy: 'name ASC',
    );
    return result.map((json) => StudentModel.fromMap(json)).toList();
  }

  Future<List<String>> getDistinctClasses() async {
    final db = await database;
    final result = await db.rawQuery(
      "SELECT DISTINCT group_class FROM students WHERE group_class IS NOT NULL AND group_class != '' ORDER BY group_class ASC",
    );
    return result.map((row) => row['group_class'] as String).toList();
  }

  Future<int> getStudentCount() async {
    final db = await database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM students'));
    return count ?? 0;
  }

  // ----------------------------------------------------
  // Google Sheet Sources CRUD & Sync Management
  // ----------------------------------------------------

  Future<int> insertGoogleSheetSource(GoogleSheetSource source) async {
    final db = await database;
    return await db.insert('google_sheet_sources', source.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> updateGoogleSheetSource(GoogleSheetSource source) async {
    final db = await database;
    return await db.update(
      'google_sheet_sources',
      source.toMap(),
      where: 'id = ?',
      whereArgs: [source.id],
    );
  }

  Future<int> deleteGoogleSheetSource(int id, {bool deleteStudents = true}) async {
    final db = await database;
    if (deleteStudents) {
      await db.delete('students', where: 'source_sheet_id = ?', whereArgs: [id]);
    } else {
      // Unlink students so they remain in app as local entries
      await db.rawUpdate('UPDATE students SET source_sheet_id = NULL WHERE source_sheet_id = ?', [id]);
    }
    return await db.delete('google_sheet_sources', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<GoogleSheetSource>> getAllGoogleSheetSources() async {
    final db = await database;
    final result = await db.query('google_sheet_sources', orderBy: 'id ASC');
    return result.map((json) => GoogleSheetSource.fromMap(json)).toList();
  }

  Future<GoogleSheetSource?> getGoogleSheetSourceById(int id) async {
    final db = await database;
    final result = await db.query('google_sheet_sources', where: 'id = ?', whereArgs: [id], limit: 1);
    if (result.isEmpty) return null;
    return GoogleSheetSource.fromMap(result.first);
  }

  /// Atomically replaces all students linked to a Google Sheet source
  Future<List<int>> replaceStudentsForSheet(int sourceSheetId, List<StudentModel> students) async {
    final db = await database;
    return await db.transaction((txn) async {
      // 1. Delete previous records from this specific source sheet
      await txn.delete('students', where: 'source_sheet_id = ?', whereArgs: [sourceSheetId]);

      // 2. Insert new batch tagged with this source_sheet_id
      final List<int> insertedIds = [];
      final batch = txn.batch();
      for (final student in students) {
        final taggedStudent = student.copyWith(sourceSheetId: sourceSheetId);
        batch.insert('students', taggedStudent.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
      final results = await batch.commit(noResult: false);
      for (final r in results) {
        if (r is int) insertedIds.add(r);
      }
      return insertedIds;
    });
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
