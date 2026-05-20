import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // ADDED: For Haptic Feedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/repositories/attendance_repository.dart';
import '../../../data/local/app_database.dart';
import '../../../providers/db_provider.dart';

class AttendanceMarkingScreen extends ConsumerStatefulWidget {
  final String subjectName;
  final int semester;
  final String section;
  final String date;

  const AttendanceMarkingScreen({
    super.key,
    required this.subjectName,
    required this.semester,
    required this.section,
    required this.date,
  });

  @override
  ConsumerState<AttendanceMarkingScreen> createState() => _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends ConsumerState<AttendanceMarkingScreen> {
  bool _isLoading = true;
  List<CachedStudent> _students = [];

  // Stores only the IDs of present students. Everyone else is implicitly absent.
  final Set<String> _presentStudentIds = {};

  @override
  void initState() {
    super.initState();
    _loadStudentsAndExistingRecord();
  }

  Future<void> _loadStudentsAndExistingRecord() async {
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final db = ref.read(dbProvider);

      // 1. Load the student roster
      final students = await repo.getStudents(widget.semester, widget.section);

      // 2. Check if an attendance record already exists for this class/date
      final cleanSubject = widget.subjectName.replaceAll(' ', '_');
      final normalizedSection = widget.section.toUpperCase().trim();
      final String attendanceId = "${cleanSubject}_${widget.semester}_${normalizedSection}_${widget.date}";

      final existingRecord = await (db.select(db.attendanceRecords)
        ..where((a) => a.attendanceId.equals(attendanceId)))
          .getSingleOrNull();

      // 3. If it exists, pre-load the present students into our Set so the teacher can edit them
      if (existingRecord != null && mounted) {
        final presentIds = List<String>.from(jsonDecode(existingRecord.presentStudentIds));
        _presentStudentIds.addAll(presentIds);
      }

      if (mounted) {
        setState(() {
          _students = students;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("DEBUG: Failed to load students or existing record: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load students"), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  // MODIFICATION: No setState here. The child widget repaints itself instantly,
  // we just silently record the state change for saving later. (Huge performance boost)
  void _toggleAttendance(String studentId, bool isPresent) {
    if (isPresent) {
      _presentStudentIds.add(studentId);
    } else {
      _presentStudentIds.remove(studentId);
    }
  }

  // MODIFICATION: Added Bulk Actions
  void _markAllPresent() {
    HapticFeedback.mediumImpact(); // iOS UX action confirm
    setState(() {
      _presentStudentIds.addAll(_students.map((s) => s.studentId));
    });
  }

  void _markAllAbsent() {
    HapticFeedback.mediumImpact(); // iOS UX action confirm
    setState(() {
      _presentStudentIds.clear();
    });
  }

  void _showSaveConfirmationDialog() {
    HapticFeedback.mediumImpact(); // iOS UX prompt
    final int presentCount = _presentStudentIds.length;
    final int absentCount = _students.length - presentCount;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: const Color(0xFF2C2C2E), // Dark grey from mockup
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 30.h, horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Present  :  ", style: TextStyle(color: Colors.white, fontSize: 22.sp)),
                    Text(
                        presentCount.toString().padLeft(2, '0'),
                        style: TextStyle(color: const Color(0xFF34C759), fontSize: 22.sp) // Green
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Absent   :  ", style: TextStyle(color: Colors.white, fontSize: 22.sp)),
                    Text(
                        absentCount.toString().padLeft(2, '0'),
                        style: TextStyle(color: const Color(0xFFFF3B30), fontSize: 22.sp) // Red
                    ),
                  ],
                ),
                SizedBox(height: 40.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                          "Cancel",
                          style: TextStyle(color: const Color(0xFFFF3B30), fontSize: 18.sp, fontWeight: FontWeight.w500)
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.heavyImpact(); // Confirm save
                        Navigator.pop(context); // Close dialog
                        _saveAttendance();
                      },
                      child: Text(
                          "Save",
                          style: TextStyle(color: const Color(0xFF5667FD), fontSize: 18.sp, fontWeight: FontWeight.w500)
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
  }

  Future<void> _saveAttendance() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(attendanceRepositoryProvider).saveAttendance(
        subjectName: widget.subjectName,
        semester: widget.semester,
        section: widget.section,
        date: widget.date,
        presentStudentIds: _presentStudentIds.toList(),
      );

      if (mounted) {
        Navigator.pop(context); // Return to setup screen/home
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Attendance saved successfully!"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      print("DEBUG: Error saving attendance: $e");
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to save attendance."), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "Attendance",
          style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w500),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5667FD)))
          : SafeArea(
        child: Column(
          children: [
            SizedBox(height: 10.h),

            // MODIFICATION: Top Bar for Bulk Actions (iOS Style)
            if (_students.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _markAllAbsent,
                      child: Text("Absent All", style: TextStyle(color: const Color(0xFFFF3B30), fontSize: 16.sp, fontWeight: FontWeight.w500)),
                    ),
                    TextButton(
                      onPressed: _markAllPresent,
                      child: Text("Present All", style: TextStyle(color: const Color(0xFF34C759), fontSize: 16.sp, fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _students.isEmpty
                  ? Center(
                child: Text(
                  "No students found for this section.",
                  style: TextStyle(color: Colors.white54, fontSize: 16.sp),
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 28.w, vertical: 8.h),
                itemCount: _students.length,
                physics: const BouncingScrollPhysics(), // Native iOS scroll feel
                itemBuilder: (context, index) {
                  final student = _students[index];
                  final isPresent = _presentStudentIds.contains(student.studentId);

                  // MODIFICATION: Use the micro-targeted stateful widget
                  return _StudentTile(
                    key: ValueKey("${student.studentId}_$isPresent"), // Forces rebuild ONLY if bulk action changes initial state
                    student: student,
                    initialIsPresent: isPresent,
                    onToggle: (newStatus) => _toggleAttendance(student.studentId, newStatus),
                  );
                },
              ),
            ),

            // Save Button Area
            if (_students.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(left: 28.w, right: 28.w, bottom: 40.h, top: 10.h),
                child: SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _showSaveConfirmationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5667FD),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24.r),
                      ),
                    ),
                    child: Text(
                      "Save",
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// MODIFICATION: Extracted Stateful Widget for Micro-Targeted Rebuilds
class _StudentTile extends StatefulWidget {
  final CachedStudent student;
  final bool initialIsPresent;
  final ValueChanged<bool> onToggle;

  const _StudentTile({
    super.key,
    required this.student,
    required this.initialIsPresent,
    required this.onToggle,
  });

  @override
  State<_StudentTile> createState() => _StudentTileState();
}

class _StudentTileState extends State<_StudentTile> {
  late bool _isPresent;

  @override
  void initState() {
    super.initState();
    _isPresent = widget.initialIsPresent;
  }

  @override
  Widget build(BuildContext context) {
    final displayId = widget.student.studentId.length >= 3
        ? widget.student.studentId.substring(widget.student.studentId.length - 3)
        : widget.student.studentId;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick(); // iOS UX micro-interaction
        setState(() => _isPresent = !_isPresent);
        widget.onToggle(_isPresent);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150), // Snappy native feel
        margin: EdgeInsets.only(bottom: 16.h),
        padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
        decoration: BoxDecoration(
          color: _isPresent ? const Color(0xFF34C759) : const Color(0xFFFF3B30),
          borderRadius: BorderRadius.circular(30.r), // Pill shape matching mockup
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50.w,
              child: Text(
                displayId,
                style: TextStyle(color: Colors.black87, fontSize: 18.sp, fontWeight: FontWeight.w500),
              ),
            ),
            Expanded(
              child: Text(
                widget.student.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.black87, fontSize: 18.sp, fontWeight: FontWeight.w500),
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              _isPresent ? "P" : "A",
              style: TextStyle(color: Colors.black87, fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}