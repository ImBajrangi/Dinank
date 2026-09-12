import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/student_model.dart';
import '../providers/student_provider.dart';
import '../services/toast_service.dart';

class StudentEditDialog extends StatefulWidget {
  final StudentModel? student;

  const StudentEditDialog({super.key, this.student});

  static Future<void> show(BuildContext context, {StudentModel? student}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentEditDialog(student: student),
    );
  }

  @override
  State<StudentEditDialog> createState() => _StudentEditDialogState();
}

class _StudentEditDialogState extends State<StudentEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _rollController;
  late TextEditingController _classController;
  late TextEditingController _phoneController;
  late TextEditingController _parentPhoneController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;

  late DateTime _selectedDob;

  @override
  void initState() {
    super.initState();
    final s = widget.student;
    _nameController = TextEditingController(text: s?.name ?? '');
    _rollController = TextEditingController(text: s?.rollNo ?? '');
    _classController = TextEditingController(text: s?.groupClass ?? '');
    _phoneController = TextEditingController(text: s?.phone ?? '');
    _parentPhoneController = TextEditingController(text: s?.parentPhone ?? '');
    _emailController = TextEditingController(text: s?.email ?? '');
    _notesController = TextEditingController(text: s?.notes ?? '');
    _selectedDob = s?.dob ?? DateTime(2006, 1, 1);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _rollController.dispose();
    _classController.dispose();
    _phoneController.dispose();
    _parentPhoneController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob,
      firstDate: DateTime(1980),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: const Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Theme.of(context).cardColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
      });
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<StudentProvider>(context, listen: false);
    final updated = StudentModel(
      id: widget.student?.id,
      name: _nameController.text.trim(),
      rollNo: _rollController.text.trim().isEmpty ? null : _rollController.text.trim(),
      groupClass: _classController.text.trim().isEmpty ? null : _classController.text.trim(),
      phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      parentPhone: _parentPhoneController.text.trim().isEmpty ? null : _parentPhoneController.text.trim(),
      email: _emailController.text.trim().isEmpty ? null : _emailController.text.trim(),
      dob: _selectedDob,
      notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    );

    if (widget.student == null) {
      provider.addStudent(updated);
      AppToast.showSuccess(
        context,
        title: "Student Added",
        message: "${updated.name} added to ${updated.groupClass ?? 'student roster'}",
        icon: Icons.school_rounded,
        badgeTag: "ROSTER UPDATED",
      );
    } else {
      provider.updateStudent(updated);
      AppToast.showSuccess(
        context,
        title: "Record Updated",
        message: "Details for ${updated.name} saved successfully",
        icon: Icons.check_circle_rounded,
        badgeTag: "SAVED",
      );
    }

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.student != null;

    return Container(
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2638) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? "Edit Student Record" : "Add New Student",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: "Student Full Name *",
                  prefixIcon: Icon(Icons.person_rounded),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Name is required" : null,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rollController,
                      decoration: const InputDecoration(
                        labelText: "Roll No / ID",
                        prefixIcon: Icon(Icons.badge_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _classController,
                      decoration: const InputDecoration(
                        labelText: "Class / Batch",
                        prefixIcon: Icon(Icons.school_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2B354C) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? const Color(0xFF2A364F) : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.cake_rounded, color: Color(0xFFEC4899), size: 20),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Date of Birth *",
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                ),
                              ),
                              Text(
                                DateFormat('dd MMMM yyyy').format(_selectedDob),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const Icon(Icons.calendar_month_rounded, color: Color(0xFF6366F1)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Student Phone",
                        prefixIcon: Icon(Icons.phone_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _parentPhoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: "Parent Phone",
                        prefixIcon: Icon(Icons.family_restroom_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Teacher Notes / Remarks (Optional)",
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_circle_rounded),
                  label: Text(isEditing ? "Update Student" : "Save Student Record"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
