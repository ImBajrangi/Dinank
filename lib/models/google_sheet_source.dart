class GoogleSheetSource {
  final int? id;
  final String name;
  final String url;
  final String sheetId;
  final String gid;
  final DateTime? lastSyncedAt;
  final int lastStudentCount;
  final bool autoSync;
  final String? lastError;
  final String? cachedFilePath;

  GoogleSheetSource({
    this.id,
    required this.name,
    required this.url,
    required this.sheetId,
    this.gid = "0",
    this.lastSyncedAt,
    this.lastStudentCount = 0,
    this.autoSync = true,
    this.lastError,
    this.cachedFilePath,
  });

  String get exportCsvUrl {
    return "https://docs.google.com/spreadsheets/d/$sheetId/export?format=csv&gid=$gid";
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'url': url,
      'sheet_id': sheetId,
      'gid': gid,
      'last_synced_at': lastSyncedAt?.toIso8601String(),
      'last_student_count': lastStudentCount,
      'auto_sync': autoSync ? 1 : 0,
      'last_error': lastError,
      'cached_file_path': cachedFilePath,
    };
  }

  factory GoogleSheetSource.fromMap(Map<String, dynamic> map) {
    DateTime? syncedAt;
    if (map['last_synced_at'] != null) {
      try {
        syncedAt = DateTime.parse(map['last_synced_at'].toString());
      } catch (_) {}
    }

    return GoogleSheetSource(
      id: map['id'] as int?,
      name: map['name'] as String? ?? 'Google Sheet',
      url: map['url'] as String? ?? '',
      sheetId: map['sheet_id'] as String? ?? '',
      gid: map['gid'] as String? ?? '0',
      lastSyncedAt: syncedAt,
      lastStudentCount: map['last_student_count'] as int? ?? 0,
      autoSync: (map['auto_sync'] as int? ?? 1) == 1,
      lastError: map['last_error'] as String?,
      cachedFilePath: map['cached_file_path'] as String?,
    );
  }

  GoogleSheetSource copyWith({
    int? id,
    String? name,
    String? url,
    String? sheetId,
    String? gid,
    DateTime? lastSyncedAt,
    int? lastStudentCount,
    bool? autoSync,
    String? lastError,
    String? cachedFilePath,
  }) {
    return GoogleSheetSource(
      id: id ?? this.id,
      name: name ?? this.name,
      url: url ?? this.url,
      sheetId: sheetId ?? this.sheetId,
      gid: gid ?? this.gid,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastStudentCount: lastStudentCount ?? this.lastStudentCount,
      autoSync: autoSync ?? this.autoSync,
      lastError: lastError,
      cachedFilePath: cachedFilePath ?? this.cachedFilePath,
    );
  }
}
