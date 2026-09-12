import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/db_helper.dart';
import '../models/student_model.dart';
import '../models/google_sheet_source.dart';
import '../services/excel_service.dart';
import '../services/google_sheet_service.dart';
import '../services/native_bridge_service.dart';

class StudentProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<StudentModel> _allStudents = [];
  List<String> _classList = [];
  List<GoogleSheetSource> _sheetSources = [];
  bool _isLoading = false;
  bool _isSyncingSheets = false;
  String _searchQuery = '';
  String? _selectedClassFilter;
  int? _selectedMonthFilter;

  // Teacher Profile & Custom Greetings
  String _teacherName = "";
  bool _hasPromptedTeacherName = false;
  String _defaultTemplate = "Dear *{name}*, wishing you a very *Happy Birthday!* 🎂 May this year bring you wisdom, great success, and joy. Keep shining in *{class}*! 🎉\n\nBest regards,\n*{teacher_name}*";
  String _parentTemplate = "Dear Parent, heartfelt congratulations on *{name}*'s birthday today! 💐 Wishing your child a glorious year ahead filled with good health and academic excellence.\n\nWarm regards,\n*{teacher_name}* (*{class}*)";
  int _notificationHour = 8;
  int _notificationMinute = 0;
  bool _isNotificationEnabled = true;

  // Getters
  bool get isLoading => _isLoading;
  bool get isSyncingSheets => _isSyncingSheets;
  List<StudentModel> get allStudents => _allStudents;
  List<String> get classList => _classList;
  List<GoogleSheetSource> get sheetSources => _sheetSources;
  String get searchQuery => _searchQuery;
  String? get selectedClassFilter => _selectedClassFilter;
  int? get selectedMonthFilter => _selectedMonthFilter;
  String get teacherName => _teacherName;
  bool get hasSetTeacherName => _teacherName.trim().isNotEmpty;
  bool get hasPromptedTeacherName => _hasPromptedTeacherName;
  bool get shouldPromptTeacherName => !_hasPromptedTeacherName && _teacherName.trim().isEmpty;
  String get defaultTemplate => _defaultTemplate;
  String get parentTemplate => _parentTemplate;
  int get notificationHour => _notificationHour;
  int get notificationMinute => _notificationMinute;
  bool get isNotificationEnabled => _isNotificationEnabled;

  // Fast In-Memory Categorized Birthday Lists
  List<StudentModel> get todayBirthdays {
    return _allStudents.where((s) => s.isBirthdayToday).toList();
  }

  List<StudentModel> get upcomingWeekBirthdays {
    return _allStudents.where((s) {
      final days = s.daysUntilBirthday;
      return days > 0 && days <= 7;
    }).toList()
      ..sort((a, b) => a.daysUntilBirthday.compareTo(b.daysUntilBirthday));
  }

  List<StudentModel> get upcomingMonthBirthdays {
    return _allStudents.where((s) {
      final days = s.daysUntilBirthday;
      return days > 7 && days <= 30;
    }).toList()
      ..sort((a, b) => a.daysUntilBirthday.compareTo(b.daysUntilBirthday));
  }

  List<StudentModel> get filteredStudents {
    return _allStudents.where((student) {
      // Search filter
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchName = student.name.toLowerCase().contains(q);
        final matchRoll = student.rollNo?.toLowerCase().contains(q) ?? false;
        final matchClass = student.groupClass?.toLowerCase().contains(q) ?? false;
        final matchPhone = student.phone?.contains(q) ?? false;
        final matchNotes = student.notes?.toLowerCase().contains(q) ?? false;

        if (!matchName && !matchRoll && !matchClass && !matchPhone && !matchNotes) {
          return false;
        }
      }

      // Class filter
      if (_selectedClassFilter != null && _selectedClassFilter!.isNotEmpty) {
        if (student.groupClass != _selectedClassFilter) return false;
      }

      // Month filter
      if (_selectedMonthFilter != null) {
        if (student.dob.month != _selectedMonthFilter) return false;
      }

      return true;
    }).toList();
  }

  // Initialize and load
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    await _loadPreferences();
    await loadAllStudents();

    if (_isNotificationEnabled) {
      await NativeBridgeService.scheduleDailyWorker(
        hour: _notificationHour,
        minute: _notificationMinute,
      );
      await checkAndNotifyTodayBirthdays();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _hasPromptedTeacherName = prefs.getBool('has_prompted_teacher_name') ?? false;
    _teacherName = prefs.getString('teacher_name') ?? "";

    final rawDefault = prefs.getString('default_template');
    final rawParent = prefs.getString('parent_template');

    // Upgrade legacy unformatted templates if detected
    if (rawDefault == null || rawDefault.isEmpty || !rawDefault.contains('*')) {
      _defaultTemplate = "Dear *{name}*, wishing you a very *Happy Birthday!* 🎂 May this year bring you wisdom, great success, and joy. Keep shining in *{class}*! 🎉\n\nBest regards,\n*{teacher_name}*";
    } else {
      _defaultTemplate = rawDefault;
    }

    if (rawParent == null || rawParent.isEmpty || !rawParent.contains('*')) {
      _parentTemplate = "Dear Parent, heartfelt congratulations on *{name}*'s birthday today! 💐 Wishing your child a glorious year ahead filled with good health and academic excellence.\n\nWarm regards,\n*{teacher_name}* (*{class}*)";
    } else {
      _parentTemplate = rawParent;
    }

    _notificationHour = prefs.getInt('notification_hour') ?? 8;
    _notificationMinute = prefs.getInt('notification_minute') ?? 0;
    _isNotificationEnabled = prefs.getBool('notification_enabled') ?? true;
  }

  Future<void> updateTeacherName(String name) async {
    _teacherName = name.trim();
    _hasPromptedTeacherName = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_name', _teacherName);
    await prefs.setBool('has_prompted_teacher_name', true);
    notifyListeners();
  }

  Future<void> markTeacherNamePrompted() async {
    if (_hasPromptedTeacherName) return;
    _hasPromptedTeacherName = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_prompted_teacher_name', true);
    notifyListeners();
  }

  Future<void> savePreferences({
    required String teacherName,
    required String defaultTemplate,
    required String parentTemplate,
    required int notificationHour,
    required int notificationMinute,
    required bool isNotificationEnabled,
  }) async {
    _teacherName = teacherName;
    _hasPromptedTeacherName = true;
    _defaultTemplate = defaultTemplate;
    _parentTemplate = parentTemplate;
    _notificationHour = notificationHour;
    _notificationMinute = notificationMinute;
    _isNotificationEnabled = isNotificationEnabled;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('teacher_name', teacherName);
    await prefs.setBool('has_prompted_teacher_name', true);
    await prefs.setString('default_template', defaultTemplate);
    await prefs.setString('parent_template', parentTemplate);
    await prefs.setInt('notification_hour', notificationHour);
    await prefs.setInt('notification_minute', notificationMinute);
    await prefs.setBool('notification_enabled', isNotificationEnabled);

    if (isNotificationEnabled) {
      await NativeBridgeService.scheduleDailyWorker(
        hour: notificationHour,
        minute: notificationMinute,
      );
      await checkAndNotifyTodayBirthdays(force: true);
    } else {
      await NativeBridgeService.cancelDailyWorker();
    }

    notifyListeners();
  }

  Future<void> loadAllStudents({bool triggerAutoSync = false}) async {
    _allStudents = await _dbHelper.getAllStudents();
    _classList = await _dbHelper.getDistinctClasses();
    _sheetSources = await _dbHelper.getAllGoogleSheetSources();
    notifyListeners();

    if (triggerAutoSync && _sheetSources.any((s) => s.autoSync)) {
      syncAllGoogleSheets(showLoading: false);
    }
  }

  Future<void> loadSheetSources() async {
    _sheetSources = await _dbHelper.getAllGoogleSheetSources();
    notifyListeners();
  }

  /// Checks if any students have a birthday today and fires a native reminder
  Future<bool> checkAndNotifyTodayBirthdays({bool force = false}) async {
    if (!_isNotificationEnabled) return false;
    final today = todayBirthdays;
    if (today.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final todayKey = "notified_${DateTime.now().year}_${DateTime.now().month}_${DateTime.now().day}";
    final alreadyNotified = prefs.getBool(todayKey) ?? false;

    if (force || !alreadyNotified) {
      final names = today.map((s) => s.name).toList();
      final details = today.map((s) {
        final classInfo = (s.groupClass != null && s.groupClass!.isNotEmpty) ? " (${s.groupClass})" : "";
        final rollInfo = (s.rollNo != null && s.rollNo!.isNotEmpty) ? " [#${s.rollNo}]" : "";
        return "${s.name}$classInfo$rollInfo - Turning ${s.turningAge} yrs";
      }).toList();

      final success = await NativeBridgeService.notifyBirthdayStudents(
        names: names,
        details: details,
      );

      if (success && !force) {
        await prefs.setBool(todayKey, true);
      }
      return success;
    }
    return true;
  }

  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    notifyListeners();
  }

  void setClassFilter(String? className) {
    _selectedClassFilter = className;
    notifyListeners();
  }

  void setMonthFilter(int? month) {
    _selectedMonthFilter = month;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedClassFilter = null;
    _selectedMonthFilter = null;
    notifyListeners();
  }

  Future<void> addStudent(StudentModel student) async {
    final id = await _dbHelper.insertStudent(student);
    final newStudent = student.copyWith(id: id);
    _allStudents.add(newStudent);
    _allStudents.sort((a, b) => a.name.compareTo(b.name));
    _classList = await _dbHelper.getDistinctClasses();
    notifyListeners();
  }

  Future<void> updateStudent(StudentModel student) async {
    await _dbHelper.updateStudent(student);
    final index = _allStudents.indexWhere((s) => s.id == student.id);
    if (index != -1) {
      _allStudents[index] = student;
      _allStudents.sort((a, b) => a.name.compareTo(b.name));
    }
    _classList = await _dbHelper.getDistinctClasses();
    notifyListeners();
  }

  Future<void> deleteStudent(int id) async {
    await _dbHelper.deleteStudent(id);
    _allStudents.removeWhere((s) => s.id == id);
    _classList = await _dbHelper.getDistinctClasses();
    notifyListeners();
  }

  Future<int> importStudents(List<StudentModel> students) async {
    _isLoading = true;
    notifyListeners();

    await _dbHelper.insertBatchStudents(students);
    await loadAllStudents();

    _isLoading = false;
    notifyListeners();
    return students.length;
  }

  Future<void> loadDemoData() async {
    _isLoading = true;
    notifyListeners();

    final samples = ExcelService.generateSampleStudents();
    await _dbHelper.insertBatchStudents(samples);
    await loadAllStudents();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> clearAllData() async {
    _isLoading = true;
    notifyListeners();

    await _dbHelper.deleteAllStudents();
    _allStudents.clear();
    _classList.clear();

    _isLoading = false;
    notifyListeners();
  }

  String exportToCsvString() {
    final buffer = StringBuffer();
    buffer.writeln("Roll No,Student Name,Class/Batch,Date of Birth,Phone,Parent Phone,Email,Notes");
    for (final s in _allStudents) {
      final roll = '"${s.rollNo ?? ''}"';
      final name = '"${s.name.replaceAll('"', '""')}"';
      final group = '"${s.groupClass ?? ''}"';
      final dob = '"${s.dob.toIso8601String().split('T').first}"';
      final phone = '"${s.phone ?? ''}"';
      final parentPhone = '"${s.parentPhone ?? ''}"';
      final email = '"${s.email ?? ''}"';
      final notes = '"${(s.notes ?? '').replaceAll('"', '""')}"';
      buffer.writeln("$roll,$name,$group,$dob,$phone,$parentPhone,$email,$notes");
    }
    return buffer.toString();
  }

  // ----------------------------------------------------
  // Google Sheets Cloud Sync Methods
  // ----------------------------------------------------

  Future<(bool, String?)> addGoogleSheet({
    required String name,
    required String url,
  }) async {
    _isSyncingSheets = true;
    notifyListeners();

    try {
      final (source, students, error) = await GoogleSheetService.addAndSyncNewSource(
        name: name,
        url: url,
      );

      await loadAllStudents();
      _isSyncingSheets = false;
      notifyListeners();

      if (error != null) {
        return (false, error);
      }
      return (true, null);
    } catch (e) {
      _isSyncingSheets = false;
      notifyListeners();
      return (false, e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<(bool, String?)> syncGoogleSheet(int sourceId) async {
    _isSyncingSheets = true;
    notifyListeners();

    try {
      final source = await _dbHelper.getGoogleSheetSourceById(sourceId);
      if (source == null) {
        _isSyncingSheets = false;
        notifyListeners();
        return (false, "Google Sheet source not found.");
      }

      final result = await GoogleSheetService.syncSource(source);
      await loadAllStudents();

      _isSyncingSheets = false;
      notifyListeners();

      if (!result.success) {
        return (false, result.errorMessage);
      }
      return (true, null);
    } catch (e) {
      _isSyncingSheets = false;
      notifyListeners();
      return (false, e.toString().replaceAll("Exception: ", ""));
    }
  }

  Future<int> syncAllGoogleSheets({bool showLoading = true}) async {
    if (showLoading) {
      _isSyncingSheets = true;
      notifyListeners();
    }

    int syncedCount = 0;
    try {
      final sources = await _dbHelper.getAllGoogleSheetSources();
      for (final src in sources) {
        if (src.autoSync) {
          final res = await GoogleSheetService.syncSource(src);
          if (res.success) {
            syncedCount += res.students.length;
          }
        }
      }
      await loadAllStudents();
    } catch (_) {}

    if (showLoading) {
      _isSyncingSheets = false;
      notifyListeners();
    }
    return syncedCount;
  }

  Future<void> deleteGoogleSheet(int sourceId, {bool deleteStudents = true}) async {
    await _dbHelper.deleteGoogleSheetSource(sourceId, deleteStudents: deleteStudents);
    await loadAllStudents();
  }

  Future<void> toggleSheetAutoSync(int sourceId, bool enabled) async {
    final source = await _dbHelper.getGoogleSheetSourceById(sourceId);
    if (source != null) {
      final updated = source.copyWith(autoSync: enabled);
      await _dbHelper.updateGoogleSheetSource(updated);
      await loadSheetSources();
    }
  }
}
