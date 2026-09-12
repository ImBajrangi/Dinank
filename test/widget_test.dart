import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:birthday_reminder_app/database/db_helper.dart';
import 'package:birthday_reminder_app/models/student_model.dart';
import 'package:birthday_reminder_app/providers/student_provider.dart';
import 'package:birthday_reminder_app/screens/home_dashboard_screen.dart';
import 'package:birthday_reminder_app/screens/import_excel_screen.dart';
import 'package:birthday_reminder_app/screens/settings_screen.dart';
import 'package:birthday_reminder_app/screens/students_list_screen.dart';
import 'package:birthday_reminder_app/services/action_service.dart';
import 'package:birthday_reminder_app/services/excel_service.dart';
import 'package:birthday_reminder_app/widgets/birthday_trend_card.dart';
import 'package:birthday_reminder_app/widgets/stat_badge.dart';
import 'package:birthday_reminder_app/widgets/student_action_card.dart';
import 'package:birthday_reminder_app/widgets/today_celebrants_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  GoogleFonts.config.allowRuntimeFetching = false;

  final methodCallLog = <MethodCall>[];

  setUp(() async {
    methodCallLog.clear();
    final db = await openDatabase(
      inMemoryDatabasePath,
      version: 1,
      onCreate: (db, v) async {
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
      },
    );
    DatabaseHelper.setDatabase(db);

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('com.birthday.teacher/native'),
      (MethodCall call) async {
        methodCallLog.add(call);
        return true;
      },
    );
  });

  group('1. Student Model & Calculations Unit Tests', () {
    test('Calculates turning age and countdown accurately', () {
      final now = DateTime.now();

      final todayStudent = StudentModel(
        name: "Aarav Sharma",
        dob: DateTime(2008, now.month, now.day),
        groupClass: "Class 10-A",
      );

      expect(todayStudent.isBirthdayToday, isTrue);
      expect(todayStudent.daysUntilBirthday, 0);
      expect(todayStudent.countdownText, "Today! 🎂");
      expect(todayStudent.turningAge, now.year - 2008);
      expect(todayStudent.initials, "AS");

      final tomorrow = now.add(const Duration(days: 1));
      final tomorrowStudent = StudentModel(
        name: "Priya Patel",
        dob: DateTime(2009, tomorrow.month, tomorrow.day),
        groupClass: "Class 9-B",
      );

      expect(tomorrowStudent.isBirthdayToday, isFalse);
      expect(tomorrowStudent.daysUntilBirthday, 1);
      expect(tomorrowStudent.countdownText, "Tomorrow 🎉");
      expect(tomorrowStudent.initials, "PP");
    });

    test('Greeting template placeholders formatting with tokens', () {
      final student = StudentModel(
        name: "Rohan Varma",
        rollNo: "42",
        groupClass: "Grade 11-Science",
        dob: DateTime(2007, 4, 15),
      );

      const template = "Dear {name} (Age {age}), congratulations on your birthday from {teacher} in {class}!";
      final formatted = ActionService.formatGreetingTemplate(
        template,
        student,
        teacherName: "Prof. Kulkarni",
      );

      expect(formatted, contains("Dear Rohan Varma"));
      expect(formatted, contains("Prof. Kulkarni"));
      expect(formatted, contains("Grade 11-Science"));
      expect(formatted, contains("Age ${student.turningAge}"));
    });

    test('Parent greeting template formatting', () {
      final student = StudentModel(
        name: "Ananya Roy",
        groupClass: "Class 8-C",
        dob: DateTime(2010, 8, 20),
      );

      const template = "Dear Parents, wishing your child {name} a wonderful {age}th birthday! - {teacher}";
      final formatted = ActionService.formatGreetingTemplate(
        template,
        student,
        teacherName: "Teacher Maria",
      );

      expect(formatted, contains("Ananya Roy"));
      expect(formatted, contains("Teacher Maria"));
    });
  });

  group('2. Excel & CSV Engine Unit Tests', () {
    test('Sample student generator outputs full classroom dataset', () {
      final samples = ExcelService.generateSampleStudents();
      expect(samples.isNotEmpty, isTrue);
      expect(samples.length, greaterThanOrEqualTo(8));
      expect(samples.any((s) => s.isBirthdayToday), isTrue);
      expect(samples.any((s) => s.isBirthdayThisWeek), isTrue);
    });

    test('Header matching algorithm resolves standard variants', () {
      final map1 = ExcelService.detectColumns(["Student Name", "DOB", "Batch"]);
      expect(map1['name'], 0);
      expect(map1['dob'], 1);
      expect(map1['group_class'], 2);

      final map2 = ExcelService.detectColumns(["Full Name", "Date of Birth", "Phone", "Parent Contact"]);
      expect(map2['name'], 0);
      expect(map2['dob'], 1);
      expect(map2['phone'], 2);
      expect(map2['parent_phone'], 3);
    });
  });

  group('3. Provider State & Database Unit Tests', () {
    test('StudentProvider loads demo data and updates categorizations', () async {
      SharedPreferences.setMockInitialValues({});
      final provider = StudentProvider();
      await provider.init();
      expect(provider.allStudents.isEmpty, isTrue);

      await provider.loadDemoData();
      expect(provider.allStudents.length, greaterThanOrEqualTo(8));
      expect(provider.todayBirthdays.isNotEmpty, isTrue);
      expect(provider.classList.isNotEmpty, isTrue);

      // Test Search
      provider.setSearchQuery("Aarav");
      expect(provider.filteredStudents.length, 1);
      expect(provider.filteredStudents.first.name, "Aarav Sharma");

      provider.clearFilters();
      expect(provider.filteredStudents.length, provider.allStudents.length);
    });
  });

  group('4. UI & Widget Component Tests', () {
    testWidgets('Dashboard Screen renders Bento layout & stat badges', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'teacher_name': 'Prof. Jackson',
        'has_prompted_teacher_name': true,
      });
      final provider = StudentProvider();
      await tester.runAsync(() async {
        await provider.init();
        await provider.loadDemoData();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: HomeDashboardScreen(onNavigateTab: (_) {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("BIRTHDAY RADAR"), findsOneWidget);
      expect(find.byType(TodayCelebrantsBanner), findsOneWidget);
      expect(find.byType(StatBadge), findsNWidgets(4));
      expect(find.byType(BirthdayTrendCard), findsOneWidget);
      expect(find.text("7-Day Forecast"), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Students Directory Screen renders list and handles search', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'teacher_name': 'Prof. Jackson',
        'has_prompted_teacher_name': true,
      });
      final provider = StudentProvider();
      await tester.runAsync(() async {
        await provider.init();
        await provider.loadDemoData();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: StudentsListScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Students Directory"), findsOneWidget);
      expect(find.byType(StudentActionCard), findsWidgets);
      expect(find.text("Aarav Sharma"), findsWidgets);

      // Enter search query
      await tester.enterText(find.byType(TextField), "Sneha");
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text("Sneha Patel"), findsWidgets);
      expect(find.text("Aarav Sharma"), findsNothing);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Settings Screen renders templates and triggers test notification', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'teacher_name': 'Prof. Jackson',
        'has_prompted_teacher_name': true,
      });
      final provider = StudentProvider();
      await tester.runAsync(() async {
        await provider.init();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Preferences & Settings"), findsOneWidget);
      expect(find.text("Daily Background Reminder (WorkManager)"), findsOneWidget);

      final notifBtn = find.text("Trigger Instant Test Notification");
      expect(notifBtn, findsOneWidget);
      await tester.tap(notifBtn);
      await tester.pump(const Duration(seconds: 5));

      expect(methodCallLog.isNotEmpty, isTrue);

      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('Import Excel Screen renders supported formats info', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({
        'teacher_name': 'Prof. Jackson',
        'has_prompted_teacher_name': true,
      });
      final provider = StudentProvider();
      await tester.runAsync(() async {
        await provider.init();
      });

      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(
            home: ImportExcelScreen(onImportSuccess: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text("Import & Sync Rosters"), findsOneWidget);
      expect(find.text("Excel / CSV File"), findsOneWidget);
      expect(find.text("Google Sheets Sync"), findsOneWidget);
      expect(find.text("Spreadsheet Column Guide"), findsOneWidget);
      expect(find.text("Select Student Roster File"), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
    });
  });
}
