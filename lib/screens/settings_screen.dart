import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';
import '../services/action_service.dart';
import '../services/native_bridge_service.dart';
import '../services/toast_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _teacherNameCtrl;
  late TextEditingController _studentTemplateCtrl;
  late TextEditingController _parentTemplateCtrl;

  late int _notificationHour;
  late int _notificationMinute;
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<StudentProvider>(context, listen: false);
    _teacherNameCtrl = TextEditingController(text: provider.teacherName);
    final studentTemplate = provider.defaultTemplate.contains('*')
        ? provider.defaultTemplate
        : "Dear *{name}*, wishing you a very *Happy Birthday!* 🎂 May this year bring you wisdom, great success, and joy. Keep shining in *{class}*! 🎉\n\nBest regards,\n*{teacher_name}*";
    final parentTemplate = provider.parentTemplate.contains('*')
        ? provider.parentTemplate
        : "Dear Parent, heartfelt congratulations on *{name}*'s birthday today! 💐 Wishing your child a glorious year ahead filled with good health and academic excellence.\n\nWarm regards,\n*{teacher_name}* (*{class}*)";
    _studentTemplateCtrl = TextEditingController(text: studentTemplate);
    _parentTemplateCtrl = TextEditingController(text: parentTemplate);
    _notificationHour = provider.notificationHour;
    _notificationMinute = provider.notificationMinute;
    _notificationsEnabled = provider.isNotificationEnabled;
  }

  @override
  void dispose() {
    _teacherNameCtrl.dispose();
    _studentTemplateCtrl.dispose();
    _parentTemplateCtrl.dispose();
    super.dispose();
  }

  void _saveAllSettings() {
    final provider = Provider.of<StudentProvider>(context, listen: false);
    provider.savePreferences(
      teacherName: _teacherNameCtrl.text.trim(),
      defaultTemplate: _studentTemplateCtrl.text.trim(),
      parentTemplate: _parentTemplateCtrl.text.trim(),
      notificationHour: _notificationHour,
      notificationMinute: _notificationMinute,
      isNotificationEnabled: _notificationsEnabled,
    );

    AppToast.showSuccess(
      context,
      title: "Preferences Saved",
      message: "Notification schedules & custom message templates are updated.",
      icon: Icons.shield_rounded,
      badgeTag: "SAVED",
    );
  }

  Future<void> _pickNotificationTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _notificationHour, minute: _notificationMinute),
    );
    if (picked != null) {
      setState(() {
        _notificationHour = picked.hour;
        _notificationMinute = picked.minute;
      });
      _saveAllSettings();
    }
  }

  Future<void> _triggerTestNotification() async {
    final provider = Provider.of<StudentProvider>(context, listen: false);
    final today = provider.todayBirthdays;
    bool success = false;
    if (today.isNotEmpty) {
      success = await provider.checkAndNotifyTodayBirthdays(force: true);
    } else {
      success = await NativeBridgeService.triggerTestNotification(
        title: "🎂 Daily Birthday Alert (Kotlin WorkManager)",
        message: "Aarav Sharma (BCA - DS) is celebrating their birthday today! Tap to wish them.",
      );
    }

    if (mounted) {
      if (success) {
        AppToast.showSuccess(
          context,
          title: "Notification Dispatched",
          message: "Android Kotlin WorkManager triggered the birthday alarm!",
          icon: Icons.notifications_active_rounded,
          badgeTag: "SYSTEM ALARM",
        );
      } else {
        AppToast.showError(
          context,
          title: "Notification Failed",
          message: "Please allow notifications in device system settings.",
        );
      }
    }
  }

  Future<void> _exportCsv() async {
    final provider = Provider.of<StudentProvider>(context, listen: false);
    final csvData = provider.exportToCsvString();

    await SharePlus.instance.share(
      ShareParams(
        text: csvData,
        subject: "Students_Birthday_Roster.csv",
      ),
    );
  }

  void _insertToken(TextEditingController ctrl, String token) {
    final text = ctrl.text;
    final selection = ctrl.selection;
    if (selection.start >= 0) {
      final newText = text.replaceRange(selection.start, selection.end, token);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: selection.start + token.length),
      );
    } else {
      ctrl.text = text + token;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<StudentProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sample student for preview (BCA - DS / BCA - AIML)
    final sampleStudent = StudentModel(
      name: "Aarav Sharma",
      rollNo: "BCA-DS-01",
      groupClass: "BCA - DS",
      dob: DateTime(2004, 9, 10),
    );

    final studentPreviewWish = ActionService.formatGreetingTemplate(
      _studentTemplateCtrl.text,
      sampleStudent,
      teacherName: _teacherNameCtrl.text,
    );

    final parentPreviewWish = ActionService.formatGreetingTemplate(
      _parentTemplateCtrl.text,
      sampleStudent,
      teacherName: _teacherNameCtrl.text,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("Preferences & Settings"),
        actions: [
          IconButton(
            icon: const Icon(Icons.check_rounded, color: Color(0xFF6366F1)),
            tooltip: "Save Settings",
            onPressed: _saveAllSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Teacher Profile Section
            _buildSectionCard(
              isDark: isDark,
              icon: Icons.person_rounded,
              title: "Teacher / Professor Profile",
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _teacherNameCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: "Your Name / Title (For Message Signature)",
                      hintText: "e.g. Prof. R. K. Sharma",
                      prefixIcon: Icon(Icons.badge_rounded),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Daily Background Alarm / Notification Card
            _buildSectionCard(
              isDark: isDark,
              icon: Icons.notifications_active_rounded,
              title: "Daily Background Reminder (WorkManager)",
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Daily Birthday Notifications", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              "Automatically checks 100% offline via native Kotlin worker",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _notificationsEnabled,
                        activeTrackColor: const Color(0xFF6366F1),
                        onChanged: (val) {
                          setState(() {
                            _notificationsEnabled = val;
                          });
                          _saveAllSettings();
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Scheduled Notification Time", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            const SizedBox(height: 2),
                            Text(
                              "${_notificationHour.toString().padLeft(2, '0')}:${_notificationMinute.toString().padLeft(2, '0')} (${_notificationHour >= 12 ? 'PM' : 'AM'})",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _notificationsEnabled ? _pickNotificationTime : null,
                        icon: const Icon(Icons.access_time_filled_rounded, size: 16),
                        label: const Text("Change"),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _triggerTestNotification,
                      icon: const Icon(Icons.notifications_rounded),
                      label: const Text("Trigger Instant Test Notification"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.12),
                        foregroundColor: const Color(0xFF6366F1),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Student WhatsApp Wish Template
            _buildSectionCard(
              isDark: isDark,
              icon: Icons.chat_bubble_rounded,
              title: "Student WhatsApp Greeting Template",
              trailing: TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _studentTemplateCtrl.text = "Dear *{name}*, wishing you a very *Happy Birthday!* 🎂 May this year bring you wisdom, great success, and joy. Keep shining in *{class}*! 🎉\n\nBest regards,\n*{teacher_name}*";
                  setState(() {});
                },
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text("Reset Default", style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Preset Ideas
                  Text(
                    "Quick Inspiration Presets (1-Tap):",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPresetRow(
                    controller: _studentTemplateCtrl,
                    isDark: isDark,
                    presets: [
                      {
                        "title": "Warm & Joyful",
                        "emoji": "🎂",
                        "template": "Dear *{name}*, wishing you a very *Happy Birthday!* 🎂 May this year bring you wisdom, great success, and joy. Keep shining in *{class}*! 🎉\n\nBest regards,\n*{teacher_name}*",
                      },
                      {
                        "title": "Academic Inspiring",
                        "emoji": "🌟",
                        "template": "Happy Birthday, *{name}*! 🌟 We are very proud of your dedication in *{class}*. May you achieve all your academic goals and reach greater heights! ✨\n\nWarm regards,\n*{teacher_name}*",
                      },
                      {
                        "title": "Short & Cheerful",
                        "emoji": "🎈",
                        "template": "Happy *{age}th* Birthday, *{name}*! 🎈 Wishing you a fantastic day filled with celebration and happiness! 🥳\n\n- *{teacher_name}*",
                      },
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Smart Dynamic Token Pills
                  Text(
                    "Tap to Insert Dynamic Student Info at Cursor:",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTokenGrid(controller: _studentTemplateCtrl, isDark: isDark),
                  const SizedBox(height: 12),

                  // WhatsApp Formatting Toolbar (Bold, Italic, Emojis)
                  _buildFormattingToolbar(_studentTemplateCtrl, isDark),
                  const SizedBox(height: 10),

                  // Editor Field
                  TextField(
                    controller: _studentTemplateCtrl,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: "Custom Student Message Template",
                      hintText: "Type greeting, use *bold* or tap tokens above...",
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Realistic WhatsApp Live Preview
                  _buildWhatsAppPreviewCard(
                    isDark: isDark,
                    previewText: studentPreviewWish,
                    recipientLabel: "Student",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Parent WhatsApp Wish Template
            _buildSectionCard(
              isDark: isDark,
              icon: Icons.family_restroom_rounded,
              title: "Parent WhatsApp Greeting Template",
              trailing: TextButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _parentTemplateCtrl.text = "Dear Parent, heartfelt congratulations on *{name}*'s birthday today! 💐 Wishing your child a glorious year ahead filled with good health and academic excellence.\n\nWarm regards,\n*{teacher_name}* (*{class}*)";
                  setState(() {});
                },
                icon: const Icon(Icons.refresh_rounded, size: 14),
                label: const Text("Reset Default", style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Preset Ideas for Parents
                  Text(
                    "Quick Inspiration Presets (1-Tap):",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildPresetRow(
                    controller: _parentTemplateCtrl,
                    isDark: isDark,
                    presets: [
                      {
                        "title": "Heartfelt Wishes",
                        "emoji": "💐",
                        "template": "Dear Parent, heartfelt congratulations on *{name}*'s birthday today! 💐 Wishing your family joy, good health, and success.\n\nWarm regards,\n*{teacher_name}* (*{class}*)",
                      },
                      {
                        "title": "Proud Teacher Note",
                        "emoji": "🌟",
                        "template": "Dear Parents, sending our warmest blessings to *{name}* on their special day! 🌟 Thank you for your continued support in *{class}*.\n\nBest wishes,\n*{teacher_name}*",
                      },
                      {
                        "title": "Prosperity & Growth",
                        "emoji": "🎉",
                        "template": "Dear Parent, wishing *{name}* a wonderful Happy Birthday! 🎉 May this year bring happiness, good health, and academic excellence.\n\nRegards,\n*{teacher_name}*",
                      },
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Smart Dynamic Token Pills for Parents
                  Text(
                    "Tap to Insert Dynamic Info at Cursor:",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTokenGrid(controller: _parentTemplateCtrl, isDark: isDark),
                  const SizedBox(height: 12),

                  // WhatsApp Formatting Toolbar (Bold, Italic, Emojis)
                  _buildFormattingToolbar(_parentTemplateCtrl, isDark),
                  const SizedBox(height: 10),

                  // Editor Field
                  TextField(
                    controller: _parentTemplateCtrl,
                    maxLines: 4,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: "Custom Parent Message Template",
                      hintText: "Type greeting, use *bold* or tap tokens above...",
                      alignLabelWithHint: true,
                      contentPadding: const EdgeInsets.all(14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Realistic WhatsApp Live Preview for Parents
                  _buildWhatsAppPreviewCard(
                    isDark: isDark,
                    previewText: parentPreviewWish,
                    recipientLabel: "Parent",
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Data Management / Backup Card
            _buildSectionCard(
              isDark: isDark,
              icon: Icons.dns_rounded,
              title: "Data Backup & Management",
              child: Column(
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
                                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.file_download_rounded, color: Color(0xFF10B981), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Export Roster as CSV", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                  Text("${provider.allStudents.length} student records in database", style: TextStyle(fontSize: 12, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: _exportCsv,
                        child: const Text("Export"),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Wipe All Student Data", style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600, fontSize: 14)),
                                  Text("Deletes all local records from device", style: TextStyle(fontSize: 12, color: Colors.grey.shade500), overflow: TextOverflow.ellipsis),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _confirmWipe(context, provider),
                        child: const Text("Reset DB"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveAllSettings,
                icon: const Icon(Icons.check_circle_rounded),
                label: const Text("Save All Preferences", style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),

            const SizedBox(height: 28),

            // App Branding & Version
            Center(
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Image.asset(
                      isDark ? 'assets/images/butterfly_white.png' : 'assets/images/butterfly_black.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Teacher's Birthday Manager",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    "v1.0.0 • 100% Offline & Private",
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  void _wrapSelection(TextEditingController ctrl, String prefix, String suffix) {
    HapticFeedback.lightImpact();
    final text = ctrl.text;
    final selection = ctrl.selection;
    if (selection.start >= 0 && selection.end > selection.start) {
      final selectedText = text.substring(selection.start, selection.end);
      final newText = text.replaceRange(selection.start, selection.end, '$prefix$selectedText$suffix');
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: selection.start + prefix.length,
          extentOffset: selection.end + prefix.length,
        ),
      );
    } else {
      final cursor = selection.start >= 0 ? selection.start : text.length;
      final newText = text.replaceRange(cursor, cursor, '${prefix}text$suffix');
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection(
          baseOffset: cursor + prefix.length,
          extentOffset: cursor + prefix.length + 4,
        ),
      );
    }
    setState(() {});
  }

  void _autoFormatTemplate(TextEditingController ctrl) {
    HapticFeedback.mediumImpact();
    String text = ctrl.text;

    // Bold tokens if unbolded
    text = text.replaceAllMapped(RegExp(r'(?<!\*)\{name\}(?!\*)'), (m) => '*{name}*');
    text = text.replaceAllMapped(RegExp(r'(?<!\*)\{class\}(?!\*)'), (m) => '*{class}*');
    text = text.replaceAllMapped(RegExp(r'(?<!\*)\{teacher_name\}(?!\*)'), (m) => '*{teacher_name}*');
    text = text.replaceAllMapped(RegExp(r'(?<!\*)\{teacher\}(?!\*)'), (m) => '*{teacher_name}*');
    text = text.replaceAllMapped(RegExp(r'(?<!\*)\{age\}th(?!\*)'), (m) => '*{age}th*');
    text = text.replaceAllMapped(RegExp(r'(?<!\*)\{roll\}(?!\*)'), (m) => '*{roll}*');

    // Bold common celebratory phrases if unbolded
    text = text.replaceAllMapped(RegExp(r'(?<!\*)Happy Birthday!?(?!\*)', caseSensitive: false), (m) => '*Happy Birthday!*');
    text = text.replaceAllMapped(RegExp(r'(?<!\*)heartfelt congratulations(?!\*)', caseSensitive: false), (m) => '*heartfelt congratulations*');

    ctrl.text = text;
    setState(() {});

    if (mounted) {
      AppToast.showSuccess(
        context,
        title: "Template Formatted",
        message: "Dynamic tags wrapped in WhatsApp bold markers (*text*)!",
        icon: Icons.auto_awesome_rounded,
        badgeTag: "WHATSAPP FORMAT",
      );
    }
  }

  Widget _buildFormattingToolbar(TextEditingController ctrl, bool isDark) {
    final emojis = ["🎂", "🎉", "💐", "🌟", "✨", "🥳", "🎈", "🎁", "❤️", "👏"];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131B2A) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Text(
                  "Format:",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(width: 8),
                // Bold Button (*B*)
                _buildToolbarButton(
                  label: "B",
                  tooltip: "Bold (*text*)",
                  isBold: true,
                  isDark: isDark,
                  onTap: () => _wrapSelection(ctrl, "*", "*"),
                ),
                const SizedBox(width: 4),
                // Italic Button (_I_)
                _buildToolbarButton(
                  label: "I",
                  tooltip: "Italic (_text_)",
                  isItalic: true,
                  isDark: isDark,
                  onTap: () => _wrapSelection(ctrl, "_", "_"),
                ),
                const SizedBox(width: 4),
                // Strikethrough Button (~S~)
                _buildToolbarButton(
                  label: "S",
                  tooltip: "Strikethrough (~text~)",
                  isStrike: true,
                  isDark: isDark,
                  onTap: () => _wrapSelection(ctrl, "~", "~"),
                ),
                const SizedBox(width: 4),
                // Monospace Button
                _buildToolbarButton(
                  label: "</>",
                  tooltip: "Monospace (```text```)",
                  isDark: isDark,
                  onTap: () => _wrapSelection(ctrl, "```", "```"),
                ),
                const SizedBox(width: 8),
                // Smart Auto-Format Button
                InkWell(
                  onTap: () => _autoFormatTemplate(ctrl),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("🪄", style: TextStyle(fontSize: 11)),
                        SizedBox(width: 4),
                        Text(
                          "Auto-Bold",
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Emoji Bar
          Row(
            children: [
              Text(
                "Emojis:",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade500,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: emojis.length,
                    separatorBuilder: (ctx, i) => const SizedBox(width: 4),
                    itemBuilder: (ctx, i) {
                      return InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _insertToken(ctrl, emojis[i]);
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E2638) : Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2A364F) : const Color(0xFFCBD5E1),
                              width: 0.8,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(emojis[i], style: const TextStyle(fontSize: 14)),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarButton({
    required String label,
    required String tooltip,
    required bool isDark,
    required VoidCallback onTap,
    bool isBold = false,
    bool isItalic = false,
    bool isStrike = false,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2638) : Colors.white,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: isDark ? const Color(0xFF2A364F) : const Color(0xFFCBD5E1),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.w900 : FontWeight.w600,
              fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
              decoration: isStrike ? TextDecoration.lineThrough : null,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required bool isDark,
    required IconData icon,
    required String title,
    required Widget child,
    Widget? trailing,
  }) {
    return Material(
      color: isDark ? const Color(0xFF1E2638) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: const Color(0xFF6366F1)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildPresetRow({
    required TextEditingController controller,
    required List<Map<String, String>> presets,
    required bool isDark,
  }) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (ctx, i) => const SizedBox(width: 8),
        itemBuilder: (ctx, i) {
          final p = presets[i];
          return ActionChip(
            avatar: Text(p["emoji"] ?? "✨", style: const TextStyle(fontSize: 12)),
            label: Text(
              p["title"]!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
              ),
            ),
            backgroundColor: isDark ? const Color(0xFF131B2A) : const Color(0xFFF1F5F9),
            side: BorderSide(
              color: isDark ? const Color(0xFF2A364F) : const Color(0xFFCBD5E1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6),
            onPressed: () {
              HapticFeedback.lightImpact();
              controller.text = p["template"]!;
              setState(() {});
            },
          );
        },
      ),
    );
  }

  Widget _buildTokenGrid({
    required TextEditingController controller,
    required bool isDark,
  }) {
    final tokens = [
      {"label": "Student Name", "token": "*{name}*", "icon": Icons.person_rounded},
      {"label": "Class", "token": "*{class}*", "icon": Icons.school_rounded},
      {"label": "Roll No", "token": "#{roll}", "icon": Icons.badge_rounded},
      {"label": "Age", "token": "*{age}*", "icon": Icons.cake_rounded},
      {"label": "Teacher Name", "token": "*{teacher_name}*", "icon": Icons.account_circle_rounded},
      {"label": "DOB", "token": "{dob}", "icon": Icons.calendar_today_rounded},
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: tokens.map((item) {
        final tokenStr = item["token"] as String;
        final labelStr = item["label"] as String;
        final iconData = item["icon"] as IconData;

        return InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            _insertToken(controller, " $tokenStr ");
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF6366F1).withValues(alpha: isDark ? 0.35 : 0.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(iconData, size: 13, color: const Color(0xFF6366F1)),
                const SizedBox(width: 5),
                Text(
                  labelStr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6366F1),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.add_rounded, size: 12, color: Color(0xFF6366F1)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  List<InlineSpan> _buildFormattedSpans(String text, TextStyle baseStyle) {
    final spans = <InlineSpan>[];
    // WhatsApp Markdown: ```monospace```, *bold*, _italic_, ~strikethrough~
    final regex = RegExp(r'(\`\`\`[^\`\n]+\`\`\`)|(\*[^\*\n]+\*)|(_[^_\n]+_)|(~[^~\n]+~)');
    int lastMatchEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: text.substring(lastMatchEnd, match.start),
          style: baseStyle,
        ));
      }
      final matchText = match.group(0)!;
      if (matchText.startsWith('```') && matchText.endsWith('```')) {
        spans.add(TextSpan(
          text: matchText.substring(3, matchText.length - 3),
          style: GoogleFonts.firaCode(
            textStyle: baseStyle.copyWith(
              fontSize: (baseStyle.fontSize ?? 13.5) * 0.92,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
            ),
          ),
        ));
      } else if (matchText.startsWith('*') && matchText.endsWith('*')) {
        spans.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: baseStyle.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 0.2,
          ),
        ));
      } else if (matchText.startsWith('_') && matchText.endsWith('_')) {
        spans.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: baseStyle.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ));
      } else if (matchText.startsWith('~') && matchText.endsWith('~')) {
        spans.add(TextSpan(
          text: matchText.substring(1, matchText.length - 1),
          style: baseStyle.copyWith(
            decoration: TextDecoration.lineThrough,
          ),
        ));
      }
      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastMatchEnd),
        style: baseStyle,
      ));
    }

    return spans;
  }

  Widget _buildWhatsAppPreviewCard({
    required bool isDark,
    required String previewText,
    required String recipientLabel,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B141A) : const Color(0xFFECE5DD),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFD1D7DB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // WhatsApp Top Bar Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2C34) : const Color(0xFF075E54),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(17)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF25D366),
                  child: Text(
                    recipientLabel[0],
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "$recipientLabel (Aarav Sharma)",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const Row(
                        children: [
                          Icon(Icons.fiber_manual_record_rounded, size: 8, color: Color(0xFF25D366)),
                          SizedBox(width: 4),
                          Text(
                            "online",
                            style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.remove_red_eye_rounded, size: 12, color: Colors.white70),
                      SizedBox(width: 4),
                      Text(
                        "Preview",
                        style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // WhatsApp Chat Bubble Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Chat Bubble
                Container(
                  constraints: const BoxConstraints(maxWidth: 320),
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF005C4B) : const Color(0xFFE7FFDB),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(4),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      RichText(
                        text: TextSpan(
                          children: _buildFormattedSpans(
                            previewText,
                            TextStyle(
                              fontSize: 13.5,
                              height: 1.45,
                              color: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            "10:45 AM",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF8696A0) : const Color(0xFF667781),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.done_all_rounded,
                            size: 15,
                            color: Color(0xFF53BDEB),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // Action Bar below chat bubble
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        AppToast.showCopied(
                          context,
                          title: "Wish Message Copied",
                          text: previewText.length > 50 ? "${previewText.substring(0, 50)}..." : previewText,
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label: const Text("Copy Text", style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? Colors.grey.shade400 : const Color(0xFF475569),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                    const SizedBox(width: 4),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        SharePlus.instance.share(
                          ShareParams(
                            text: previewText,
                            subject: "Birthday Wish Preview",
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 14),
                      label: const Text("Share Wish", style: TextStyle(fontSize: 11)),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmWipe(BuildContext context, StudentProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Wipe All Student Records?"),
        content: const Text("This will permanently remove all student records from your local database. This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              provider.clearAllData();
              Navigator.pop(ctx);
              AppToast.showInfo(
                context,
                title: "Database Cleared",
                message: "All student records removed from local storage",
                icon: Icons.delete_sweep_rounded,
                badgeTag: "WIPED",
              );
            },
            child: const Text("Wipe Database", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
