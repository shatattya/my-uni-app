import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';

import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../routes/app_router.dart';

class AttendanceSetupScreen extends ConsumerStatefulWidget {
  const AttendanceSetupScreen({super.key});

  @override
  ConsumerState<AttendanceSetupScreen> createState() =>
      _AttendanceSetupScreenState();
}

class _AttendanceSetupScreenState
    extends ConsumerState<AttendanceSetupScreen> {
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
      final firebaseUser =
          firebase_auth.FirebaseAuth.instance.currentUser;

      if (firebaseUser == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          isLoading = false;
        });
        return;
      }

      final user = await ref
          .read(userRepositoryProvider)
          .getUserLocally(firebaseUser.uid);

      if (user == null) {
        if (!mounted) {
          return;
        }

        setState(() {
          isLoading = false;
        });
        return;
      }

      final classes = await ref
          .read(attendanceRepositoryProvider)
          .getTeacherClasses(user.internalId);

      if (!mounted) {
        return;
      }

      setState(() {
        availableClasses = classes;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'Attendance setup: failed to load classes: $e',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not load your teaching schedule.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  List<String> get _uniqueCourses {
    final courses = <String>{};

    for (final entry in availableClasses) {
      final value = entry['subjectName'];

      if (value is String && value.trim().isNotEmpty) {
        courses.add(value.trim());
      }
    }

    final result = courses.toList()..sort();

    return result;
  }

  List<int> get _availableSemesters {
    if (selectedCourse == null) {
      return const [];
    }

    final semesters = <int>{};

    for (final entry in availableClasses) {
      if (entry['subjectName'] != selectedCourse) {
        continue;
      }

      final value = entry['semester'];

      if (value is int) {
        semesters.add(value);
      }
    }

    final result = semesters.toList()..sort();

    return result;
  }

  List<String> get _availableSections {
    if (selectedCourse == null ||
        selectedSemester == null) {
      return const [];
    }

    final sections = <String>{};

    for (final entry in availableClasses) {
      if (entry['subjectName'] != selectedCourse ||
          entry['semester'] != selectedSemester) {
        continue;
      }

      final value = entry['section'];

      if (value is String && value.trim().isNotEmpty) {
        sections.add(value.trim().toUpperCase());
      }
    }

    final result = sections.toList()..sort();

    return result;
  }

  bool get _canTakeAttendance {
    return selectedCourse != null &&
        selectedSemester != null &&
        selectedSection != null;
  }

  void _onTakeAttendance() {
    if (!_canTakeAttendance) {
      HapticFeedback.heavyImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a course, semester, and section.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    Navigator.pushNamed(
      context,
      AppRoutes.attendanceMarking,
      arguments: {
        'subjectName': selectedCourse!,
        'semester': selectedSemester!,
        'section': selectedSection!,
        'date': DateFormat(
          'yyyy-MM-dd',
        ).format(selectedDate),
      },
    );
  }

  Future<void> _pickDate() async {
    HapticFeedback.lightImpact();

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (pickerContext) {
        return Container(
          height: 300.h,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(20.r),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(
                  height: 52.h,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      CupertinoButton(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                        ),
                        onPressed: () {
                          Navigator.of(pickerContext).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                      Text(
                        'Attendance date',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                        ),
                        onPressed: () {
                          Navigator.of(pickerContext).pop();
                        },
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: CupertinoDatePicker(
                    backgroundColor:
                    Theme.of(context).colorScheme.surface,
                    initialDateTime: selectedDate,
                    minimumDate: DateTime(2020),
                    maximumDate: DateTime.now().add(
                      const Duration(days: 30),
                    ),
                    mode: CupertinoDatePickerMode.date,
                    onDateTimeChanged: (newDate) {
                      HapticFeedback.selectionClick();

                      if (!mounted) {
                        return;
                      }

                      setState(() {
                        selectedDate = newDate;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(
          color: colorScheme.onSurface,
        ),
        title: Text(
          'Take Attendance',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(
          color: colorScheme.primary,
        ),
      )
          : SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding =
            constraints.maxWidth >= 700
                ? 72.w
                : 20.w;

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                12.h,
                horizontalPadding,
                28.h,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 760,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Class details',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Choose the class and date for which you want to record attendance.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 24.h),

                    _buildSectionLabel(
                      context,
                      'Course',
                    ),
                    SizedBox(height: 8.h),
                    _buildDropdownField<String>(
                      context: context,
                      value: selectedCourse,
                      hintText: _uniqueCourses.isEmpty
                          ? 'No courses available'
                          : 'Select course',
                      items: _uniqueCourses
                          .map(
                            (course) =>
                            DropdownMenuItem<String>(
                              value: course,
                              child: Text(
                                course,
                                overflow:
                                TextOverflow.ellipsis,
                              ),
                            ),
                      )
                          .toList(),
                      onChanged: _uniqueCourses.isEmpty
                          ? null
                          : (value) {
                        HapticFeedback.selectionClick();

                        setState(() {
                          selectedCourse = value;
                          selectedSemester = null;
                          selectedSection = null;
                        });
                      },
                    ),

                    SizedBox(height: 20.h),

                    _buildSectionLabel(
                      context,
                      'Semester',
                    ),
                    SizedBox(height: 8.h),
                    _buildDropdownField<int>(
                      context: context,
                      value: selectedSemester,
                      hintText: selectedCourse == null
                          ? 'Select a course first'
                          : _availableSemesters.isEmpty
                          ? 'No semesters available'
                          : 'Select semester',
                      items: _availableSemesters
                          .map(
                            (semester) =>
                            DropdownMenuItem<int>(
                              value: semester,
                              child: Text(
                                semester.toString(),
                              ),
                            ),
                      )
                          .toList(),
                      onChanged:
                      selectedCourse == null ||
                          _availableSemesters
                              .isEmpty
                          ? null
                          : (value) {
                        HapticFeedback
                            .selectionClick();

                        setState(() {
                          selectedSemester =
                              value;
                          selectedSection =
                          null;
                        });
                      },
                    ),

                    SizedBox(height: 20.h),

                    _buildSectionLabel(
                      context,
                      'Section',
                    ),
                    SizedBox(height: 8.h),
                    _buildDropdownField<String>(
                      context: context,
                      value: selectedSection,
                      hintText:
                      selectedSemester == null
                          ? 'Select a semester first'
                          : _availableSections.isEmpty
                          ? 'No sections available'
                          : 'Select section',
                      items: _availableSections
                          .map(
                            (section) =>
                            DropdownMenuItem<String>(
                              value: section,
                              child: Text(section),
                            ),
                      )
                          .toList(),
                      onChanged:
                      selectedSemester == null ||
                          _availableSections
                              .isEmpty
                          ? null
                          : (value) {
                        HapticFeedback
                            .selectionClick();

                        setState(() {
                          selectedSection =
                              value;
                        });
                      },
                    ),

                    SizedBox(height: 20.h),

                    _buildSectionLabel(
                      context,
                      'Date',
                    ),
                    SizedBox(height: 8.h),
                    _buildDateSelector(
                      context,
                    ),

                    SizedBox(height: 28.h),

                    _buildSelectionSummary(
                      context,
                    ),

                    SizedBox(height: 28.h),

                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                        _canTakeAttendance
                            ? _onTakeAttendance
                            : null,
                        icon: const Icon(
                          Icons.fact_check_outlined,
                        ),
                        label: const Text(
                          'Take Attendance',
                        ),
                        style: FilledButton.styleFrom(
                          minimumSize: Size(
                            double.infinity,
                            52.h,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionLabel(
      BuildContext context,
      String label,
      ) {
    final theme = Theme.of(context);

    return Text(
      label,
      style: theme.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required BuildContext context,
    required T? value,
    required String hintText,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?>? onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      items: items.isEmpty ? null : items,
      onChanged: onChanged,
      style: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 16.sp,
      ),
      dropdownColor: colorScheme.surface,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor: colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(
              alpha: 0.45,
            ),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 1.5,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
          borderSide: BorderSide(
            color: colorScheme.outline.withValues(
              alpha: 0.20,
            ),
          ),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16.w,
          vertical: 14.h,
        ),
      ),
      hint: Text(
        hintText,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildDateSelector(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Semantics(
      button: true,
      label:
      'Attendance date ${DateFormat('dd MMMM yyyy').format(selectedDate)}',
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: _pickDate,
          borderRadius: BorderRadius.circular(12.r),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: 52.h,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16.w,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.event_outlined,
                    color: colorScheme.primary,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      DateFormat(
                        'dd MMMM yyyy',
                      ).format(selectedDate),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionSummary(
      BuildContext context,
      ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final hasSelection = _canTakeAttendance;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: colorScheme.outline.withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.start,
        children: [
          Icon(
            hasSelection
                ? Icons.check_circle_outline_rounded
                : Icons.info_outline_rounded,
            color: hasSelection
                ? colorScheme.primary
                : colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  hasSelection
                      ? 'Ready to continue'
                      : 'Selection incomplete',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  hasSelection
                      ? '${selectedCourse!} · Sem ${selectedSemester!} · Sec ${selectedSection!} · ${DateFormat('dd MMM yyyy').format(selectedDate)}'
                      : 'Select all three class fields before starting attendance.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}