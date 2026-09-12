import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';
import '../services/action_service.dart';
import '../services/toast_service.dart';

class TodayCelebrantsBanner extends StatelessWidget {
  const TodayCelebrantsBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<StudentProvider>(context);
    final todayList = provider.todayBirthdays;
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, dd MMMM').format(now);

    if (todayList.isEmpty) {
      final nextCelebrant = provider.upcomingWeekBirthdays.isNotEmpty
          ? provider.upcomingWeekBirthdays.first
          : (provider.upcomingMonthBirthdays.isNotEmpty ? provider.upcomingMonthBirthdays.first : null);

      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.school_rounded, color: Colors.white70, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      dateStr,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "Daily Radar",
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "No Student Birthdays Today",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nextCelebrant != null
                  ? "Next birthday: ${nextCelebrant.name} (${nextCelebrant.groupClass ?? ''}) in ${nextCelebrant.daysUntilBirthday} days on ${nextCelebrant.formattedBirthdayDayMonth}."
                  : "Upload your classroom roster (.xlsx, .csv) to track and celebrate all birthdays!",
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF831843), Color(0xFFBE185D), Color(0xFFEC4899)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEC4899).withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 8),
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
                    const Icon(Icons.cake_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "TODAY'S CELEBRATIONS",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () async {
                  final ok = await provider.checkAndNotifyTodayBirthdays(force: true);
                  if (context.mounted) {
                    if (ok) {
                      AppToast.showInfo(
                        context,
                        title: "System Notification Dispatched",
                        message: "Birthday alert pushed to Android notification tray!",
                        icon: Icons.notifications_active_rounded,
                        badgeTag: "SYSTEM ALERT",
                      );
                    } else {
                      AppToast.showError(
                        context,
                        title: "Notification Failed",
                        message: "Please ensure notification permissions are enabled in Android settings.",
                      );
                    }
                  }
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        "${todayList.length} ${todayList.length == 1 ? 'Student' : 'Students'}",
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            todayList.length == 1
                ? "Today is ${todayList.first.name}'s Birthday!"
                : "${todayList.length} Students are Celebrating Today!",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Send them your blessings and best wishes on behalf of the faculty.",
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          // Horizontal list of today's celebrants
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: todayList.length,
              separatorBuilder: (ctx, i) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final student = todayList[i];
                return _buildCelebrantPill(context, student, provider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCelebrantPill(BuildContext context, StudentModel student, StudentProvider provider) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white,
            child: Text(
              student.initials,
              style: const TextStyle(color: Color(0xFFBE185D), fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  student.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  "${student.groupClass ?? ''} • ${student.turningAge} yrs",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(4),
            tooltip: "Send WhatsApp Wish",
            onPressed: () {
              ActionService.sendWhatsAppWish(
                student,
                template: provider.defaultTemplate,
                teacherName: provider.teacherName,
                context: context,
              );
            },
          ),
        ],
      ),
    );
  }
}
