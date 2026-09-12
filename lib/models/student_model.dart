import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StudentModel {
  final int? id;
  final String name;
  final String? rollNo;
  final String? groupClass;
  final String? phone;
  final String? parentPhone;
  final String? email;
  final DateTime dob;
  final String? notes;
  final int? dobMonth;
  final int dobDay;
  final String? avatarColorHex;
  final int? sourceSheetId;

  StudentModel({
    this.id,
    required this.name,
    this.rollNo,
    this.groupClass,
    this.phone,
    this.parentPhone,
    this.email,
    required this.dob,
    this.notes,
    int? dobMonth,
    int? dobDay,
    this.avatarColorHex,
    this.sourceSheetId,
  })  : dobMonth = dobMonth ?? dob.month,
        dobDay = dobDay ?? dob.day;

  // Computed properties
  int get ageThisYear {
    final now = DateTime.now();
    int age = now.year - dob.year;
    return age > 0 ? age : 0;
  }

  int get turningAge {
    final now = DateTime.now();
    final birthdayThisYear = DateTime(now.year, dob.month, dob.day);
    if (birthdayThisYear.isBefore(DateTime(now.year, now.month, now.day))) {
      return now.year - dob.year + 1;
    }
    return now.year - dob.year;
  }

  int get daysUntilBirthday {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime nextBirthday = DateTime(now.year, dob.month, dob.day);

    if (nextBirthday.isBefore(today)) {
      nextBirthday = DateTime(now.year + 1, dob.month, dob.day);
    }
    return nextBirthday.difference(today).inDays;
  }

  bool get isBirthdayToday {
    final now = DateTime.now();
    return dob.month == now.month && dob.day == now.day;
  }

  bool get isBirthdayThisWeek {
    final days = daysUntilBirthday;
    return days >= 0 && days <= 7;
  }

  String get formattedDob {
    return DateFormat('dd MMM yyyy').format(dob);
  }

  String get formattedBirthdayDayMonth {
    return DateFormat('dd MMMM').format(dob);
  }

  String get countdownText {
    final days = daysUntilBirthday;
    if (days == 0) return "Today! 🎂";
    if (days == 1) return "Tomorrow 🎉";
    return "In $days days";
  }

  Color get avatarColor {
    if (avatarColorHex != null && avatarColorHex!.isNotEmpty) {
      try {
        final hex = avatarColorHex!.replaceAll('#', '');
        return Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }
    // Deterministic palette generation based on name
    final palette = [
      const Color(0xFF6366F1), // Indigo
      const Color(0xFF8B5CF6), // Purple
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF43F5E), // Rose
      const Color(0xFFF97316), // Orange
      const Color(0xFF10B981), // Emerald
      const Color(0xFF06B6D4), // Cyan
      const Color(0xFF3B82F6), // Blue
      const Color(0xFF14B8A6), // Teal
      const Color(0xFFA855F7), // Violet
    ];
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    return palette[hash % palette.length];
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts[0].isEmpty) return "S";
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length >= 2 ? 2 : 1).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'roll_no': rollNo,
      'group_class': groupClass,
      'phone': phone,
      'parent_phone': parentPhone,
      'email': email,
      'dob': dob.toIso8601String(),
      'dob_month': dobMonth,
      'dob_day': dobDay,
      'notes': notes,
      'avatar_color': avatarColorHex,
      'source_sheet_id': sourceSheetId,
    };
  }

  factory StudentModel.fromMap(Map<String, dynamic> map) {
    DateTime parsedDob;
    try {
      parsedDob = DateTime.parse(map['dob'].toString());
    } catch (_) {
      parsedDob = DateTime(2000, map['dob_month'] ?? 1, map['dob_day'] ?? 1);
    }

    return StudentModel(
      id: map['id'] as int?,
      name: (map['name'] as String?)?.trim() ?? 'Unknown Student',
      rollNo: map['roll_no'] as String?,
      groupClass: map['group_class'] as String?,
      phone: map['phone'] as String?,
      parentPhone: map['parent_phone'] as String?,
      email: map['email'] as String?,
      dob: parsedDob,
      dobMonth: map['dob_month'] as int? ?? parsedDob.month,
      dobDay: map['dob_day'] as int? ?? parsedDob.day,
      notes: map['notes'] as String?,
      avatarColorHex: map['avatar_color'] as String?,
      sourceSheetId: map['source_sheet_id'] as int?,
    );
  }

  StudentModel copyWith({
    int? id,
    String? name,
    String? rollNo,
    String? groupClass,
    String? phone,
    String? parentPhone,
    String? email,
    DateTime? dob,
    String? notes,
    String? avatarColorHex,
    int? sourceSheetId,
  }) {
    return StudentModel(
      id: id ?? this.id,
      name: name ?? this.name,
      rollNo: rollNo ?? this.rollNo,
      groupClass: groupClass ?? this.groupClass,
      phone: phone ?? this.phone,
      parentPhone: parentPhone ?? this.parentPhone,
      email: email ?? this.email,
      dob: dob ?? this.dob,
      notes: notes ?? this.notes,
      avatarColorHex: avatarColorHex ?? this.avatarColorHex,
      sourceSheetId: sourceSheetId ?? this.sourceSheetId,
    );
  }
}
