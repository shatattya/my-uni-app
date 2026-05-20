import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart'; // ADDED: For iOS Date Picker
import 'package:flutter/services.dart'; // ADDED: For Haptic Feedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/user_repository.dart';
import 'attendance_marking_screen.dart';

class AttendanceSetupScreen extends ConsumerStatefulWidget {
  const AttendanceSetupScreen({super.key});

  @override
  ConsumerState<AttendanceSetupScreen> createState() => _AttendanceSetupScreenState();
}

class _AttendanceSetupScreenState extends ConsumerState<AttendanceSetupScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> availableClasses = [];

  String? selectedCourse;
  int? selectedSemester;
  String? selectedSection;
  DateTime selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    try {
      final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        final user = await ref.read(userRepositoryProvider).getUserLocally(firebaseUser.uid);
        if (user != null) {
          final classes = await ref.read(attendanceRepositoryProvider).getTeacherClasses(user.internalId);
          if (mounted) {
            setState(() {
              availableClasses = classes;
              isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print("DEBUG: Failed to load classes: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // Dynamic filtering based on selections
  List<String> get _uniqueCourses {
    return availableClasses.map((c) => c["subjectName"] as String).toSet().toList();
  }

  List<int> get _availableSemesters {
    if (selectedCourse == null) return [];
    return availableClasses
        .where((c) => c["subjectName"] == selectedCourse)
        .map((c) => c["semester"] as int)
        .toSet()
        .toList();
  }

  List<String> get _availableSections {
    if (selectedCourse == null || selectedSemester == null) return [];
    return availableClasses
        .where((c) => c["subjectName"] == selectedCourse && c["semester"] == selectedSemester)
        .map((c) => c["section"] as String)
        .toSet()
        .toList();
  }

  void _onTakeAttendance() {
    if (selectedCourse == null || selectedSemester == null || selectedSection == null) {
      HapticFeedback.heavyImpact(); // iOS UX warning
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Course, Semester, and Section"), backgroundColor: Colors.redAccent),
      );
      return;
    }

    HapticFeedback.mediumImpact(); // iOS UX action confirm
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AttendanceMarkingScreen(
          subjectName: selectedCourse!,
          semester: selectedSemester!,
          section: selectedSection!,
          date: DateFormat('yyyy-MM-dd').format(selectedDate),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF5667FD)))
          : SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 20.h),

              // 1. Course Selection
              _buildDropdownField<String>(
                label: "Course",
                value: selectedCourse,
                items: _uniqueCourses.map((course) {
                  return DropdownMenuItem<String>(
                    value: course,
                    child: Text(course, style: TextStyle(color: Colors.white, fontSize: 18.sp)),
                  );
                }).toList(),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    selectedCourse = val;
                    selectedSemester = null; // Reset dependents
                    selectedSection = null;
                  });
                },
              ),

              SizedBox(height: 40.h),

              // 2. Semester Selection
              _buildDropdownField<int>(
                label: "Semester",
                value: selectedSemester,
                items: _availableSemesters.map((sem) {
                  return DropdownMenuItem<int>(
                    value: sem,
                    child: Text("$sem", style: TextStyle(color: Colors.white, fontSize: 18.sp)),
                  );
                }).toList(),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    selectedSemester = val;
                    selectedSection = null; // Reset dependent
                  });
                },
              ),

              SizedBox(height: 40.h),

              // 3. Section Selection
              _buildDropdownField<String>(
                label: "Section",
                value: selectedSection,
                items: _availableSections.map((sec) {
                  return DropdownMenuItem<String>(
                    value: sec,
                    child: Text(sec, style: TextStyle(color: Colors.white, fontSize: 18.sp)),
                  );
                }).toList(),
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    selectedSection = val;
                  });
                },
              ),

              SizedBox(height: 40.h),

              // 4. Date Selection (MODIFIED: iOS Cupertino Picker)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) => Container(
                          height: 250.h,
                          color: const Color(0xFF1E1E1E), // Match app dark theme
                          child: SafeArea(
                            top: false,
                            child: CupertinoDatePicker(
                              backgroundColor: const Color(0xFF1E1E1E),
                              initialDateTime: selectedDate,
                              minimumDate: DateTime(2020),
                              maximumDate: DateTime.now().add(const Duration(days: 30)),
                              mode: CupertinoDatePickerMode.date,
                              onDateTimeChanged: (DateTime newDate) {
                                HapticFeedback.selectionClick(); // Tactile scrolling
                                setState(() => selectedDate = newDate);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Date",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 22.sp,
                              fontWeight: FontWeight.w500
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              DateFormat('dd MMM, yyyy').format(selectedDate),
                              style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                            ),
                            SizedBox(width: 8.w),
                            Icon(Icons.arrow_drop_down, color: Colors.white, size: 28.sp),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Container(height: 1.h, color: Colors.white),
                ],
              ),

              const Spacer(),

              // Take Attendance Button matching the specific purple/blue from mockup
              SizedBox(
                width: double.infinity,
                height: 56.h,
                child: ElevatedButton(
                  onPressed: _onTakeAttendance,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5667FD),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24.r),
                    ),
                  ),
                  child: Text(
                    "Take Attendance",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.black, // Matching mockup text color logic if standard, but usually it's black/dark on this button
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40.h),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to build the exact underlined UI from the mockup
  Widget _buildDropdownField<T>({
    required String label,
    required T? value,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            hint: Text(
              label,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w500
              ),
            ),
            isExpanded: true,
            icon: Icon(Icons.arrow_drop_down, color: Colors.white, size: 28.sp),
            dropdownColor: const Color(0xFF1E1E1E),
            items: items.isEmpty ? null : items, // Disable if empty
            onChanged: onChanged,
            selectedItemBuilder: (BuildContext context) {
              return items.map<Widget>((DropdownMenuItem<T> item) {
                return Row(
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w500
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item.value.toString(),
                      style: TextStyle(color: Colors.white70, fontSize: 16.sp),
                    ),
                  ],
                );
              }).toList();
            },
          ),
        ),
        SizedBox(height: 4.h),
        Container(height: 1.h, color: Colors.white),
      ],
    );
  }
}