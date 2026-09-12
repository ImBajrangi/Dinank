import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/student_provider.dart';
import '../widgets/birthday_trend_card.dart';
import '../widgets/stat_badge.dart';
import '../widgets/student_action_card.dart';
import '../widgets/student_edit_dialog.dart';
import '../widgets/today_celebrants_banner.dart';
import '../services/toast_service.dart';

class HomeDashboardScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const HomeDashboardScreen({super.key, required this.onNavigateTab});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen> {
  bool _hasCheckedNamePrompt = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndPromptTeacherName();
    });
  }

  void _checkAndPromptTeacherName() {
    if (_hasCheckedNamePrompt || !mounted) return;

    final provider = Provider.of<StudentProvider>(context, listen: false);
    if (provider.isLoading) return;

    _hasCheckedNamePrompt = true;

    // Only prompt if the user has never been prompted AND name is not yet configured
    if (provider.shouldPromptTeacherName) {
      _showNamePromptBottomSheet(context, provider);
    }
  }

  void _showNamePromptBottomSheet(BuildContext context, StudentProvider provider) {
    final nameCtrl = TextEditingController(text: provider.teacherName);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2638) : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.badge_rounded, color: Color(0xFF6366F1), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Welcome to Birthday Radar! 👋",
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "What is your Name or Title?",
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  "Your name will appear on the dashboard and will be automatically inserted as the signature on your WhatsApp birthday greetings to students and parents.",
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: "Your Name / Title",
                    hintText: "e.g. Prof. Sharma, Dr. Priya, Mrs. Mehta",
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          "Set Later",
                          style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          final text = nameCtrl.text.trim();
                          if (text.isNotEmpty) {
                            HapticFeedback.lightImpact();
                            provider.updateTeacherName(text);
                            Navigator.pop(ctx);
                            AppToast.showSuccess(
                              context,
                              title: "Welcome aboard, $text!",
                              message: "Your profile & greetings signature are configured.",
                              icon: Icons.waving_hand_rounded,
                              badgeTag: "PROFILE READY",
                            );
                          } else {
                            Navigator.pop(ctx);
                          }
                        },
                        icon: const Icon(Icons.check_rounded),
                        label: const Text("Save & Continue"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6366F1),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ).whenComplete(() {
      provider.markTeacherNamePrompted();
    });
  }

  void _showEditNameDialog(BuildContext context, StudentProvider provider) {
    final nameCtrl = TextEditingController(text: provider.teacherName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: Color(0xFF6366F1), size: 20),
            SizedBox(width: 8),
            Text("Edit Profile Name"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Enter your name or title to personalize your dashboard and WhatsApp greetings:",
              style: TextStyle(fontSize: 12.5, color: Colors.grey),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: "Name / Title",
                hintText: "e.g. Prof. R. K. Sharma",
                prefixIcon: Icon(Icons.person_rounded),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final newName = nameCtrl.text.trim();
              provider.updateTeacherName(newName);
              Navigator.pop(ctx);
              AppToast.showSuccess(
                context,
                title: "Profile Updated",
                message: newName.isNotEmpty
                    ? "Display name set to $newName"
                    : "Display name cleared",
                icon: Icons.account_circle_rounded,
                badgeTag: "PROFILE",
              );
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<StudentProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final todayList = provider.todayBirthdays;
    final weekList = provider.upcomingWeekBirthdays;
    final monthList = provider.upcomingMonthBirthdays;
    final totalCount = provider.allStudents.length;

    final hasCustomName = provider.hasSetTeacherName;
    final teacherTitle = hasCustomName
        ? provider.teacherName.trim()
        : "Welcome, Educator";

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await provider.syncAllGoogleSheets(showLoading: false);
            await provider.loadAllStudents();
          },
          color: const Color(0xFF6366F1),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Top Brand & Teacher Header Bar
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // App logo & faculty info
                      Expanded(
                        child: InkWell(
                          onTap: () => _showEditNameDialog(context, provider),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF00D2B4), Color(0xFF06B6D4)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00D2B4).withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.cake_rounded,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            "BIRTHDAY RADAR",
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                              color: const Color(0xFF0D9488),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF10B981),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          if (!hasCustomName) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                "Tap to set name",
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF6366F1),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 1),
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              teacherTitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.edit_rounded,
                                            size: 14,
                                            color: Colors.grey.withValues(alpha: 0.6),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Top Action Pill Buttons
                      Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2638) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                              color: const Color(0xFF6366F1),
                              tooltip: "Add Student",
                              onPressed: () => StudentEditDialog.show(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2638) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.tune_rounded, size: 20),
                              color: isDark ? Colors.grey.shade300 : const Color(0xFF475569),
                              tooltip: "Settings",
                              onPressed: () => widget.onNavigateTab(3),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Today's Hero Banner
              const SliverToBoxAdapter(
                child: TodayCelebrantsBanner(),
              ),

              // Quick Stats Row (Bento Grid)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                  child: Row(
                    children: [
                      StatBadge(
                        title: "Today",
                        count: todayList.length.toString(),
                        icon: Icons.cake_rounded,
                        color: const Color(0xFFEC4899),
                        onTap: () => widget.onNavigateTab(1),
                      ),
                      const SizedBox(width: 6),
                      StatBadge(
                        title: "This Week",
                        count: weekList.length.toString(),
                        icon: Icons.calendar_today_rounded,
                        color: const Color(0xFF6366F1),
                        onTap: () => widget.onNavigateTab(1),
                      ),
                      const SizedBox(width: 6),
                      StatBadge(
                        title: "This Month",
                        count: monthList.length.toString(),
                        icon: Icons.event_note_rounded,
                        color: const Color(0xFF06B6D4),
                        onTap: () => widget.onNavigateTab(1),
                      ),
                      const SizedBox(width: 6),
                      StatBadge(
                        title: "Total",
                        count: totalCount.toString(),
                        icon: Icons.groups_rounded,
                        color: const Color(0xFF10B981),
                        onTap: () => widget.onNavigateTab(1),
                      ),
                    ],
                  ),
                ),
              ),

              // 7-Day Horizon Trend Card
              SliverToBoxAdapter(
                child: BirthdayTrendCard(students: provider.allStudents),
              ),

              // Actionable Category Sections: Today's Celebrants
              if (todayList.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.cake_rounded, color: Color(0xFFEC4899), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Today's Birthdays",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => widget.onNavigateTab(1),
                          child: const Text("View All", style: TextStyle(color: Color(0xFF6366F1), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return StudentActionCard(
                        student: todayList[index],
                        isFeaturedToday: true,
                      );
                    },
                    childCount: todayList.length,
                  ),
                ),
              ],

              // Upcoming in next 7 days
              if (weekList.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              "Upcoming This Week",
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () => widget.onNavigateTab(1),
                          child: const Text("View All", style: TextStyle(color: Color(0xFF6366F1), fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return StudentActionCard(
                        student: weekList[index],
                      );
                    },
                    childCount: weekList.length > 5 ? 5 : weekList.length,
                  ),
                ),
              ],

              // Empty State
              if (totalCount == 0)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2638) : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.cake_outlined,
                            size: 48,
                            color: Color(0xFF6366F1),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No Birthdays Recorded Yet",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "Import your class Excel roster or add your students manually to start receiving daily birthday alerts and 1-tap WhatsApp greetings.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: () => widget.onNavigateTab(2),
                          icon: const Icon(Icons.file_upload_rounded),
                          label: const Text("Import Student Roster"),
                        ),
                      ],
                    ),
                  ),
                ),

              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
