import 'package:flutter_test/flutter_test.dart';
import 'package:birthday_reminder_app/models/google_sheet_source.dart';
import 'package:birthday_reminder_app/services/google_sheet_service.dart';

void main() {
  group('GoogleSheetService URL Parsing Tests', () {
    test('Parses standard Google Sheets share link', () {
      const url = 'https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit?usp=sharing';
      final res = GoogleSheetService.parseSheetUrl(url);

      expect(res, isNotNull);
      expect(res!.sheetId, equals('1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms'));
      expect(res.gid, equals('0'));
      expect(res.isPublishedLink, isFalse);
    });

    test('Parses Google Sheets share link with specific gid', () {
      const url = 'https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit#gid=1982736450';
      final res = GoogleSheetService.parseSheetUrl(url);

      expect(res, isNotNull);
      expect(res!.sheetId, equals('1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms'));
      expect(res.gid, equals('1982736450'));
    });

    test('Parses published web Google Sheets link', () {
      const url = 'https://docs.google.com/spreadsheets/d/e/2PACX-1vTCG8LhZ-8y6e8f4r3w/pubhtml';
      final res = GoogleSheetService.parseSheetUrl(url);

      expect(res, isNotNull);
      expect(res!.sheetId, equals('2PACX-1vTCG8LhZ-8y6e8f4r3w'));
      expect(res.isPublishedLink, isTrue);
    });

    test('GoogleSheetSource toMap and fromMap serialization', () {
      final now = DateTime(2026, 9, 12, 10, 30);
      final source = GoogleSheetSource(
        id: 1,
        name: 'Class 10-A',
        url: 'https://docs.google.com/spreadsheets/d/12345/edit',
        sheetId: '12345',
        gid: '0',
        lastSyncedAt: now,
        lastStudentCount: 42,
        autoSync: true,
      );

      final map = source.toMap();
      final restored = GoogleSheetSource.fromMap(map);

      expect(restored.id, equals(1));
      expect(restored.name, equals('Class 10-A'));
      expect(restored.sheetId, equals('12345'));
      expect(restored.lastStudentCount, equals(42));
      expect(restored.autoSync, isTrue);
      expect(restored.exportCsvUrl, equals('https://docs.google.com/spreadsheets/d/12345/export?format=csv&gid=0'));
    });
  });
}
