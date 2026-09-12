import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/student_provider.dart';
import '../services/toast_service.dart';
import '../widgets/student_action_card.dart';
import '../widgets/student_edit_dialog.dart';

class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({super.key});

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  final List<String> _months = [
    "All Months",
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December"
  ];

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<StudentProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final students = provider.filteredStudents;
    final classList = provider.classList;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Students Directory"),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded),
            tooltip: "Add Student",
            onPressed: () => StudentEditDialog.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Box
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) => provider.setSearchQuery(val),
              decoration: InputDecoration(
                hintText: "Search by student name, roll no, phone...",
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          provider.setSearchQuery('');
                        },
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),

          // Filters Row: Class Chips & Month Dropdown
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Month selector menu
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: provider.selectedMonthFilter != null
                        ? const Color(0xFF6366F1).withValues(alpha: 0.15)
                        : (isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: provider.selectedMonthFilter != null
                            ? const Color(0xFF6366F1)
                            : (isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: provider.selectedMonthFilter,
                          hint: Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 14,
                                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                              ),
                              const SizedBox(width: 6),
                              const Text("Month", style: TextStyle(fontSize: 12)),
                            ],
                          ),
                          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          dropdownColor: isDark ? const Color(0xFF1E2638) : Colors.white,
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text("All Months"),
                            ),
                            ...List.generate(12, (index) {
                              return DropdownMenuItem<int?>(
                                value: index + 1,
                                child: Text(_months[index + 1]),
                              );
                            }),
                          ],
                          onChanged: (val) => provider.setMonthFilter(val),
                        ),
                      ),
                    ),
                  ),
                ),

                // All Classes Chip
                _buildClassChip(
                  label: "All Classes (${provider.allStudents.length})",
                  isSelected: provider.selectedClassFilter == null,
                  onTap: () => provider.setClassFilter(null),
                  isDark: isDark,
                ),

                // Class Chips
                ...classList.map((cls) {
                  final isSelected = provider.selectedClassFilter == cls;
                  return _buildClassChip(
                    label: cls,
                    isSelected: isSelected,
                    onTap: () => provider.setClassFilter(isSelected ? null : cls),
                    isDark: isDark,
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Count Info Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Showing ${students.length} of ${provider.allStudents.length} students",
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    ),
                  ),
                ),
                if (provider.searchQuery.isNotEmpty ||
                    provider.selectedClassFilter != null ||
                    provider.selectedMonthFilter != null)
                  InkWell(
                    onTap: () {
                      _searchCtrl.clear();
                      provider.clearFilters();
                    },
                    child: const Text(
                      "Clear Filters",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6366F1),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // Students List
          Expanded(
            child: students.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 54,
                          color: isDark ? Colors.grey.shade700 : Colors.grey.shade400,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "No matching student records found",
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Try adjusting your search query or filters",
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: students.length,
                    padding: const EdgeInsets.only(bottom: 100),
                    itemBuilder: (ctx, i) {
                      final student = students[i];
                      return Dismissible(
                        key: ValueKey(student.id ?? i),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          padding: const EdgeInsets.only(right: 20),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Icon(Icons.delete_rounded, color: Colors.white, size: 28),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Record"),
                              content: Text("Remove ${student.name} from directory?"),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) {
                          final studentName = student.name;
                          provider.deleteStudent(student.id!);
                          AppToast.showInfo(
                            context,
                            title: "Student Deleted",
                            message: "Removed $studentName from records",
                            icon: Icons.delete_outline_rounded,
                            badgeTag: "DELETED",
                          );
                        },
                        child: StudentActionCard(student: student),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: const Color(0xFF6366F1).withValues(alpha: 0.18),
        checkmarkColor: const Color(0xFF6366F1),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          color: isSelected
              ? const Color(0xFF6366F1)
              : (isDark ? Colors.grey.shade300 : const Color(0xFF334155)),
        ),
        backgroundColor: isDark ? const Color(0xFF1E2638) : const Color(0xFFF1F5F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isSelected
                ? const Color(0xFF6366F1)
                : (isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0)),
          ),
        ),
      ),
    );
  }
}
