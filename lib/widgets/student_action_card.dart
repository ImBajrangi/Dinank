import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';
import '../services/action_service.dart';
import '../services/toast_service.dart';
import 'student_edit_dialog.dart';

class StudentActionCard extends StatelessWidget {
  final StudentModel student;
  final bool isFeaturedToday;

  const StudentActionCard({
    super.key,
    required this.student,
    this.isFeaturedToday = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<StudentProvider>(context, listen: false);
    final isToday = student.isBirthdayToday;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isToday
            ? (isDark ? const Color(0xFF2C243B) : const Color(0xFFFDF2F8))
            : (isDark ? const Color(0xFF1E2638) : Colors.white),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isToday
              ? const Color(0xFFEC4899).withValues(alpha: 0.6)
              : (isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0)),
          width: isToday ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isToday
                ? const Color(0xFFEC4899).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showStudentDetails(context, student, provider),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar with initials
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            student.avatarColor,
                            student.avatarColor.withValues(alpha: 0.75),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: student.avatarColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        student.initials,
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Name and info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  student.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                              if (student.rollNo != null && student.rollNo!.isNotEmpty) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2B354C) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    "#${student.rollNo}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (student.groupClass != null && student.groupClass!.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    student.groupClass!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6366F1),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  "🎂 ${student.formattedBirthdayDayMonth} (${student.turningAge} yrs)",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Countdown badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: isToday
                            ? const Color(0xFFEC4899)
                            : (student.isBirthdayThisWeek
                                ? const Color(0xFFF59E0B)
                                : (isDark ? const Color(0xFF2B354C) : const Color(0xFFE2E8F0))),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        student.countdownText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: (isToday || student.isBirthdayThisWeek)
                              ? Colors.white
                              : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
                        ),
                      ),
                    ),
                  ],
                ),
                if (student.notes != null && student.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF131B2A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "📝 ${student.notes!}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Action Buttons Row
                Row(
                  children: [
                    // WhatsApp Wish to Student
                    Expanded(
                      child: _buildActionButton(
                        context: context,
                        icon: Icons.chat_bubble_rounded,
                        label: "Wish Student",
                        color: const Color(0xFF25D366),
                        onTap: () => ActionService.sendWhatsAppWish(
                          student,
                          template: provider.defaultTemplate,
                          teacherName: provider.teacherName,
                          context: context,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Call Student
                    if (student.phone != null && student.phone!.isNotEmpty) ...[
                      _buildIconButton(
                        icon: Icons.phone_rounded,
                        color: const Color(0xFF0284C7),
                        tooltip: "Call ${student.name}",
                        onTap: () => ActionService.makePhoneCall(student.phone, context: context),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // WhatsApp to Parent
                    if (student.parentPhone != null && student.parentPhone!.isNotEmpty) ...[
                      _buildIconButton(
                        icon: Icons.family_restroom_rounded,
                        color: const Color(0xFF8B5CF6),
                        tooltip: "Wish Parents on WhatsApp",
                        onTap: () => ActionService.sendParentWhatsAppWish(
                          student,
                          parentTemplate: provider.parentTemplate,
                          teacherName: provider.teacherName,
                          context: context,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    // More options popup menu
                    Material(
                      color: isDark ? const Color(0xFF263248) : const Color(0xFFF1F5F9),
                      shape: const CircleBorder(),
                      child: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_horiz_rounded,
                          size: 20,
                          color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                        ),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (val) {
                          if (val == 'edit') {
                            StudentEditDialog.show(context, student: student);
                          } else if (val == 'share') {
                            final msg = ActionService.formatGreetingTemplate(
                              provider.defaultTemplate,
                              student,
                              teacherName: provider.teacherName,
                            );
                            ActionService.shareWishText(student, msg);
                          } else if (val == 'copy') {
                            final info = "${student.name} | DOB: ${student.formattedDob}${student.groupClass != null ? ' | Class: ${student.groupClass}' : ''}${student.phone != null ? ' | Phone: ${student.phone}' : ''}";
                            Clipboard.setData(ClipboardData(text: info));
                            AppToast.showCopied(
                              context,
                              title: "Student Details Copied",
                              text: "${student.name} • ${student.formattedDob}",
                            );
                          } else if (val == 'delete') {
                            _confirmDelete(context, student, provider);
                          }
                        },
                        itemBuilder: (ctx) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_rounded, size: 18),
                                SizedBox(width: 10),
                                Text("Edit Record"),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_rounded, size: 18),
                                SizedBox(width: 10),
                                Text("Share Greeting"),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'copy',
                            child: Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 18),
                                SizedBox(width: 10),
                                Text("Copy Details"),
                              ],
                            ),
                          ),
                          const PopupMenuDivider(),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                                SizedBox(width: 10),
                                Text("Delete", style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          child: Icon(icon, size: 19, color: color),
        ),
      ),
    );
  }

  void _showStudentDetails(BuildContext context, StudentModel student, StudentProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2638) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: student.avatarColor,
                    child: Text(
                      student.initials,
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.name,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${student.groupClass ?? 'No Class'} • Roll #${student.rollNo ?? 'N/A'}",
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 32),
              _detailRow(Icons.cake_rounded, "Date of Birth", "${student.formattedDob} (Turning ${student.turningAge})"),
              _detailRow(Icons.phone_rounded, "Student Contact", student.phone ?? "Not recorded"),
              _detailRow(Icons.family_restroom_rounded, "Parent Contact", student.parentPhone ?? "Not recorded"),
              if (student.notes != null)
                _detailRow(Icons.note_alt_rounded, "Teacher Notes", student.notes!),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        StudentEditDialog.show(context, student: student);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text("Edit Details"),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, StudentModel student, StudentProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Student Record?"),
        content: Text("Are you sure you want to remove ${student.name} from the database?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final studentName = student.name;
              provider.deleteStudent(student.id!);
              Navigator.pop(ctx);
              AppToast.showInfo(
                context,
                title: "Student Removed",
                message: "Removed $studentName from records",
                icon: Icons.delete_outline_rounded,
                badgeTag: "DELETED",
              );
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
