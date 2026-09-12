import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/student_model.dart';

class RosterColumnDefinition {
  final String name;
  final String fieldKey;
  final bool isRequired;
  final String purpose;
  final String example;
  final String formatHint;
  final List<String> recognizedHeaders;

  const RosterColumnDefinition({
    required this.name,
    required this.fieldKey,
    required this.isRequired,
    required this.purpose,
    required this.example,
    required this.formatHint,
    required this.recognizedHeaders,
  });
}

class ExcelParseResult {
  final String fileName;
  final int fileSize;
  final String? savedFilePath;
  final Uint8List rawBytes;
  final List<StudentModel> students;
  final Map<String, int> detectedColumns;

  const ExcelParseResult({
    required this.fileName,
    required this.fileSize,
    this.savedFilePath,
    required this.rawBytes,
    required this.students,
    required this.detectedColumns,
  });
}

class ExcelService {
  /// Standard Application Column Definitions for teachers and professors
  static const List<RosterColumnDefinition> applicationColumns = [
    RosterColumnDefinition(
      name: "Student Name",
      fieldKey: "name",
      isRequired: true,
      purpose: "Used in greeting templates, birthday notifications, and student profile cards.",
      example: "Aarav Sharma",
      formatHint: "Plain text full name (e.g. John Doe, Aarav Sharma)",
      recognizedHeaders: ["name", "student name", "fullname", "student_name", "student", "candidatename"],
    ),
    RosterColumnDefinition(
      name: "Date of Birth (DOB)",
      fieldKey: "dob",
      isRequired: true,
      purpose: "Calculates birthday countdowns, turning age, and daily alert triggers.",
      example: "12/09/2004",
      formatHint: "DD/MM/YYYY, YYYY-MM-DD, DD-MM-YYYY, or Excel date numbers",
      recognizedHeaders: ["dob", "date of birth", "birth date", "birthday", "birth_date", "bday"],
    ),
    RosterColumnDefinition(
      name: "Class / Batch",
      fieldKey: "group_class",
      isRequired: false,
      purpose: "Used for batch filtering (e.g. BCA - DS, BCA - AIML) and custom batch greetings.",
      example: "BCA - DS",
      formatHint: "Course, Grade, Batch, or Department name",
      recognizedHeaders: ["class", "batch", "section", "grade", "course", "group_class", "dept"],
    ),
    RosterColumnDefinition(
      name: "Roll No / Student ID",
      fieldKey: "roll_no",
      isRequired: false,
      purpose: "Unique classroom identification and indexed search.",
      example: "BCA-DS-01",
      formatHint: "Alphanumeric ID or roll index",
      recognizedHeaders: ["roll no", "roll", "id", "student id", "reg no", "roll_no", "enrollmentno"],
    ),
    RosterColumnDefinition(
      name: "Student Phone",
      fieldKey: "phone",
      isRequired: false,
      purpose: "Enables 1-tap WhatsApp birthday wishes directly to the student.",
      example: "+91 98765 43210",
      formatHint: "Mobile number with or without country code",
      recognizedHeaders: ["phone", "mobile", "contact", "student phone", "whatsapp", "student_phone"],
    ),
    RosterColumnDefinition(
      name: "Parent Phone",
      fieldKey: "parent_phone",
      isRequired: false,
      purpose: "Enables 1-tap WhatsApp greetings directly to parents / guardians.",
      example: "+91 98765 00001",
      formatHint: "Parent / guardian mobile contact number",
      recognizedHeaders: ["parent phone", "parent contact", "guardian phone", "father phone", "mother phone", "parent_phone"],
    ),
    RosterColumnDefinition(
      name: "Student Email",
      fieldKey: "email",
      isRequired: false,
      purpose: "Contact record and roster backup export.",
      example: "aarav.ds@college.edu",
      formatHint: "Standard email address (user@domain.com)",
      recognizedHeaders: ["email", "mail", "student email", "email_address"],
    ),
    RosterColumnDefinition(
      name: "Teacher Notes / Remarks",
      fieldKey: "notes",
      isRequired: false,
      purpose: "Private remarks, project leads, or achievements visible only to you.",
      example: "Class representative, Data Science project lead",
      formatHint: "Freeform text notes",
      recognizedHeaders: ["notes", "remarks", "comments", "specialization", "teacher_notes"],
    ),
  ];

  /// Get the app's persistent storage directory for imported files
  static Future<Directory> getRosterStorageDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final rosterDir = Directory(p.join(docsDir.path, 'imported_rosters'));
    if (!await rosterDir.exists()) {
      await rosterDir.create(recursive: true);
    }
    return rosterDir;
  }

  /// Save uploaded spreadsheet file into app's persistent documents directory
  static Future<String> saveFileToAppStorage(String fileName, Uint8List bytes) async {
    final rosterDir = await getRosterStorageDirectory();
    final cleanFileName = fileName.replaceAll(RegExp(r'[^\w\.\-]'), '_');
    final targetPath = p.join(rosterDir.path, '${DateTime.now().millisecondsSinceEpoch}_$cleanFileName');
    final file = File(targetPath);
    await file.writeAsBytes(bytes);
    return targetPath;
  }

  /// Pick an Excel or CSV file, save it to app storage, and parse student data
  static Future<ExcelParseResult?> pickAndParseFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
      );

      if (result.isEmpty) {
        return null;
      }

      final file = result.first;
      final bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception("Selected file is empty or could not be read.");
      }

      // Save file permanently in app storage
      final savedPath = await saveFileToAppStorage(file.name, bytes);

      final extension = (file.extension ?? '').toLowerCase();
      List<StudentModel> students;
      Map<String, int> detectedCols;

      if (extension == 'csv') {
        final parsed = parseCsvBytesWithDetails(bytes);
        students = parsed.$1;
        detectedCols = parsed.$2;
      } else {
        final parsed = parseExcelBytesWithDetails(bytes);
        students = parsed.$1;
        detectedCols = parsed.$2;
      }

      return ExcelParseResult(
        fileName: file.name,
        fileSize: bytes.length,
        savedFilePath: savedPath,
        rawBytes: bytes,
        students: students,
        detectedColumns: detectedCols,
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Parse CSV bytes and return students + detected column map
  static (List<StudentModel>, Map<String, int>) parseCsvBytesWithDetails(Uint8List bytes) {
    String csvString;
    try {
      csvString = utf8.decode(bytes);
    } catch (_) {
      csvString = latin1.decode(bytes);
    }

    final decoder = const CsvDecoder();
    final rows = decoder.convert(csvString);

    if (rows.isEmpty) return (<StudentModel>[], <String, int>{});

    final headerRow = rows.first.map((e) => e.toString().trim()).toList();
    final columnMap = detectColumns(headerRow);

    final List<StudentModel> students = [];

    for (int i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((c) => c == null || c.toString().trim().isEmpty)) {
        continue;
      }

      final student = _mapRowToStudent(row, columnMap);
      if (student != null) {
        students.add(student);
      }
    }

    return (students, columnMap);
  }

  /// Parse Excel bytes and return students + detected column map
  static (List<StudentModel>, Map<String, int>) parseExcelBytesWithDetails(Uint8List bytes) {
    final excel = xl.Excel.decodeBytes(bytes);
    final List<StudentModel> students = [];
    Map<String, int> columnMap = {};

    for (final table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.maxRows == 0) continue;

      final rows = sheet.rows;
      if (rows.isEmpty) continue;

      // Extract header strings
      final headerRow = rows.first.map((cell) => cell?.value?.toString().trim() ?? '').toList();
      columnMap = detectColumns(headerRow);

      for (int i = 1; i < rows.length; i++) {
        final rowCells = rows[i];
        if (rowCells.isEmpty) continue;

        final rawRow = rowCells.map((c) => c?.value).toList();
        if (rawRow.every((c) => c == null || c.toString().trim().isEmpty)) continue;

        final student = _mapExcelRowToStudent(rawRow, columnMap);
        if (student != null) {
          students.add(student);
        }
      }

      if (students.isNotEmpty) {
        break; // Process primary populated sheet
      }
    }

    return (students, columnMap);
  }

  static List<StudentModel> parseCsvBytes(Uint8List bytes) => parseCsvBytesWithDetails(bytes).$1;
  static List<StudentModel> parseExcelBytes(Uint8List bytes) => parseExcelBytesWithDetails(bytes).$1;

  static Map<String, int> detectColumns(List<String> headers) {
    final Map<String, int> map = {};

    for (int i = 0; i < headers.length; i++) {
      final h = headers[i].toLowerCase().replaceAll(RegExp(r'[\s_\.\-]+'), '');

      if (map['name'] == null && (h.contains('studentname') || h == 'name' || h == 'fullname' || h == 'student' || h == 'candidatename')) {
        map['name'] = i;
      } else if (map['dob'] == null && (h.contains('dob') || h.contains('birth') || h.contains('dateofbirth') || h == 'bday')) {
        map['dob'] = i;
      } else if (map['roll_no'] == null && (h.contains('roll') || h == 'id' || h == 'studentid' || h == 'regno' || h == 'enrollmentno')) {
        map['roll_no'] = i;
      } else if (map['group_class'] == null && (h.contains('class') || h.contains('batch') || h.contains('grade') || h.contains('section') || h.contains('dept') || h == 'course')) {
        map['group_class'] = i;
      } else if (map['parent_phone'] == null && (h.contains('parent') || h.contains('father') || h.contains('mother') || h.contains('guardian'))) {
        map['parent_phone'] = i;
      } else if (map['phone'] == null && (h.contains('phone') || h.contains('mobile') || h.contains('contact') || h.contains('cell') || h.contains('whatsapp'))) {
        map['phone'] = i;
      } else if (map['email'] == null && (h.contains('email') || h.contains('mail'))) {
        map['email'] = i;
      } else if (map['notes'] == null && (h.contains('note') || h.contains('remark') || h.contains('comment') || h.contains('specialization'))) {
        map['notes'] = i;
      }
    }

    // Fallbacks if not detected by exact keywords:
    if (map['name'] == null && headers.isNotEmpty) map['name'] = 0;
    if (map['dob'] == null && headers.length > 1) map['dob'] = 1;

    return map;
  }

  static StudentModel? _mapRowToStudent(List<dynamic> row, Map<String, int> colMap) {
    final nameIdx = colMap['name'];
    final dobIdx = colMap['dob'];

    if (nameIdx == null || nameIdx >= row.length) return null;
    final name = row[nameIdx]?.toString().trim() ?? '';
    if (name.isEmpty) return null;

    DateTime? dob;
    if (dobIdx != null && dobIdx < row.length) {
      dob = _parseDateValue(row[dobIdx]);
    }

    dob ??= DateTime(2005, 1, 1);

    final rollNo = _getValue(row, colMap['roll_no']);
    final groupClass = _getValue(row, colMap['group_class']);
    final phone = _cleanPhoneNumber(_getValue(row, colMap['phone']));
    final parentPhone = _cleanPhoneNumber(_getValue(row, colMap['parent_phone']));
    final email = _getValue(row, colMap['email']);
    final notes = _getValue(row, colMap['notes']);

    return StudentModel(
      name: name,
      dob: dob,
      rollNo: rollNo,
      groupClass: groupClass,
      phone: phone,
      parentPhone: parentPhone,
      email: email,
      notes: notes,
    );
  }

  static StudentModel? _mapExcelRowToStudent(List<dynamic> row, Map<String, int> colMap) {
    final nameIdx = colMap['name'];
    final dobIdx = colMap['dob'];

    if (nameIdx == null || nameIdx >= row.length) return null;
    final name = row[nameIdx]?.toString().trim() ?? '';
    if (name.isEmpty) return null;

    DateTime? dob;
    if (dobIdx != null && dobIdx < row.length) {
      dob = _parseDateValue(row[dobIdx]);
    }

    dob ??= DateTime(2005, 1, 1);

    final rollNo = _getValue(row, colMap['roll_no']);
    final groupClass = _getValue(row, colMap['group_class']);
    final phone = _cleanPhoneNumber(_getValue(row, colMap['phone']));
    final parentPhone = _cleanPhoneNumber(_getValue(row, colMap['parent_phone']));
    final email = _getValue(row, colMap['email']);
    final notes = _getValue(row, colMap['notes']);

    return StudentModel(
      name: name,
      dob: dob,
      rollNo: rollNo,
      groupClass: groupClass,
      phone: phone,
      parentPhone: parentPhone,
      email: email,
      notes: notes,
    );
  }

  static String? _getValue(List<dynamic> row, int? index) {
    if (index == null || index >= row.length) return null;
    final val = row[index]?.toString().trim();
    return (val == null || val.isEmpty) ? null : val;
  }

  static String? _cleanPhoneNumber(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'[^0-9+]'), '');
    return digits.isEmpty ? null : digits;
  }

  static DateTime? _parseDateValue(dynamic val) {
    if (val == null) return null;

    if (val is DateTime) return val;

    // Check if Excel serial date number
    if (val is num) {
      return DateTime(1899, 12, 30).add(Duration(days: val.toInt()));
    }

    final str = val.toString().trim();
    if (str.isEmpty) return null;

    try {
      return DateTime.parse(str);
    } catch (_) {}

    final formats = [
      'dd/MM/yyyy',
      'MM/dd/yyyy',
      'dd-MM-yyyy',
      'MM-dd-yyyy',
      'yyyy/MM/dd',
      'yyyy.MM.dd',
      'dd.MM.yyyy',
      'd MMM yyyy',
      'dd MMM yyyy',
      'MMMM d, yyyy',
      'd/M/yyyy',
      'd-M-yyyy',
    ];

    for (final fmt in formats) {
      try {
        final parsed = DateFormat(fmt).parseLoose(str);
        return parsed;
      } catch (_) {}
    }

    return null;
  }

  /// Dynamically generates a real .xlsx Excel file for BCA - DS & BCA - AIML
  static Uint8List generateSampleExcelBytes() {
    final xlDoc = xl.Excel.createExcel();
    const sheetName = "Students_Roster";
    xlDoc.rename("Sheet1", sheetName);
    final sheet = xlDoc[sheetName];

    final headers = [
      "Roll No",
      "Student Name",
      "Class / Batch",
      "Date of Birth (DD/MM/YYYY)",
      "Student Phone",
      "Parent Phone",
      "Email",
      "Notes",
    ];

    sheet.appendRow(headers.map((h) => xl.TextCellValue(h)).toList());

    final now = DateTime.now();
    final sampleRows = [
      ["BCA-DS-01", "Aarav Sharma", "BCA - DS", "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/2004", "+919876543210", "+919876500001", "aarav.ds@college.edu", "Class representative, Data Science project lead"],
      ["BCA-AIML-04", "Ananya Iyer", "BCA - AIML", "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/2004", "+919876543211", "+919876500002", "ananya.ai@college.edu", "AI Club coordinator & NLP researcher"],
      ["BCA-DS-12", "Rohan Verma", "BCA - DS", "${((now.day + 1 > 28) ? 1 : now.day + 1).toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/2004", "+919876543212", "+919876500003", "rohan.ds@college.edu", "Python & Big Data analytics specialist"],
      ["BCA-AIML-18", "Sneha Patel", "BCA - AIML", "${((now.day + 3 > 28) ? 2 : now.day + 3).toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/2004", "+919876543213", "+919876500004", "sneha.ai@college.edu", "Deep Learning & Computer Vision team"],
      ["BCA-DS-27", "Vikram Malhotra", "BCA - DS", "${((now.day + 6 > 28) ? 3 : now.day + 6).toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/2003", "+919876543214", "+919876500005", "vikram.ds@college.edu", "Database & Cloud Architecture intern"],
      ["BCA-AIML-31", "Pooja Reddy", "BCA - AIML", "15/${((now.month % 12) + 1).toString().padLeft(2, '0')}/2004", "+919876543215", "+919876500006", "pooja.ai@college.edu", "Hackathon winner in Neural Networks"],
      ["BCA-DS-35", "Devendra Mehta", "BCA - DS", "24/08/2004", "+919876543216", "+919876500007", "devendra.ds@college.edu", "Data Visualization & Tableau specialist"],
      ["BCA-AIML-42", "Meera Nair", "BCA - AIML", "12/11/2003", "+919876543217", "+919876500008", "meera.ai@college.edu", "Reinforcement Learning researcher"],
    ];

    for (final row in sampleRows) {
      sheet.appendRow(row.map((cell) => xl.TextCellValue(cell)).toList());
    }

    final bytes = xlDoc.encode();
    return Uint8List.fromList(bytes ?? []);
  }

  /// Dynamically generates a real .csv file string for BCA - DS & BCA - AIML
  static String generateSampleCsvString() {
    final now = DateTime.now();
    final buffer = StringBuffer();
    buffer.writeln("Roll No,Student Name,Class / Batch,Date of Birth,Student Phone,Parent Phone,Email,Notes");
    buffer.writeln('BCA-DS-01,"Aarav Sharma",BCA - DS,${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/2004,+919876543210,+919876500001,aarav.ds@college.edu,"Class representative, Data Science project lead"');
    buffer.writeln('BCA-AIML-04,"Ananya Iyer",BCA - AIML,${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/2004,+919876543211,+919876500002,ananya.ai@college.edu,"AI Club coordinator & NLP researcher"');
    buffer.writeln('BCA-DS-12,"Rohan Verma",BCA - DS,${((now.day + 1 > 28) ? 1 : now.day + 1).toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/2004,+919876543212,+919876500003,rohan.ds@college.edu,"Python & Big Data analytics specialist"');
    buffer.writeln('BCA-AIML-18,"Sneha Patel",BCA - AIML,${((now.day + 3 > 28) ? 2 : now.day + 3).toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/2004,+919876543213,+919876500004,sneha.ai@college.edu,"Deep Learning & Computer Vision team"');
    buffer.writeln('BCA-DS-27,"Vikram Malhotra",BCA - DS,${((now.day + 6 > 28) ? 3 : now.day + 6).toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/2003,+919876543214,+919876500005,vikram.ds@college.edu,"Database & Cloud Architecture intern"');
    buffer.writeln('BCA-AIML-31,"Pooja Reddy",BCA - AIML,15/${((now.month % 12) + 1).toString().padLeft(2, '0')}/2004,+919876543215,+919876500006,pooja.ai@college.edu,"Hackathon winner in Neural Networks"');
    buffer.writeln('BCA-DS-35,"Devendra Mehta",BCA - DS,24/08/2004,+919876543216,+919876500007,devendra.ds@college.edu,"Data Visualization & Tableau specialist"');
    buffer.writeln('BCA-AIML-42,"Meera Nair",BCA - AIML,12/11/2003,+919876543217,+919876500008,meera.ai@college.edu,"Reinforcement Learning researcher"');
    return buffer.toString();
  }

  /// Exports / Shares a clean classroom template file (.xlsx or .csv) for the teacher to fill
  static Future<void> exportClassroomTemplate({bool isExcel = true}) async {
    final tempDir = await getTemporaryDirectory();
    final fileName = isExcel ? "Classroom_Birthday_Roster_Template.xlsx" : "Classroom_Birthday_Roster_Template.csv";
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);

    if (isExcel) {
      final bytes = generateSampleExcelBytes();
      await file.writeAsBytes(bytes);
    } else {
      final csvString = generateSampleCsvString();
      await file.writeAsString(csvString);
    }

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(filePath)],
        subject: fileName,
        text: "Here is the official Classroom Birthday Roster Template. Open in Microsoft Excel, Google Sheets, or Apple Numbers to enter student records.",
      ),
    );
  }

  /// Load real trial spreadsheet dataset via file parser
  static Future<ExcelParseResult> loadTrialDatasetResult() async {
    final bytes = generateSampleExcelBytes();
    const fileName = "Trial_BCA_Classroom_Roster.xlsx";
    final savedPath = await saveFileToAppStorage(fileName, bytes);
    final parsed = parseExcelBytesWithDetails(bytes);

    return ExcelParseResult(
      fileName: fileName,
      fileSize: bytes.length,
      savedFilePath: savedPath,
      rawBytes: bytes,
      students: parsed.$1,
      detectedColumns: parsed.$2,
    );
  }

  /// Helper for backwards compatibility
  static List<StudentModel> generateSampleStudents() {
    final bytes = generateSampleExcelBytes();
    return parseExcelBytes(bytes);
  }
}
