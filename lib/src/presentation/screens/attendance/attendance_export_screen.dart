import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // ADDED: For iOS Date Picker
import 'package:flutter/services.dart'; // ADDED: For Haptic Feedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:share_plus/share_plus.dart';

import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/local/app_database.dart';
import 'attendance_marking_screen.dart';

class AttendanceExportScreen extends ConsumerStatefulWidget {
  const AttendanceExportScreen({super.key});

  @override
  ConsumerState<AttendanceExportScreen> createState() => _AttendanceExportScreenState();
}

class _AttendanceExportScreenState extends ConsumerState<AttendanceExportScreen> {
  // Dashboard State
  bool isLoading = true;
  bool isSyncing = false;
  int _pendingSyncs = 0;
  List<AttendanceRecord> _history = [];
  int _historyLimit = 25;
  String? _teacherId; // Required for two-way sync

  // Export Form State
  bool isExporting = false;
  List<Map<String, dynamic>> availableClasses = [];
  String? selectedCourse;
  int? selectedSemester;
  String? selectedSection;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();
  String selectedMode = 'Linear';
  final TextEditingController maxMarksController = TextEditingController(text: "10");

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    maxMarksController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final user = await ref.read(userRepositoryProvider).getUserLocally(firebaseUser.uid);
        if (user != null) {
          _teacherId = user.internalId; // Store for sync logic
          final classes = await ref.read(attendanceRepositoryProvider).getTeacherClasses(user.internalId);
          if (mounted) {
            setState(() => availableClasses = classes);
          }
        }
      }
      await _loadDashboardData();
    } catch (e) {
      print("DEBUG: Failed to load initial data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final pending = await repo.getPendingSyncCount();
      final history = await repo.getRecentAttendance(limit: _historyLimit);

      if (mounted) {
        setState(() {
          _pendingSyncs = pending;
          _history = history;
          isLoading = false;
        });
      }
    } catch (e) {
      print("DEBUG: Failed to load dashboard data: $e");
      if (mounted) setState(() => isLoading = false);
    }
  }

  // --- Dashboard Actions ---

  Future<void> _handleSync() async {
    if (_teacherId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Authentication error. Please relogin."), backgroundColor: Colors.redAccent),
      );
      return;
    }

    HapticFeedback.mediumImpact(); // iOS UX action confirm
    setState(() => isSyncing = true);
    try {
      // Execute the two-way sync and capture if updates occurred
      final bool hasUpdates = await ref.read(attendanceRepositoryProvider).syncPendingRecords(_teacherId!);

      await _loadDashboardData(); // Refresh counts and history

      if (mounted) {
        if (hasUpdates) {
          _showSyncDialog(
            title: "Sync Successful",
            message: "New updates are added successfully (for both cloud and local)",
            isError: false,
          );
        } else {
          _showSyncDialog(
            title: "Up to Date",
            message: "All attendances are stored successfully and no new updates.",
            isError: false,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        HapticFeedback.heavyImpact(); // iOS UX error warning
        _showSyncDialog(
          title: "Sync Failed",
          message: "Some error occured, not stored.\n\nError Code: ${e.toString()}",
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => isSyncing = false);
    }
  }

  void _showSyncDialog({required String title, required String message, required bool isError}) {
    showDialog(
      context: context,
      barrierDismissible: false, // Force user to tap "Okay"
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF2C2C2E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Row(
            children: [
              Icon(
                isError ? Icons.error_outline : Icons.check_circle_outline,
                color: isError ? Colors.redAccent : Colors.green,
                size: 28.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            message,
            style: TextStyle(color: Colors.white70, fontSize: 15.sp, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.pop(context);
              },
              child: Text("Okay", style: TextStyle(color: const Color(0xFF5667FD), fontSize: 16.sp, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _loadMoreHistory() {
    HapticFeedback.lightImpact();
    setState(() {
      _historyLimit += 5;
      isLoading = true;
    });
    _loadDashboardData();
  }

  // --- Export Actions ---

  List<String> get _uniqueCourses => availableClasses.map((c) => c["subjectName"] as String).toSet().toList();
  List<int> get _availableSemesters {
    if (selectedCourse == null) return [];
    return availableClasses.where((c) => c["subjectName"] == selectedCourse).map((c) => c["semester"] as int).toSet().toList();
  }
  List<String> get _availableSections {
    if (selectedCourse == null || selectedSemester == null) return [];
    return availableClasses
        .where((c) => c["subjectName"] == selectedCourse && c["semester"] == selectedSemester)
        .map((c) => c["section"] as String).toSet().toList();
  }

  Future<void> _handleExport() async {
    if (selectedCourse == null || selectedSemester == null || selectedSection == null) {
      HapticFeedback.heavyImpact(); // iOS UX error warning
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Course, Semester, and Section"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    final double? maxMarks = double.tryParse(maxMarksController.text.trim());
    if (maxMarks == null || maxMarks <= 0) {
      HapticFeedback.heavyImpact(); // iOS UX error warning
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid number for Max Marks"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    HapticFeedback.mediumImpact(); // iOS UX action confirm
    setState(() => isExporting = true);
    try {
      final path = await ref.read(attendanceRepositoryProvider).generateCsvReport(
        subjectName: selectedCourse!,
        semester: selectedSemester!,
        section: selectedSection!,
        startDate: startDate,
        endDate: endDate,
        maxMarks: maxMarks,
        mode: selectedMode,
      );

      if (mounted) {
        setState(() => isExporting = false);
        await Share.shareXFiles([XFile(path)], text: "Attendance Report - ${selectedCourse!}");
      }
    } catch (e) {
      if (mounted) {
        setState(() => isExporting = false);
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to generate report"), backgroundColor: Colors.redAccent));
      }
    }
  }

  // --- UI Builders ---

  @override
  Widget build(BuildContext context) {
    // MODIFICATION: Wrap in GestureDetector to seamlessly drop keyboard
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          elevation: 0,
          title: Text("Control Center", style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w500)),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: isLoading && _history.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF5667FD)))
            : SafeArea(
          child: RefreshIndicator(
            color: const Color(0xFF5667FD),
            backgroundColor: const Color(0xFF1E1E1E),
            onRefresh: () async {
              HapticFeedback.lightImpact();
              await _loadDashboardData();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSyncCard(),
                    SizedBox(height: 24.h),
                    _buildExportSection(),
                    SizedBox(height: 32.h),
                    Text("Recent Entries", style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                    SizedBox(height: 16.h),
                    _buildHistoryList(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncCard() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFF5667FD).withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: const Color(0xFF5667FD).withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cloud_sync_outlined,
              color: const Color(0xFF5667FD),
              size: 28.sp,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Cloud Sync", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 4.h),
                Text(
                  "$_pendingSyncs records pending upload",
                  style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                ),
              ],
            ),
          ),
          isSyncing
              ? SizedBox(width: 24.w, height: 24.w, child: const CircularProgressIndicator(color: Color(0xFF5667FD), strokeWidth: 2))
              : TextButton(
            onPressed: _handleSync,
            style: TextButton.styleFrom(
              backgroundColor: const Color(0xFF5667FD),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            child: Text("Sync", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Widget _buildExportSection() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: Colors.white,
          collapsedIconColor: Colors.white70,
          title: Text("Generate CSV Report", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
          childrenPadding: EdgeInsets.only(left: 20.w, right: 20.w, bottom: 20.h),
          children: [
            _buildDropdownField<String>(
              label: "Course",
              value: selectedCourse,
              items: _uniqueCourses.map((c) => DropdownMenuItem(value: c, child: Text(c, style: TextStyle(color: Colors.white, fontSize: 16.sp)))).toList(),
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() { selectedCourse = val; selectedSemester = null; selectedSection = null; });
              },
            ),
            SizedBox(height: 20.h),
            _buildDropdownField<int>(
              label: "Semester",
              value: selectedSemester,
              items: _availableSemesters.map((s) => DropdownMenuItem(value: s, child: Text("$s", style: TextStyle(color: Colors.white, fontSize: 16.sp)))).toList(),
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() { selectedSemester = val; selectedSection = null; });
              },
            ),
            SizedBox(height: 20.h),
            _buildDropdownField<String>(
              label: "Section",
              value: selectedSection,
              items: _availableSections.map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: Colors.white, fontSize: 16.sp)))).toList(),
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => selectedSection = val);
              },
            ),
            SizedBox(height: 20.h),
            _buildDateField(
              label: "Date Beginning",
              selectedDate: startDate,
              onDateChanged: (newDate) => setState(() => startDate = newDate),
            ),
            SizedBox(height: 20.h),
            _buildDateField(
              label: "Date End",
              selectedDate: endDate,
              onDateChanged: (newDate) => setState(() => endDate = newDate),
            ),
            SizedBox(height: 20.h),
            _buildDropdownField<String>(
              label: "Mode",
              value: selectedMode,
              items: const [
                DropdownMenuItem(value: "Linear", child: Text("Linear", style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: "Bucketed", child: Text("Bucketed", style: TextStyle(color: Colors.white))),
              ],
              onChanged: (val) {
                HapticFeedback.selectionClick();
                setState(() => selectedMode = val!);
              },
            ),
            SizedBox(height: 20.h),
            _buildTextField(label: "Max Marks", controller: maxMarksController),
            SizedBox(height: 30.h),
            SizedBox(
              width: double.infinity,
              height: 50.h,
              child: ElevatedButton(
                onPressed: isExporting ? null : _handleExport,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5667FD), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r))),
                child: isExporting
                    ? SizedBox(height: 20.h, width: 20.h, child: const CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Export CSV", style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.black)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    if (_history.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.only(top: 20.h),
          child: Text("No attendance records found.", style: TextStyle(color: Colors.white54, fontSize: 16.sp)),
        ),
      );
    }

    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _history.length,
          separatorBuilder: (_, __) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final record = _history[index];
            final dateObj = DateTime.tryParse(record.date);
            final displayDate = dateObj != null ? DateFormat('dd MMM, yyyy').format(dateObj) : record.date;

            return InkWell(
              borderRadius: BorderRadius.circular(12.r),
              onTap: () {
                HapticFeedback.lightImpact(); // iOS UX micro-interaction
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AttendanceMarkingScreen(
                      subjectName: record.subjectId,
                      semester: record.semester,
                      section: record.section,
                      date: record.date,
                    ),
                  ),
                ).then((_) => _loadDashboardData());
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
                decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12.r)),
                child: Row(
                  children: [
                    Container(
                      width: 4.w,
                      height: 40.h,
                      decoration: BoxDecoration(color: record.isSynced ? Colors.green : Colors.orange, borderRadius: BorderRadius.circular(2.r)),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(record.subjectId, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          SizedBox(height: 4.h),
                          Text("Sem ${record.semester} • Sec ${record.section} • $displayDate", style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, color: Colors.white54, size: 20.sp),
                  ],
                ),
              ),
            );
          },
        ),
        if (_history.length >= _historyLimit) ...[
          SizedBox(height: 20.h),
          TextButton(
            onPressed: isLoading ? null : _loadMoreHistory,
            child: Text("Load More", style: TextStyle(color: const Color(0xFF5667FD), fontSize: 16.sp, fontWeight: FontWeight.bold)),
          ),
        ]
      ],
    );
  }

  // --- Helper Widgets for Export Form ---

  Widget _buildDropdownField<T>({required String label, required T? value, required List<DropdownMenuItem<T>> items, required void Function(T?) onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: Text(label, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w500)),
            isExpanded: true,
            icon: Icon(Icons.arrow_drop_down, color: Colors.white, size: 24.sp),
            dropdownColor: const Color(0xFF2C2C2E),
            items: items.isEmpty ? null : items,
            onChanged: onChanged,
            selectedItemBuilder: (BuildContext context) {
              return items.map<Widget>((DropdownMenuItem<T> item) {
                return Row(
                  children: [
                    Text(label, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w500)),
                    const Spacer(),
                    Text(item.value.toString(), style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                  ],
                );
              }).toList();
            },
          ),
        ),
        Container(height: 1.h, color: Colors.white24),
      ],
    );
  }

  // MODIFICATION: Replaced Android Date Picker implementation with Cupertino
  Widget _buildDateField({required String label, required DateTime selectedDate, required Function(DateTime) onDateChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            showCupertinoModalPopup(
              context: context,
              builder: (BuildContext context) => Container(
                height: 250.h,
                color: const Color(0xFF1E1E1E),
                child: SafeArea(
                  top: false,
                  child: CupertinoDatePicker(
                    backgroundColor: const Color(0xFF1E1E1E),
                    initialDateTime: selectedDate,
                    minimumDate: DateTime(2020),
                    maximumDate: DateTime.now().add(const Duration(days: 365)),
                    mode: CupertinoDatePickerMode.date,
                    onDateTimeChanged: (DateTime newDate) {
                      HapticFeedback.selectionClick();
                      onDateChanged(newDate);
                    },
                  ),
                ),
              ),
            );
          },
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w500)),
              Row(
                children: [
                  Text(DateFormat('MMM dd, yyyy').format(selectedDate), style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                  SizedBox(width: 8.w),
                  Icon(Icons.arrow_drop_down, color: Colors.white, size: 24.sp),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 8.h),
        Container(height: 1.h, color: Colors.white24),
      ],
    );
  }

  Widget _buildTextField({required String label, required TextEditingController controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w500)),
            SizedBox(
              width: 80.w,
              child: TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.right,
                style: TextStyle(color: Colors.white70, fontSize: 14.sp),
                decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(height: 1.h, color: Colors.white24),
      ],
    );
  }
}