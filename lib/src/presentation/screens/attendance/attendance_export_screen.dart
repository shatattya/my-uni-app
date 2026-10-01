import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../data/local/app_database.dart';
import '../../../data/repositories/attendance_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../routes/app_router.dart';

class AttendanceExportScreen extends ConsumerStatefulWidget {
  const AttendanceExportScreen({super.key});

  @override
  ConsumerState<AttendanceExportScreen> createState() =>
      _AttendanceExportScreenState();
}

class _AttendanceExportScreenState
    extends ConsumerState<AttendanceExportScreen> {
  bool isLoading = true;
  bool isSyncing = false;

  int _pendingSyncs = 0;
  List<AttendanceRecord> _history = [];
  int _historyLimit = 25;
  String? _teacherId;

  bool isExporting = false;

  List<Map<String, dynamic>> availableClasses = [];

  String? selectedCourse;
  int? selectedSemester;
  String? selectedSection;

  DateTime startDate =
  DateTime.now().subtract(
    const Duration(days: 30),
  );

  DateTime endDate =
  DateTime.now();

  String selectedMode = 'Linear';

  final TextEditingController
  maxMarksController =
  TextEditingController(
    text: '10',
  );

  bool _isReportSectionExpanded =
  true;

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
      final firebaseUser =
          firebase_auth.FirebaseAuth.instance.currentUser;

      if (firebaseUser != null) {
        final user = await ref
            .read(userRepositoryProvider)
            .getUserLocally(
          firebaseUser.uid,
        );

        if (user != null) {
          _teacherId = user.internalId;

          final classes = await ref
              .read(
            attendanceRepositoryProvider,
          )
              .getTeacherClasses(
            user.internalId,
          );

          if (mounted) {
            setState(() {
              availableClasses =
                  classes;
            });
          }
        }
      }

      await _loadDashboardData();
    } catch (e, stackTrace) {
      debugPrint(
        'Attendance dashboard: failed to load initial data: $e',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDashboardData() async {
    try {
      final repo = ref.read(
        attendanceRepositoryProvider,
      );

      final pending =
      await repo.getPendingSyncCount();

      final history =
      await repo.getRecentAttendance(
        limit: _historyLimit,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _pendingSyncs = pending;
        _history = history;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'Attendance dashboard: failed to load dashboard data: $e',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _handleSync() async {
    if (isSyncing) {
      return;
    }

    final teacherId = _teacherId;

    if (teacherId == null ||
        teacherId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Authentication error. Please log in again.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      isSyncing = true;
    });

    try {
      final hasUpdates = await ref
          .read(
        attendanceRepositoryProvider,
      )
          .syncPendingRecords(
        teacherId,
      );

      await _loadDashboardData();

      if (!mounted) {
        return;
      }

      if (hasUpdates) {
        _showSyncDialog(
          title: 'Sync complete',
          message:
          'Attendance data was synchronized with the cloud and local cache.',
          isError: false,
        );
      } else {
        _showSyncDialog(
          title: 'Already up to date',
          message:
          'There were no new attendance changes to synchronize.',
          isError: false,
        );
      }
    } catch (e, stackTrace) {
      debugPrint(
        'Attendance dashboard: sync failed: $e',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();

        _showSyncDialog(
          title: 'Sync failed',
          message:
          e.toString().replaceFirst(
            'Exception: ',
            '',
          ),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSyncing = false;
        });
      }
    }
  }

  void _showSyncDialog({
    required String title,
    required String message,
    required bool isError,
  }) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme =
        Theme.of(dialogContext);
        final colorScheme =
            theme.colorScheme;

        return AlertDialog(
          icon: Icon(
            isError
                ? Icons.sync_problem_outlined
                : Icons.cloud_done_outlined,
            size: 32.r,
            color: isError
                ? colorScheme.error
                : colorScheme.primary,
          ),
          title: Text(
            title,
            textAlign:
            TextAlign.center,
          ),
          content: Text(
            message,
            textAlign:
            TextAlign.center,
            style:
            theme.textTheme.bodyMedium?.copyWith(
              color:
              colorScheme
                  .onSurfaceVariant,
              height: 1.4,
            ),
          ),
          actions: [
            FilledButton(
              onPressed: () {
                HapticFeedback.lightImpact();

                Navigator.of(
                  dialogContext,
                ).pop();
              },
              child: const Text(
                'Done',
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadMoreHistory() async {
    if (isLoading) {
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _historyLimit += 5;
      isLoading = true;
    });

    await _loadDashboardData();
  }

  List<String> get _uniqueCourses {
    final courses = <String>{};

    for (final entry in availableClasses) {
      final value = entry['subjectName'];

      if (value is String &&
          value.trim().isNotEmpty) {
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
      if (entry['subjectName'] !=
          selectedCourse) {
        continue;
      }

      final value =
      entry['semester'];

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
      if (entry['subjectName'] !=
          selectedCourse ||
          entry['semester'] !=
              selectedSemester) {
        continue;
      }

      final value =
      entry['section'];

      if (value is String &&
          value.trim().isNotEmpty) {
        sections.add(
          value.trim().toUpperCase(),
        );
      }
    }

    final result = sections.toList()..sort();

    return result;
  }

  bool get _isReportConfigurationValid {
    if (selectedCourse == null ||
        selectedSemester == null ||
        selectedSection == null) {
      return false;
    }

    if (endDate.isBefore(startDate)) {
      return false;
    }

    final maxMarks =
    double.tryParse(
      maxMarksController.text.trim(),
    );

    return maxMarks != null &&
        maxMarks > 0;
  }

  Future<void> _handleExport() async {
    if (selectedCourse == null ||
        selectedSemester == null ||
        selectedSection == null) {
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

    if (endDate.isBefore(startDate)) {
      HapticFeedback.heavyImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'The end date cannot be before the start date.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final maxMarks =
    double.tryParse(
      maxMarksController.text.trim(),
    );

    if (maxMarks == null ||
        maxMarks <= 0) {
      HapticFeedback.heavyImpact();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a valid positive number for Max Marks.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (isExporting) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      isExporting = true;
    });

    try {
      final path = await ref
          .read(
        attendanceRepositoryProvider,
      )
          .generateCsvReport(
        subjectName:
        selectedCourse!,
        semester:
        selectedSemester!,
        section:
        selectedSection!,
        startDate: startDate,
        endDate: endDate,
        maxMarks: maxMarks,
        mode: selectedMode,
      );

      if (!mounted) {
        return;
      }

      await Share.shareXFiles(
        [
          XFile(path),
        ],
        text:
        'Attendance Report - ${selectedCourse!}',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Attendance dashboard: report generation failed: $e',
      );
      debugPrintStack(
        stackTrace: stackTrace,
      );

      if (mounted) {
        HapticFeedback.heavyImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Failed to generate the attendance report.',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  Future<void> _pickDate({
    required DateTime currentDate,
    required ValueChanged<DateTime> onChanged,
    required DateTime minimumDate,
    required DateTime maximumDate,
  }) async {
    HapticFeedback.lightImpact();

    await showCupertinoModalPopup<void>(
      context: context,
      builder: (pickerContext) {
        final surface =
            Theme.of(context)
                .colorScheme
                .surface;

        return Container(
          height: 300.h,
          decoration: BoxDecoration(
            color: surface,
            borderRadius:
            BorderRadius.vertical(
              top:
              Radius.circular(
                20.r,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                SizedBox(
                  height: 52.h,
                  child: Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,
                    children: [
                      CupertinoButton(
                        padding:
                        EdgeInsets.symmetric(
                          horizontal:
                          16.w,
                        ),
                        onPressed: () {
                          Navigator.of(
                            pickerContext,
                          ).pop();
                        },
                        child:
                        const Text(
                          'Cancel',
                        ),
                      ),
                      Text(
                        'Select date',
                        style:
                        TextStyle(
                          color:
                          Colors.white,
                          fontSize:
                          15.sp,
                          fontWeight:
                          FontWeight
                              .w600,
                        ),
                      ),
                      CupertinoButton(
                        padding:
                        EdgeInsets.symmetric(
                          horizontal:
                          16.w,
                        ),
                        onPressed: () {
                          Navigator.of(
                            pickerContext,
                          ).pop();
                        },
                        child:
                        const Text(
                          'Done',
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child:
                  CupertinoDatePicker(
                    backgroundColor:
                    surface,
                    initialDateTime:
                    currentDate,
                    minimumDate:
                    minimumDate,
                    maximumDate:
                    maximumDate,
                    mode:
                    CupertinoDatePickerMode
                        .date,
                    onDateTimeChanged:
                        (newDate) {
                      HapticFeedback
                          .selectionClick();

                      onChanged(
                        newDate,
                      );
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
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return GestureDetector(
      onTap: () =>
          FocusScope.of(context)
              .unfocus(),
      child: Scaffold(
        backgroundColor:
        theme.scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor:
          theme.scaffoldBackgroundColor,
          surfaceTintColor:
          Colors.transparent,
          elevation: 0,
          centerTitle: false,
          iconTheme:
          IconThemeData(
            color:
            colorScheme
                .onSurface,
          ),
          title: Column(
            crossAxisAlignment:
            CrossAxisAlignment
                .start,
            children: [
              Text(
                'Attendance Dashboard',
                style: theme
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
              Text(
                'Reports, sync, and recent entries',
                style: theme
                    .textTheme
                    .labelMedium
                    ?.copyWith(
                  color:
                  colorScheme
                      .onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        body: isLoading &&
            _history.isEmpty
            ? Center(
          child:
          CircularProgressIndicator(
            color: colorScheme
                .primary,
          ),
        )
            : SafeArea(
          child: RefreshIndicator(
            color:
            colorScheme.primary,
            onRefresh: () async {
              HapticFeedback
                  .lightImpact();

              await _loadDashboardData();
            },
            child: LayoutBuilder(
              builder:
                  (context, constraints) {
                final horizontalPadding =
                constraints.maxWidth >=
                    800
                    ? 56.w
                    : 16.w;

                return ListView(
                  physics:
                  const AlwaysScrollableScrollPhysics(
                    parent:
                    BouncingScrollPhysics(),
                  ),
                  padding:
                  EdgeInsets.fromLTRB(
                    horizontalPadding,
                    10.h,
                    horizontalPadding,
                    32.h,
                  ),
                  children: [
                    ConstrainedBox(
                      constraints:
                      const BoxConstraints(
                        maxWidth: 900,
                      ),
                      child:
                      _buildSyncSection(
                        context,
                      ),
                    ),
                    SizedBox(
                      height: 24.h,
                    ),
                    ConstrainedBox(
                      constraints:
                      const BoxConstraints(
                        maxWidth: 900,
                      ),
                      child:
                      _buildReportSection(
                        context,
                      ),
                    ),
                    SizedBox(
                      height: 28.h,
                    ),
                    ConstrainedBox(
                      constraints:
                      const BoxConstraints(
                        maxWidth: 900,
                      ),
                      child:
                      _buildHistorySection(
                        context,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSyncSection(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return Container(
      padding:
      EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color:
        colorScheme.surface,
        borderRadius:
        BorderRadius.circular(
          14.r,
        ),
        border: Border.all(
          color:
          colorScheme.outline
              .withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44.r,
            height: 44.r,
            decoration:
            BoxDecoration(
              color:
              colorScheme.primary
                  .withValues(
                alpha: 0.10,
              ),
              borderRadius:
              BorderRadius.circular(
                10.r,
              ),
            ),
            child: Icon(
              Icons.cloud_sync_outlined,
              color:
              colorScheme.primary,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment
                  .start,
              children: [
                Text(
                  'Cloud sync',
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                    FontWeight
                        .w700,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  _pendingSyncs == 1
                      ? '1 record pending upload'
                      : '$_pendingSyncs records pending upload',
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color:
                    colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10.w),
          if (isSyncing)
            SizedBox(
              width: 24.r,
              height: 24.r,
              child:
              CircularProgressIndicator(
                strokeWidth: 2,
                color:
                colorScheme
                    .primary,
              ),
            )
          else
            OutlinedButton(
              onPressed:
              _handleSync,
              child:
              const Text(
                'Sync',
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReportSection(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color:
        colorScheme.surface,
        borderRadius:
        BorderRadius.circular(
          14.r,
        ),
        border: Border.all(
          color:
          colorScheme.outline
              .withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Theme(
        data: theme.copyWith(
          dividerColor:
          Colors.transparent,
        ),
        child: ExpansionTile(
          initiallyExpanded:
          _isReportSectionExpanded,
          onExpansionChanged:
              (expanded) {
            setState(() {
              _isReportSectionExpanded =
                  expanded;
            });
          },
          tilePadding:
          EdgeInsets.symmetric(
            horizontal: 16.w,
            vertical: 4.h,
          ),
          childrenPadding:
          EdgeInsets.fromLTRB(
            16.w,
            0,
            16.w,
            16.h,
          ),
          leading: Container(
            width: 40.r,
            height: 40.r,
            decoration:
            BoxDecoration(
              color:
              colorScheme
                  .primary
                  .withValues(
                alpha: 0.10,
              ),
              borderRadius:
              BorderRadius.circular(
                10.r,
              ),
            ),
            child: Icon(
              Icons
                  .description_outlined,
              color:
              colorScheme.primary,
            ),
          ),
          title: Text(
            'Generate CSV report',
            style: theme
                .textTheme
                .titleSmall
                ?.copyWith(
              fontWeight:
              FontWeight.w700,
            ),
          ),
          subtitle: Text(
            _isReportConfigurationValid
                ? '${selectedCourse!} · Sem ${selectedSemester!} · Sec ${selectedSection!}'
                : 'Choose the class, date range, and report settings',
            maxLines: 2,
            overflow:
            TextOverflow.ellipsis,
            style: theme
                .textTheme
                .bodySmall
                ?.copyWith(
              color:
              colorScheme
                  .onSurfaceVariant,
            ),
          ),
          children: [
            SizedBox(height: 8.h),
            _buildSectionLabel(
              context,
              'Course',
            ),
            SizedBox(height: 6.h),
            _buildDropdownField<String>(
              context: context,
              value: selectedCourse,
              hintText:
              'Select course',
              items: _uniqueCourses
                  .map(
                    (course) =>
                    DropdownMenuItem<
                        String>(
                      value:
                      course,
                      child:
                      Text(
                        course,
                        overflow:
                        TextOverflow
                            .ellipsis,
                      ),
                    ),
              )
                  .toList(),
              onChanged:
              _uniqueCourses.isEmpty
                  ? null
                  : (value) {
                HapticFeedback
                    .selectionClick();

                setState(() {
                  selectedCourse =
                      value;
                  selectedSemester =
                  null;
                  selectedSection =
                  null;
                });
              },
            ),
            SizedBox(height: 16.h),

            _buildSectionLabel(
              context,
              'Semester',
            ),
            SizedBox(height: 6.h),
            _buildDropdownField<int>(
              context: context,
              value:
              selectedSemester,
              hintText:
              selectedCourse ==
                  null
                  ? 'Select a course first'
                  : 'Select semester',
              items:
              _availableSemesters
                  .map(
                    (semester) =>
                    DropdownMenuItem<
                        int>(
                      value:
                      semester,
                      child:
                      Text(
                        semester
                            .toString(),
                      ),
                    ),
              )
                  .toList(),
              onChanged:
              selectedCourse ==
                  null ||
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
            SizedBox(height: 16.h),

            _buildSectionLabel(
              context,
              'Section',
            ),
            SizedBox(height: 6.h),
            _buildDropdownField<String>(
              context: context,
              value:
              selectedSection,
              hintText:
              selectedSemester ==
                  null
                  ? 'Select a semester first'
                  : 'Select section',
              items:
              _availableSections
                  .map(
                    (section) =>
                    DropdownMenuItem<
                        String>(
                      value:
                      section,
                      child:
                      Text(
                        section,
                      ),
                    ),
              )
                  .toList(),
              onChanged:
              selectedSemester ==
                  null ||
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
            SizedBox(height: 16.h),

            _buildSectionLabel(
              context,
              'Date range',
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Expanded(
                  child:
                  _buildDateField(
                    context: context,
                    label: 'From',
                    selectedDate:
                    startDate,
                    onDateChanged:
                        (value) {
                      setState(() {
                        startDate =
                            value;
                      });
                    },
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child:
                  _buildDateField(
                    context: context,
                    label: 'To',
                    selectedDate:
                    endDate,
                    onDateChanged:
                        (value) {
                      setState(() {
                        endDate =
                            value;
                      });
                    },
                  ),
                ),
              ],
            ),

            if (endDate.isBefore(
              startDate,
            )) ...[
              SizedBox(height: 8.h),
              Row(
                children: [
                  Icon(
                    Icons
                        .error_outline_rounded,
                    size: 16.r,
                    color:
                    colorScheme
                        .error,
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      'End date must be on or after the start date.',
                      style: theme
                          .textTheme
                          .labelMedium
                          ?.copyWith(
                        color:
                        colorScheme
                            .error,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            SizedBox(height: 16.h),

            _buildSectionLabel(
              context,
              'Mode',
            ),
            SizedBox(height: 6.h),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment<String>(
                  value: 'Linear',
                  label: Text(
                    'Linear',
                  ),
                ),
                ButtonSegment<String>(
                  value: 'Bucketed',
                  label: Text(
                    'Bucketed',
                  ),
                ),
              ],
              selected: {
                selectedMode,
              },
              onSelectionChanged:
                  (selection) {
                if (selection.isEmpty) {
                  return;
                }

                HapticFeedback
                    .selectionClick();

                setState(() {
                  selectedMode =
                      selection.first;
                });
              },
            ),

            SizedBox(height: 16.h),

            _buildSectionLabel(
              context,
              'Maximum marks',
            ),
            SizedBox(height: 6.h),
            TextField(
              controller:
              maxMarksController,
              keyboardType:
              const TextInputType
                  .numberWithOptions(
                decimal: true,
              ),
              textInputAction:
              TextInputAction.done,
              onChanged: (_) {
                setState(() {});
              },
              decoration:
              InputDecoration(
                hintText:
                'e.g. 10',
                prefixIcon:
                const Icon(
                  Icons
                      .scoreboard_outlined,
                ),
                filled: true,
                fillColor:
                colorScheme
                    .surface,
                border:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    12.r,
                  ),
                ),
                enabledBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    12.r,
                  ),
                  borderSide:
                  BorderSide(
                    color: colorScheme
                        .outline
                        .withValues(
                      alpha: 0.45,
                    ),
                  ),
                ),
                focusedBorder:
                OutlineInputBorder(
                  borderRadius:
                  BorderRadius
                      .circular(
                    12.r,
                  ),
                  borderSide:
                  BorderSide(
                    color: colorScheme
                        .primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),

            SizedBox(height: 20.h),

            SizedBox(
              width:
              double.infinity,
              child:
              FilledButton.icon(
                onPressed:
                isExporting ||
                    !_isReportConfigurationValid
                    ? null
                    : _handleExport,
                icon: isExporting
                    ? SizedBox(
                  width: 20.r,
                  height: 20.r,
                  child:
                  const CircularProgressIndicator(
                    strokeWidth:
                    2,
                    color:
                    Colors.white,
                  ),
                )
                    : const Icon(
                  Icons
                      .file_download_outlined,
                ),
                label: Text(
                  isExporting
                      ? 'Generating...'
                      : 'Export CSV',
                ),
                style:
                FilledButton
                    .styleFrom(
                  minimumSize:
                  Size(
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
  }

  Widget _buildHistorySection(
      BuildContext context,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return Column(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Recent entries',
                style: theme
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                  fontWeight:
                  FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${_history.length}',
              style: theme
                  .textTheme
                  .labelLarge
                  ?.copyWith(
                color:
                colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
        SizedBox(height: 10.h),
        if (_history.isEmpty)
          Container(
            width: double.infinity,
            padding:
            EdgeInsets.symmetric(
              horizontal: 20.w,
              vertical: 28.h,
            ),
            decoration:
            BoxDecoration(
              color:
              colorScheme.surface,
              borderRadius:
              BorderRadius.circular(
                14.r,
              ),
              border: Border.all(
                color: colorScheme
                    .outline
                    .withValues(
                  alpha: 0.35,
                ),
              ),
            ),
            child: Column(
              children: [
                Icon(
                  Icons
                      .history_outlined,
                  size: 42.r,
                  color:
                  colorScheme
                      .onSurfaceVariant,
                ),
                SizedBox(height: 10.h),
                Text(
                  'No attendance records found.',
                  textAlign:
                  TextAlign.center,
                  style: theme
                      .textTheme
                      .bodyLarge
                      ?.copyWith(
                    fontWeight:
                    FontWeight.w600,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'Saved attendance entries will appear here.',
                  textAlign:
                  TextAlign.center,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color:
                    colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        else
          ..._history.map(
                (record) =>
                Padding(
                  padding:
                  EdgeInsets.only(
                    bottom: 8.h,
                  ),
                  child:
                  _buildHistoryItem(
                    context,
                    record,
                  ),
                ),
          ),
        if (_history.length >=
            _historyLimit) ...[
          SizedBox(height: 8.h),
          SizedBox(
            width:
            double.infinity,
            child:
            OutlinedButton(
              onPressed: isLoading
                  ? null
                  : _loadMoreHistory,
              child:
              const Text(
                'Load more',
              ),
              style:
              OutlinedButton.styleFrom(
                minimumSize:
                Size(
                  double.infinity,
                  48.h,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildHistoryItem(
      BuildContext context,
      AttendanceRecord record,
      ) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    final dateObj =
    DateTime.tryParse(
      record.date,
    );

    final displayDate =
    dateObj != null
        ? DateFormat(
      'dd MMM yyyy',
    ).format(dateObj)
        : record.date;

    final stateColor =
    record.isSynced
        ? colorScheme.primary
        : Colors.orange;

    final stateLabel =
    record.isSynced
        ? 'Synced'
        : 'Pending';

    return Semantics(
      button: true,
      label:
      '${record.subjectId}, '
          'semester ${record.semester}, '
          'section ${record.section}, '
          '$displayDate, '
          '$stateLabel',
      child: Material(
        color:
        colorScheme.surface,
        borderRadius:
        BorderRadius.circular(
          12.r,
        ),
        child: InkWell(
          borderRadius:
          BorderRadius.circular(
            12.r,
          ),
          onTap: () {
            HapticFeedback.lightImpact();

            Navigator.pushNamed(
              context,
              AppRoutes.attendanceMarking,
              arguments: {
                'subjectName':
                record.subjectId,
                'semester':
                record.semester,
                'section':
                record.section,
                'date':
                record.date,
              },
            ).then(
                  (_) =>
                  _loadDashboardData(),
            );
          },
          child: ConstrainedBox(
            constraints:
            BoxConstraints(
              minHeight: 72.h,
            ),
            child: Padding(
              padding:
              EdgeInsets.symmetric(
                horizontal: 14.w,
                vertical: 10.h,
              ),
              child: Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 44.h,
                    decoration:
                    BoxDecoration(
                      color:
                      stateColor,
                      borderRadius:
                      BorderRadius
                          .circular(
                        99.r,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                      crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                      children: [
                        Text(
                          record
                              .subjectId,
                          maxLines: 1,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style: theme
                              .textTheme
                              .bodyLarge
                              ?.copyWith(
                            fontWeight:
                            FontWeight
                                .w700,
                          ),
                        ),
                        SizedBox(
                            height: 4.h),
                        Text(
                          'Sem ${record.semester} · '
                              'Sec ${record.section} · '
                              '$displayDate',
                          maxLines: 2,
                          overflow:
                          TextOverflow
                              .ellipsis,
                          style: theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                            color: colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                    children: [
                      Container(
                        padding:
                        EdgeInsets
                            .symmetric(
                          horizontal:
                          8.w,
                          vertical:
                          5.h,
                        ),
                        decoration:
                        BoxDecoration(
                          color: stateColor
                              .withValues(
                            alpha:
                            0.10,
                          ),
                          borderRadius:
                          BorderRadius
                              .circular(
                            7.r,
                          ),
                        ),
                        child: Text(
                          stateLabel,
                          style: theme
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                            color:
                            stateColor,
                            fontWeight:
                            FontWeight
                                .w800,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 4.h,
                      ),
                      Icon(
                        Icons
                            .chevron_right_rounded,
                        color: colorScheme
                            .onSurfaceVariant,
                        size: 20.r,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(
      BuildContext context,
      String label,
      ) {
    return Text(
      label,
      style: Theme.of(context)
          .textTheme
          .labelLarge
          ?.copyWith(
        fontWeight:
        FontWeight.w700,
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required BuildContext context,
    required T? value,
    required String hintText,
    required List<DropdownMenuItem<T>>
    items,
    required ValueChanged<T?>?
    onChanged,
  }) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    return DropdownButtonFormField<T>(
      value: value,
      isExpanded: true,
      items:
      items.isEmpty ? null : items,
      onChanged: onChanged,
      style: TextStyle(
        color:
        colorScheme.onSurface,
        fontSize: 15.sp,
      ),
      dropdownColor:
      colorScheme.surface,
      icon: const Icon(
        Icons
            .keyboard_arrow_down_rounded,
      ),
      decoration:
      InputDecoration(
        hintText: hintText,
        filled: true,
        fillColor:
        colorScheme.surface,
        border:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            12.r,
          ),
        ),
        enabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            12.r,
          ),
          borderSide:
          BorderSide(
            color: colorScheme
                .outline
                .withValues(
              alpha:
              0.45,
            ),
          ),
        ),
        focusedBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            12.r,
          ),
          borderSide:
          BorderSide(
            color:
            colorScheme
                .primary,
            width: 1.5,
          ),
        ),
        disabledBorder:
        OutlineInputBorder(
          borderRadius:
          BorderRadius.circular(
            12.r,
          ),
          borderSide:
          BorderSide(
            color: colorScheme
                .outline
                .withValues(
              alpha:
              0.20,
            ),
          ),
        ),
        contentPadding:
        EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: 13.h,
        ),
      ),
    );
  }

  Widget _buildDateField({
    required BuildContext context,
    required String label,
    required DateTime selectedDate,
    required ValueChanged<DateTime>
    onDateChanged,
  }) {
    final theme =
    Theme.of(context);
    final colorScheme =
        theme.colorScheme;

    final formatted =
    DateFormat(
      'dd MMM yyyy',
    ).format(selectedDate);

    final minimumDate =
    DateTime(2020);

    final maximumDate =
    DateTime.now().add(
      const Duration(days: 365),
    );

    return Semantics(
      button: true,
      label:
      '$label date $formatted',
      child: Material(
        color:
        colorScheme.surface,
        borderRadius:
        BorderRadius.circular(
          12.r,
        ),
        child: InkWell(
          onTap: () =>
              _pickDate(
                currentDate:
                selectedDate,
                onChanged:
                onDateChanged,
                minimumDate:
                minimumDate,
                maximumDate:
                maximumDate,
              ),
          borderRadius:
          BorderRadius.circular(
            12.r,
          ),
          child: ConstrainedBox(
            constraints:
            BoxConstraints(
              minHeight: 54.h,
            ),
            child: Padding(
              padding:
              EdgeInsets.symmetric(
                horizontal: 12.w,
                vertical: 8.h,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment
                    .start,
                mainAxisAlignment:
                MainAxisAlignment
                    .center,
                children: [
                  Text(
                    label,
                    style: theme
                        .textTheme
                        .labelSmall
                        ?.copyWith(
                      color: colorScheme
                          .onSurfaceVariant,
                    ),
                  ),
                  SizedBox(
                      height: 2.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatted,
                          style: theme
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ),
                      Icon(
                        Icons
                            .calendar_today_outlined,
                        size: 17.r,
                        color:
                        colorScheme
                            .primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}