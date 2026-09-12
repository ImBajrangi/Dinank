import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/google_sheet_source.dart';
import '../providers/student_provider.dart';
import '../services/excel_service.dart';
import '../services/toast_service.dart';

class ImportExcelScreen extends StatefulWidget {
  final VoidCallback onImportSuccess;

  const ImportExcelScreen({super.key, required this.onImportSuccess});

  @override
  State<ImportExcelScreen> createState() => _ImportExcelScreenState();
}

class _ImportExcelScreenState extends State<ImportExcelScreen> {
  int _selectedTabIndex = 0; // 0: Local Spreadsheet File, 1: Google Sheets Cloud Sync
  bool _isProcessing = false;
  String? _errorMessage;
  ExcelParseResult? _currentParseResult;
  bool _isDemoData = false;
  bool _isColumnGuideExpanded = false;
  bool _isHowToConnectExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<StudentProvider>(context, listen: false).loadSheetSources();
    });
  }

  // ----------------------------------------------------
  // Local File Upload Workflow
  // ----------------------------------------------------

  Future<void> _pickFile() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final parseResult = await ExcelService.pickAndParseFile();
      if (parseResult != null) {
        if (parseResult.students.isEmpty) {
          setState(() {
            _errorMessage = "No valid student rows found in '${parseResult.fileName}'. Ensure 'Name' and 'DOB' columns exist.";
            _currentParseResult = null;
            _isDemoData = false;
          });
        } else {
          setState(() {
            _currentParseResult = parseResult;
            _isDemoData = false;
            _errorMessage = null;
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to parse spreadsheet: ${e.toString()}";
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  void _clearPreview() {
    HapticFeedback.lightImpact();
    setState(() {
      _currentParseResult = null;
      _isDemoData = false;
      _errorMessage = null;
    });
  }

  Future<void> _commitImport() async {
    if (_currentParseResult == null || _currentParseResult!.students.isEmpty) return;

    setState(() {
      _isProcessing = true;
    });

    final provider = Provider.of<StudentProvider>(context, listen: false);
    final count = await provider.importStudents(_currentParseResult!.students);

    final fileName = _currentParseResult!.fileName;

    setState(() {
      _isProcessing = false;
      _currentParseResult = null;
      _isDemoData = false;
    });

    if (mounted) {
      AppToast.showSuccess(
        context,
        title: "Roster Imported Successfully!",
        message: "$count students loaded from '$fileName' into database",
        icon: Icons.table_chart_rounded,
        badgeTag: "DATABASE SYNCED",
        duration: const Duration(milliseconds: 4000),
      );
      widget.onImportSuccess();
    }
  }

  Future<void> _loadTrialDemo() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final trialResult = await ExcelService.loadTrialDatasetResult();
      setState(() {
        _currentParseResult = trialResult;
        _isDemoData = true;
        _errorMessage = null;
        _isProcessing = false;
      });
      if (mounted) {
        AppToast.showInfo(
          context,
          title: "Trial Demo Generated",
          message: "Loaded 12 sample students from BCA - DS & BCA - AIML",
          icon: Icons.auto_awesome_rounded,
          badgeTag: "DEMO PREVIEW",
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Failed to generate trial dataset: $e";
        _isProcessing = false;
      });
    }
  }

  Future<void> _downloadTemplate({required bool isExcel}) async {
    HapticFeedback.lightImpact();
    try {
      await ExcelService.exportClassroomTemplate(isExcel: isExcel);
      if (mounted) {
        AppToast.showSuccess(
          context,
          title: "Template Saved",
          message: "Download complete! Check your Downloads folder.",
          icon: Icons.file_download_done_rounded,
          badgeTag: "TEMPLATE READY",
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.showError(
          context,
          title: "Export Failed",
          message: "$e",
        );
      }
    }
  }

  // ----------------------------------------------------
  // Google Sheets Cloud Sync Workflow
  // ----------------------------------------------------

  void _showAddSheetBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    bool isSaving = false;
    String? localError;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(modalContext).viewInsets.bottom),
              child: Container(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2638) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
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
                          color: Colors.grey.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0F9D58), Color(0xFF00BFA5)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Connect Google Sheet",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Auto-syncs live roster updates directly from cloud",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Sheet Name Field
                    TextField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: "Sheet Name / Batch (Optional)",
                        hintText: "e.g. Grade 10 - Biology or BCA Batch 2026",
                        prefixIcon: const Icon(Icons.badge_rounded, color: Color(0xFF0F9D58)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Google Sheet URL Field
                    TextField(
                      controller: urlCtrl,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: "Google Sheet Link *",
                        hintText: "https://docs.google.com/spreadsheets/d/...",
                        prefixIcon: const Icon(Icons.link_rounded, color: Color(0xFF0F9D58)),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.content_paste_rounded, size: 20),
                          tooltip: "Paste from Clipboard",
                          onPressed: () async {
                            final data = await Clipboard.getData(Clipboard.kTextPlain);
                            if (data?.text != null) {
                              urlCtrl.text = data!.text!.trim();
                              setModalState(() {});
                            }
                          },
                        ),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Access Note
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F9D58).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF0F9D58).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Color(0xFF0F9D58), size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Make sure your Google Sheet access is set to 'Anyone with the link can view' (Share > General Access).",
                              style: TextStyle(
                                fontSize: 11.5,
                                color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (localError != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                localError!,
                                style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),

                    // Actions
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isSaving ? null : () => Navigator.pop(ctx),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: isSaving
                                ? null
                                : () async {
                                    final rawUrl = urlCtrl.text.trim();
                                    if (rawUrl.isEmpty) {
                                      setModalState(() {
                                        localError = "Please paste a valid Google Sheet link.";
                                      });
                                      return;
                                    }

                                    setModalState(() {
                                      isSaving = true;
                                      localError = null;
                                    });

                                    final provider = Provider.of<StudentProvider>(context, listen: false);
                                    final (success, error) = await provider.addGoogleSheet(
                                      name: nameCtrl.text.trim(),
                                      url: rawUrl,
                                    );

                                    if (!modalContext.mounted) return;

                                    if (success) {
                                      Navigator.pop(ctx);
                                      AppToast.showSuccess(
                                        context,
                                        title: "Google Sheet Connected!",
                                        message: "Synced and linked ${nameCtrl.text.isEmpty ? 'Google Sheet' : nameCtrl.text} to local database",
                                        icon: Icons.cloud_done_rounded,
                                        badgeTag: "CLOUD SYNCED",
                                      );
                                      widget.onImportSuccess();
                                    } else {
                                      setModalState(() {
                                        isSaving = false;
                                        localError = error ?? "Failed to connect Google Sheet.";
                                      });
                                    }
                                  },
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Icon(Icons.sync_rounded),
                            label: Text(
                              isSaving ? "Connecting & Syncing..." : "Connect & Fetch Roster",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0F9D58),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
        );
      },
    );
  }

  // ----------------------------------------------------
  // Main Build
  // ----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<StudentProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Import & Sync Rosters"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Segmented Tab Switcher (Local Excel vs Google Sheets Sync)
            _buildModeSwitcher(isDark),

            const SizedBox(height: 18),

            // Mode 0: Local File Upload & Guide
            if (_selectedTabIndex == 0) ...[
              _buildColumnGuideCard(isDark),
              const SizedBox(height: 18),
              _buildFileDropZone(isDark),

              // Trial Demo Button (Shown when no preview is active)
              if (_currentParseResult == null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: TextButton.icon(
                      onPressed: _isProcessing ? null : _loadTrialDemo,
                      icon: const Icon(Icons.science_rounded, size: 16, color: Color(0xFF6366F1)),
                      label: const Text(
                        "Want to test first? Load Trial Roster (BCA - DS & AIML .xlsx)",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                      ),
                    ),
                  ),
                ),

              // Error message container
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.red),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Active Parsed Preview Section
              if (_currentParseResult != null && _currentParseResult!.students.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildRosterPreviewSection(isDark),
              ],
            ] else ...[
              // Mode 1: Google Sheets Cloud Sync View
              _buildGoogleSheetsSyncSection(context, provider, isDark),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Segmented Mode Switcher
  // ----------------------------------------------------

  Widget _buildModeSwitcher(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTabIndex = 0);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 0
                      ? (isDark ? const Color(0xFF263248) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTabIndex == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.description_rounded,
                      size: 18,
                      color: _selectedTabIndex == 0 ? const Color(0xFF6366F1) : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Excel / CSV File",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: _selectedTabIndex == 0 ? FontWeight.w800 : FontWeight.w600,
                        color: _selectedTabIndex == 0
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _selectedTabIndex = 1);
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedTabIndex == 1
                      ? (isDark ? const Color(0xFF263248) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: _selectedTabIndex == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.cloud_sync_rounded,
                      size: 18,
                      color: _selectedTabIndex == 1 ? const Color(0xFF0F9D58) : Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "Google Sheets Sync",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: _selectedTabIndex == 1 ? FontWeight.w800 : FontWeight.w600,
                        color: _selectedTabIndex == 1
                            ? (isDark ? Colors.white : const Color(0xFF0F172A))
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Google Sheets Tab Section
  // ----------------------------------------------------

  Widget _buildGoogleSheetsSyncSection(BuildContext context, StudentProvider provider, bool isDark) {
    final sources = provider.sheetSources;
    final isSyncing = provider.isSyncingSheets;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sync Summary & Action Header Card
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF132A1C), const Color(0xFF1B3D2B)]
                  : [const Color(0xFFE8F5E9), const Color(0xFFF1F8E9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF0F9D58).withValues(alpha: isDark ? 0.35 : 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F9D58), Color(0xFF00BFA5)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Live Cloud Synchronization",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sources.isEmpty
                              ? "Connect online Google Sheets for real-time roster updates"
                              : "${sources.length} active sheet${sources.length > 1 ? 's' : ''} connected",
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF2E7D32),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isSyncing ? null : () => _showAddSheetBottomSheet(context),
                      icon: const Icon(Icons.add_link_rounded, size: 18),
                      label: const Text("Add Google Sheet", style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F9D58),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (sources.isNotEmpty) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: isSyncing
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              final synced = await provider.syncAllGoogleSheets(showLoading: true);
                              if (context.mounted) {
                                AppToast.showSuccess(
                                  context,
                                  title: "All Sheets Synced",
                                  message: "$synced student records updated from cloud",
                                  icon: Icons.done_all_rounded,
                                  badgeTag: "LIVE SYNC",
                                );
                              }
                            },
                      icon: isSyncing
                          ? const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F9D58)),
                            )
                          : const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF0F9D58)),
                      label: Text(
                        isSyncing ? "Syncing..." : "Sync All",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F9D58)),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        side: const BorderSide(color: Color(0xFF0F9D58)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // How to connect accordion
        _buildHowToConnectGuide(isDark),

        const SizedBox(height: 18),

        // Connected Sheets List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Connected Google Sheets",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            if (sources.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F9D58).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${sources.length} Linked",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0F9D58)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (sources.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2638) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F9D58).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link_off_rounded, size: 36, color: Color(0xFF0F9D58)),
                ),
                const SizedBox(height: 14),
                Text(
                  "No Google Sheets Connected Yet",
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Paste your Google Sheet share link above to automatically sync student birthdays and classes in real time.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddSheetBottomSheet(context),
                  icon: const Icon(Icons.add_link_rounded, size: 18),
                  label: const Text("Connect Your First Sheet"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F9D58),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sources.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (ctx, index) {
              final src = sources[index];
              return _buildSheetSourceCard(context, provider, src, isDark);
            },
          ),
      ],
    );
  }

  // ----------------------------------------------------
  // How to connect Google Sheet guide card
  // ----------------------------------------------------

  Widget _buildHowToConnectGuide(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isHowToConnectExpanded = !_isHowToConnectExpanded;
              });
            },
            borderRadius: BorderRadius.circular(18),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.help_outline_rounded, color: Color(0xFF0F9D58), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "How to get the Google Sheet share link",
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  Icon(
                    _isHowToConnectExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF0F9D58),
                  ),
                ],
              ),
            ),
          ),
          if (_isHowToConnectExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 6),
                  _buildStepRow("1", "Open your student roster spreadsheet on Google Sheets."),
                  _buildStepRow("2", "Click the green 'Share' button in the top right corner."),
                  _buildStepRow("3", "Under General Access, change 'Restricted' to 'Anyone with the link' (Viewer)."),
                  _buildStepRow("4", "Click 'Copy link' and paste it in Birthday Radar."),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF0F9D58).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Text(
              number,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF0F9D58)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12.5, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Connected Sheet Card Item
  // ----------------------------------------------------

  Widget _buildSheetSourceCard(
    BuildContext context,
    StudentProvider provider,
    GoogleSheetSource source,
    bool isDark,
  ) {
    final hasError = source.lastError != null && source.lastError!.isNotEmpty;
    final syncTimeStr = source.lastSyncedAt != null
        ? DateFormat('dd MMM, hh:mm a').format(source.lastSyncedAt!)
        : "Never synced";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError
              ? Colors.red.withValues(alpha: 0.4)
              : (isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Quick Actions
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: hasError
                      ? Colors.red.withValues(alpha: 0.12)
                      : const Color(0xFF0F9D58).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasError ? Icons.sync_problem_rounded : Icons.table_chart_rounded,
                  color: hasError ? Colors.red : const Color(0xFF0F9D58),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      source.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "Synced: $syncTimeStr",
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                    ),
                  ],
                ),
              ),
              // Student count badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F9D58).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${source.lastStudentCount} Students",
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF0F9D58)),
                ),
              ),
            ],
          ),

          if (hasError) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      source.lastError!,
                      style: const TextStyle(fontSize: 11.5, color: Colors.red, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Auto-sync switch
              Row(
                children: [
                  Transform.scale(
                    scale: 0.75,
                    child: Switch(
                      value: source.autoSync,
                      activeTrackColor: const Color(0xFF0F9D58),
                      onChanged: (val) {
                        if (source.id != null) {
                          provider.toggleSheetAutoSync(source.id!, val);
                        }
                      },
                    ),
                  ),
                  Text(
                    "Auto-Sync",
                    style: TextStyle(fontSize: 11.5, color: isDark ? Colors.white70 : Colors.black87),
                  ),
                ],
              ),

              Row(
                children: [
                  // Open in Browser button
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    tooltip: "Open in Google Sheets",
                    onPressed: () async {
                      try {
                        final uri = Uri.parse(source.url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      } catch (_) {}
                    },
                  ),

                  // Manual Sync button
                  IconButton(
                    icon: const Icon(Icons.sync_rounded, size: 20, color: Color(0xFF0F9D58)),
                    tooltip: "Sync Now",
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      if (source.id == null) return;
                      final (success, error) = await provider.syncGoogleSheet(source.id!);
                      if (context.mounted) {
                        if (success) {
                          AppToast.showSuccess(
                            context,
                            title: "Sheet Synchronized",
                            message: "Refreshed records from '${source.name}'",
                            icon: Icons.sync_rounded,
                            badgeTag: "UPDATED",
                          );
                        } else {
                          AppToast.showError(
                            context,
                            title: "Sync Failed",
                            message: error ?? "Check sheet sharing permissions.",
                          );
                        }
                      }
                    },
                  ),

                  // Delete button
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 19, color: Colors.red),
                    tooltip: "Delete Connection",
                    onPressed: () {
                      _confirmDeleteSheetDialog(context, provider, source);
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSheetDialog(BuildContext context, StudentProvider provider, GoogleSheetSource source) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text("Unlink '${source.name}'?"),
          ],
        ),
        content: const Text(
          "Do you want to delete this Google Sheet connection?\n\nYou can choose to also remove all synchronized students from this sheet or keep them locally.",
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (source.id != null) {
                provider.deleteGoogleSheet(source.id!, deleteStudents: false);
                AppToast.showInfo(
                  context,
                  title: "Sheet Unlinked",
                  message: "Students retained as local entries",
                  icon: Icons.link_off_rounded,
                );
              }
            },
            child: const Text("Keep Students"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (source.id != null) {
                provider.deleteGoogleSheet(source.id!, deleteStudents: true);
                AppToast.showSuccess(
                  context,
                  title: "Sheet Removed",
                  message: "Sheet and associated records removed",
                  icon: Icons.delete_forever_rounded,
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete All"),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Spreadsheet Column Guide Card
  // ----------------------------------------------------

  Widget _buildColumnGuideCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header clickable toggle
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() {
                _isColumnGuideExpanded = !_isColumnGuideExpanded;
              });
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                "Spreadsheet Column Guide",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "8 Fields",
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF6366F1),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          "Auto-mapped columns recognized by Birthday Radar",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    _isColumnGuideExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: const Color(0xFF6366F1),
                    size: 24,
                  ),
                ],
              ),
            ),
          ),

          // Mini Excel Sheet Visual Demonstration
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131B2A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.preview_rounded, size: 14, color: Color(0xFF6366F1)),
                      const SizedBox(width: 6),
                      Text(
                        "Sample Spreadsheet Format Preview",
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2638) : Colors.white,
                          border: Border.all(
                            color: isDark ? const Color(0xFF2A364F) : const Color(0xFFCBD5E1),
                            width: 0.8,
                          ),
                        ),
                        child: Table(
                          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                          defaultColumnWidth: const IntrinsicColumnWidth(),
                          children: [
                            // Table Header Row
                            TableRow(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF263248) : const Color(0xFFF1F5F9),
                              ),
                              children: [
                                _buildTableColHeader("Student Name *", isRequired: true, isDark: isDark),
                                _buildTableColHeader("DOB *", isRequired: true, isDark: isDark),
                                _buildTableColHeader("Class / Batch", isRequired: false, isDark: isDark),
                                _buildTableColHeader("Roll No", isRequired: false, isDark: isDark),
                                _buildTableColHeader("Student Phone", isRequired: false, isDark: isDark),
                                _buildTableColHeader("Parent Phone", isRequired: false, isDark: isDark),
                              ],
                            ),
                            // Sample Row 1
                            TableRow(
                              children: [
                                _buildTableCell("Aarav Sharma", isHighlight: true, isDark: isDark),
                                _buildTableCell("14/09/2004", isHighlight: true, isDark: isDark),
                                _buildTableCell("BCA - DS", isHighlight: false, isDark: isDark),
                                _buildTableCell("DS-01", isHighlight: false, isDark: isDark),
                                _buildTableCell("+91 98765 43210", isHighlight: false, isDark: isDark),
                                _buildTableCell("+91 98765 00001", isHighlight: false, isDark: isDark),
                              ],
                            ),
                            // Sample Row 2
                            TableRow(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF161F30) : const Color(0xFFF8FAFC),
                              ),
                              children: [
                                _buildTableCell("Diya Patel", isHighlight: true, isDark: isDark),
                                _buildTableCell("28/11/2004", isHighlight: true, isDark: isDark),
                                _buildTableCell("BCA - AIML", isHighlight: false, isDark: isDark),
                                _buildTableCell("AI-04", isHighlight: false, isDark: isDark),
                                _buildTableCell("+91 98765 43211", isHighlight: false, isDark: isDark),
                                _buildTableCell("+91 98765 00002", isHighlight: false, isDark: isDark),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Template Download Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadTemplate(isExcel: true),
                    icon: const Icon(Icons.file_download_rounded, size: 16, color: Color(0xFF10B981)),
                    label: const Text(
                      "Download .xlsx Template",
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF10B981)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _downloadTemplate(isExcel: false),
                    icon: const Icon(Icons.file_download_rounded, size: 16, color: Color(0xFF6366F1)),
                    label: const Text(
                      "Download .csv Template",
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF6366F1)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Expanded Column Breakdown List
          if (_isColumnGuideExpanded) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Recognized Column Synonyms",
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Birthday Radar automatically maps synonyms regardless of uppercase or lowercase headers:",
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 10),
                  ...ExcelService.applicationColumns.map((col) => _buildColumnGuideItem(col, isDark)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  Widget _buildTableColHeader(String text, {required bool isRequired, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Text(
        text,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: isRequired
              ? (isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5))
              : (isDark ? Colors.grey.shade300 : const Color(0xFF475569)),
        ),
      ),
    );
  }

  Widget _buildTableCell(String text, {required bool isHighlight, required bool isDark}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Text(
        text,
        softWrap: false,
        maxLines: 1,
        overflow: TextOverflow.visible,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: isHighlight ? FontWeight.w600 : FontWeight.normal,
          color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
        ),
      ),
    );
  }

  Widget _buildColumnGuideItem(RosterColumnDefinition col, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF131B2A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: col.isRequired
                ? (isDark ? const Color(0xFF4F46E5).withValues(alpha: 0.3) : const Color(0xFF6366F1).withValues(alpha: 0.2))
                : (isDark ? const Color(0xFF263248) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  col.name,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: col.isRequired
                        ? Colors.red.withValues(alpha: 0.12)
                        : Colors.blue.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    col.isRequired ? "REQUIRED" : "OPTIONAL",
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: col.isRequired ? Colors.red : const Color(0xFF3B82F6),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              "Synonyms: ${col.recognizedHeaders.join(', ')}",
              style: TextStyle(fontSize: 10.5, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // File Drop Zone
  // ----------------------------------------------------

  Widget _buildFileDropZone(bool isDark) {
    return InkWell(
      onTap: _isProcessing ? null : _pickFile,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2638) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF6366F1).withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: _isProcessing
                  ? const CircularProgressIndicator(color: Color(0xFF6366F1))
                  : const Icon(
                      Icons.upload_file_rounded,
                      size: 40,
                      color: Color(0xFF6366F1),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              "Select Student Roster File",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "Tap to browse your device (.xlsx, .xls, or .csv)",
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // Active Parsed Preview Table & Confirm
  // ----------------------------------------------------

  Widget _buildRosterPreviewSection(bool isDark) {
    final result = _currentParseResult!;
    final students = result.students;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Preview Parsed Students (${students.length})",
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            TextButton.icon(
              onPressed: _clearPreview,
              icon: const Icon(Icons.close_rounded, size: 16, color: Colors.red),
              label: const Text("Clear", style: TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // File details pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              const Icon(Icons.file_present_rounded, size: 16, color: Color(0xFF6366F1)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  "${result.fileName} • ${_isDemoData ? 'Demo Dataset' : '${(result.fileSize / 1024).toStringAsFixed(1)} KB'}",
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Student preview cards list
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2638) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
            ),
          ),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: students.length > 10 ? 10 : students.length,
            separatorBuilder: (ctx, i) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final student = students[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: student.avatarColor.withValues(alpha: 0.15),
                      child: Text(
                        student.initials,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: student.avatarColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                student.name,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                              if (student.rollNo != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF2A364F) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    student.rollNo!,
                                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "${student.groupClass ?? 'No class'} • DOB: ${student.formattedDob}",
                            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                    if (student.phone != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.phone_rounded, size: 14, color: Color(0xFF25D366)),
                      ),
                    if (student.parentPhone != null)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.family_restroom_rounded, size: 14, color: Color(0xFF6366F1)),
                      ),
                  ],
                ),
              );
            },
          ),
        ),

        if (students.length > 10)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Center(
              child: Text(
                "+ ${students.length - 10} more records in this file",
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ),
          ),

        const SizedBox(height: 12),

        // Confirm Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : _commitImport,
            icon: const Icon(Icons.cloud_download_rounded),
            label: Text(
              "Confirm & Save ${students.length} Records to Database",
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),
      ],
    );
  }
}
