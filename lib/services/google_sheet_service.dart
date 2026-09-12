import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../database/db_helper.dart';
import '../models/google_sheet_source.dart';
import '../models/student_model.dart';
import 'excel_service.dart';

class SheetUrlParseResult {
  final String sheetId;
  final String gid;
  final String suggestedName;
  final bool isPublishedLink;

  const SheetUrlParseResult({
    required this.sheetId,
    required this.gid,
    required this.suggestedName,
    this.isPublishedLink = false,
  });
}

class GoogleSheetSyncResult {
  final bool success;
  final GoogleSheetSource source;
  final List<StudentModel> students;
  final String? errorMessage;

  const GoogleSheetSyncResult({
    required this.success,
    required this.source,
    required this.students,
    this.errorMessage,
  });
}

class GoogleSheetService {
  /// Parse any standard or published Google Sheet link into sheetId, gid, and name
  static SheetUrlParseResult? parseSheetUrl(String rawInput) {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    // Pattern 1: Published to web URL https://docs.google.com/spreadsheets/d/e/{ID}/pub...
    final pubMatch = RegExp(r'/spreadsheets/d/e/([a-zA-Z0-9-_]+)').firstMatch(trimmed);
    if (pubMatch != null) {
      final pubId = pubMatch.group(1)!;
      final gidMatch = RegExp(r'[#&?]gid=([0-9]+)').firstMatch(trimmed);
      final gid = gidMatch != null ? gidMatch.group(1)! : "0";

      return SheetUrlParseResult(
        sheetId: pubId,
        gid: gid,
        suggestedName: "Published Cloud Roster",
        isPublishedLink: true,
      );
    }

    // Pattern 2: Standard URL https://docs.google.com/spreadsheets/d/{ID}/edit...
    final standardMatch = RegExp(r'/spreadsheets/d/([a-zA-Z0-9-_]+)').firstMatch(trimmed);
    if (standardMatch != null) {
      final sheetId = standardMatch.group(1)!;
      final gidMatch = RegExp(r'[#&?]gid=([0-9]+)').firstMatch(trimmed);
      final gid = gidMatch != null ? gidMatch.group(1)! : "0";

      return SheetUrlParseResult(
        sheetId: sheetId,
        gid: gid,
        suggestedName: "Google Sheet Roster",
        isPublishedLink: false,
      );
    }

    // Pattern 3: Raw Sheet ID (e.g. 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms)
    if (RegExp(r'^[a-zA-Z0-9-_]{20,}$').hasMatch(trimmed)) {
      return SheetUrlParseResult(
        sheetId: trimmed,
        gid: "0",
        suggestedName: "Google Sheet Roster",
        isPublishedLink: false,
      );
    }

    return null;
  }

  /// Get cache directory for offline Google Sheet rosters
  static Future<Directory> getSheetCacheDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory(p.join(docsDir.path, 'google_sheet_cache'));
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Fetch CSV bytes from Google Sheet with redirect following and safety checks
  static Future<Uint8List> fetchCsvBytes(GoogleSheetSource source) async {
    final String exportUrl;
    if (source.url.contains('/spreadsheets/d/e/')) {
      exportUrl = "https://docs.google.com/spreadsheets/d/e/${source.sheetId}/pub?output=csv&gid=${source.gid}";
    } else {
      exportUrl = "https://docs.google.com/spreadsheets/d/${source.sheetId}/export?format=csv&gid=${source.gid}";
    }

    final response = await http.get(
      Uri.parse(exportUrl),
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; StudentBirthdayReminderApp/1.0)',
        'Accept': 'text/csv,text/plain,*/*',
      },
    ).timeout(const Duration(seconds: 18));

    if (response.statusCode != 200) {
      if (response.statusCode == 404) {
        throw Exception("Sheet not found. Please check your Google Sheet link.");
      } else if (response.statusCode == 403 || response.statusCode == 401) {
        throw Exception("Access restricted: Please set Google Sheet sharing to 'Anyone with the link can view'.");
      } else {
        throw Exception("Failed to fetch sheet (HTTP ${response.statusCode}).");
      }
    }

    final bodyBytes = response.bodyBytes;
    final prefixCheck = utf8.decode(bodyBytes.take(200).toList(), allowMalformed: true).toLowerCase();

    // Check if Google returned an HTML login or permission denied page
    if (prefixCheck.contains('<!doctype html') || prefixCheck.contains('<html') || prefixCheck.contains('accounts.google.com')) {
      throw Exception("Access restricted: Please set Google Sheet sharing to 'Anyone with the link can view' (Viewer permission).");
    }

    return bodyBytes;
  }

  /// Synchronize a single Google Sheet source into local database + cache
  static Future<GoogleSheetSyncResult> syncSource(GoogleSheetSource source) async {
    final dbHelper = DatabaseHelper.instance;
    try {
      Uint8List bytes;
      String? cachedPath = source.cachedFilePath;

      try {
        bytes = await fetchCsvBytes(source);

        // Cache bytes to permanent storage for offline launch
        final cacheDir = await getSheetCacheDirectory();
        final localFile = File(p.join(cacheDir.path, 'sheet_${source.sheetId}_${source.gid}.csv'));
        await localFile.writeAsBytes(bytes);
        cachedPath = localFile.path;
      } catch (networkError) {
        // If network failed but we have a cached copy, parse cached version
        if (cachedPath != null && await File(cachedPath).exists()) {
          bytes = await File(cachedPath).readAsBytes();
        } else {
          rethrow;
        }
      }

      // Parse CSV
      final (parsedStudents, _) = ExcelService.parseCsvBytesWithDetails(bytes);
      if (parsedStudents.isEmpty) {
        throw Exception("No student records found in sheet. Make sure columns like 'Student Name' and 'DOB' are included.");
      }

      // Update database atomically
      if (source.id != null) {
        await dbHelper.replaceStudentsForSheet(source.id!, parsedStudents);
      }

      final updatedSource = source.copyWith(
        lastSyncedAt: DateTime.now(),
        lastStudentCount: parsedStudents.length,
        lastError: null,
        cachedFilePath: cachedPath,
      );

      if (source.id != null) {
        await dbHelper.updateGoogleSheetSource(updatedSource);
      }

      return GoogleSheetSyncResult(
        success: true,
        source: updatedSource,
        students: parsedStudents,
      );
    } catch (e) {
      final errorMsg = e.toString().replaceAll("Exception: ", "");
      final failedSource = source.copyWith(lastError: errorMsg);
      if (source.id != null) {
        await dbHelper.updateGoogleSheetSource(failedSource);
      }

      return GoogleSheetSyncResult(
        success: false,
        source: failedSource,
        students: [],
        errorMessage: errorMsg,
      );
    }
  }

  /// Create and immediately sync a new Google Sheet source
  static Future<(GoogleSheetSource?, List<StudentModel>, String?)> addAndSyncNewSource({
    required String name,
    required String url,
  }) async {
    final parseResult = parseSheetUrl(url);
    if (parseResult == null) {
      return (null, <StudentModel>[], "Invalid Google Sheet link. Please copy the full share link from Google Sheets.");
    }

    final dbHelper = DatabaseHelper.instance;
    final initialSource = GoogleSheetSource(
      name: name.trim().isEmpty ? parseResult.suggestedName : name.trim(),
      url: url.trim(),
      sheetId: parseResult.sheetId,
      gid: parseResult.gid,
    );

    // Insert to DB to get assigned ID
    final sourceId = await dbHelper.insertGoogleSheetSource(initialSource);
    final sourceWithId = initialSource.copyWith(id: sourceId);

    // Perform first sync
    final syncResult = await syncSource(sourceWithId);

    if (!syncResult.success) {
      return (syncResult.source, <StudentModel>[], syncResult.errorMessage);
    }

    return (syncResult.source, syncResult.students, null);
  }
}
