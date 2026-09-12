import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/student_model.dart';

class BirthdayTrendCard extends StatelessWidget {
  final List<StudentModel> students;

  const BirthdayTrendCard({super.key, required this.students});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Calculate birthday counts for the next 7 days
    final now = DateTime.now();
    final weekDayCounts = <int, int>{};
    for (int i = 0; i < 7; i++) {
      weekDayCounts[i] = 0;
    }

    for (final s in students) {
      final days = s.daysUntilBirthday;
      if (days >= 0 && days < 7) {
        weekDayCounts[days] = (weekDayCounts[days] ?? 0) + 1;
      }
    }

    final maxCount = weekDayCounts.values.fold<int>(1, (prev, curr) => curr > prev ? curr : prev);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00D2B4).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bar_chart_rounded, color: Color(0xFF00D2B4), size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "7-Day Forecast",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D2B4).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up_rounded, size: 14, color: Color(0xFF0D9488)),
                    const SizedBox(width: 4),
                    Text(
                      "Radar",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF0D9488),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Mini Chart Bars
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(7, (index) {
              final dayDate = now.add(Duration(days: index));
              final dayName = index == 0 ? "Today" : DateFormat('E').format(dayDate);
              final count = weekDayCounts[index] ?? 0;
              final isToday = index == 0;
              final barHeightRatio = (count / maxCount).clamp(0.18, 1.0);

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (count > 0)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isToday ? const Color(0xFFEC4899) : const Color(0xFF00D2B4),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        count.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    const SizedBox(height: 20),
                  // Animated pill bar
                  Container(
                    width: 24,
                    height: 60 * barHeightRatio,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isToday
                            ? [const Color(0xFFF43F5E), const Color(0xFFEC4899)]
                            : (count > 0
                                ? [const Color(0xFF06B6D4), const Color(0xFF00D2B4)]
                                : [
                                    isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0),
                                    isDark ? const Color(0xFF1E283C) : const Color(0xFFF1F5F9),
                                  ]),
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dayName,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: isToday
                          ? (isDark ? const Color(0xFFEC4899) : const Color(0xFFBE185D))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
