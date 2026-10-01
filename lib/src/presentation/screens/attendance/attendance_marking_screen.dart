import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../data/local/app_database.dart';
import '../../../data/models/attendance_draft.dart';
import '../../../data/repositories/attendance_repository.dart';
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
  ConsumerState<AttendanceMarkingScreen> createState() =>
      _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState
    extends ConsumerState<AttendanceMarkingScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  List<CachedStudent> _students = [];

  // Only present students are stored.
  // Students absent from this set are considered absent.
  final Set<String> _presentStudentIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadStudentsAndExistingRecord();
  }

  Future<void> _loadStudentsAndExistingRecord() async {
    try {
      final repo = ref.read(attendanceRepositoryProvider);
      final db = ref.read(dbProvider);

      final students = await repo.getStudents(widget.semester, widget.section);

      final normalizedSubject = _normalizeSubject(widget.subjectName);
      final normalizedSection = widget.section.trim().toUpperCase();
      final normalizedDate = widget.date.trim();

      final existingRecord =
          await (db.select(db.attendanceRecords)
                ..where((a) => a.subjectId.equals(normalizedSubject))
                ..where((a) => a.semester.equals(widget.semester))
                ..where((a) => a.section.equals(normalizedSection))
                ..where((a) => a.date.equals(normalizedDate)))
              .getSingleOrNull();

      if (existingRecord != null) {
        _presentStudentIds
          ..clear()
          ..addAll(_decodePresentStudentIds(existingRecord.presentStudentIds));
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _students = students;
        _isLoading = false;
      });
    } on FirebaseException catch (e, stackTrace) {
      debugPrint(
        'Attendance: Firebase error while loading attendance: '
        '${e.code}: ${e.message}',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Failed to load attendance data.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('Attendance: failed to load students or existing record: $e');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to load students.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  String _normalizeSubject(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  Set<String> _decodePresentStudentIds(String json) {
    try {
      final decoded = jsonDecode(json);

      if (decoded is! List) {
        return <String>{};
      }

      return decoded
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (e) {
      debugPrint('Attendance: malformed local presentStudentIds: $e');

      return <String>{};
    }
  }

  void _toggleAttendance(String studentId, bool isPresent) {
    final normalizedId = studentId.trim();

    if (normalizedId.isEmpty) {
      return;
    }

    if (isPresent) {
      _presentStudentIds.add(normalizedId);
    } else {
      _presentStudentIds.remove(normalizedId);
    }
  }

  void _markAllPresent() {
    if (_isSaving || _students.isEmpty) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _presentStudentIds.addAll(
        _students
            .map((student) => student.studentId.trim())
            .where((id) => id.isNotEmpty),
      );
    });
  }

  void _markAllAbsent() {
    if (_isSaving || _students.isEmpty) {
      return;
    }

    HapticFeedback.mediumImpact();

    setState(() {
      _presentStudentIds.clear();
    });
  }

  Future<void> _showSaveConfirmationDialog() async {
    if (_isSaving || _students.isEmpty) {
      return;
    }

    HapticFeedback.mediumImpact();

    final presentCount = _presentStudentIds.length;
    final absentCount = _students.length - presentCount;

    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final colorScheme = theme.colorScheme;

        return AlertDialog(
          title: const Text('Save attendance?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogSummaryRow(
                context: dialogContext,
                icon: Icons.check_circle_outline_rounded,
                label: 'Present',
                value: presentCount,
                valueColor: colorScheme.primary,
              ),
              SizedBox(height: 10.h),
              _buildDialogSummaryRow(
                context: dialogContext,
                icon: Icons.cancel_outlined,
                label: 'Absent',
                value: absentCount,
                valueColor: colorScheme.error,
              ),
              SizedBox(height: 16.h),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${widget.subjectName} · '
                  'Sem ${widget.semester} · '
                  'Sec ${widget.section}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                HapticFeedback.heavyImpact();

                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave == true && mounted) {
      await _saveAttendance();
    }
  }

  Widget _buildDialogSummaryRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required int value,
    required Color valueColor,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: valueColor),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value.toString(),
          style: theme.textTheme.titleMedium?.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Future<void> _saveAttendance() async {
    if (_isSaving || !mounted) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final result = await ref
          .read(attendanceRepositoryProvider)
          .saveAttendance(
            subjectName: widget.subjectName,
            semester: widget.semester,
            section: widget.section,
            date: widget.date,
            presentStudentIds: _presentStudentIds.toList(),
          );

      if (!mounted) {
        return;
      }

      final String message;

      switch (result) {
        case AttendanceSaveResult.cloudSynced:
          message = 'Attendance saved successfully.';
        case AttendanceSaveResult.queuedForSync:
          message = 'Attendance saved locally and queued for synchronization.';
      }

      final messenger = ScaffoldMessenger.of(context);

      messenger.showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: result == AttendanceSaveResult.cloudSynced
              ? Colors.green
              : Colors.orange,
        ),
      );

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    } on AttendanceAuthorizationException catch (e) {
      _showError(e.message);
    } on AttendanceConflictException catch (e) {
      _showError(e.message);
    } on AttendanceValidationException catch (e) {
      _showError(e.message);
    } on AttendanceException catch (e) {
      _showError(e.message);
    } on FirebaseException catch (e) {
      debugPrint(
        'Attendance: unexpected Firebase error: '
        '${e.code}: ${e.message}',
      );

      _showError(e.message ?? 'Failed to save attendance.');
    } catch (e, stackTrace) {
      debugPrint('Attendance: unexpected save error: $e');
      debugPrintStack(stackTrace: stackTrace);

      _showError('Failed to save attendance.');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) {
      return;
    }

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final presentCount = _presentStudentIds.length;
    final absentCount = (_students.length - presentCount).clamp(
      0,
      _students.length,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              widget.subjectName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
          : SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 10.h),
                    child: _buildSummaryHeader(
                      context,
                      presentCount,
                      absentCount,
                    ),
                  ),

                  if (_students.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSaving ? null : _markAllAbsent,
                              icon: const Icon(Icons.remove_done_rounded),
                              label: const Text('Mark all absent'),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size(0, 48.h),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _isSaving ? null : _markAllPresent,
                              icon: const Icon(Icons.done_all_rounded),
                              label: const Text('Mark all present'),
                              style: FilledButton.styleFrom(
                                minimumSize: Size(0, 48.h),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  SizedBox(height: 8.h),

                  Expanded(
                    child: _students.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(
                              16.w,
                              4.h,
                              16.w,
                              110.h,
                            ),
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            itemCount: _students.length,
                            separatorBuilder: (_, __) => SizedBox(height: 8.h),
                            itemBuilder: (context, index) {
                              final student = _students[index];

                              final isPresent = _presentStudentIds.contains(
                                student.studentId,
                              );

                              return _StudentTile(
                                key: ValueKey(student.studentId),
                                student: student,
                                initialIsPresent: isPresent,
                                enabled: !_isSaving,
                                onToggle: (newStatus) {
                                  if (_isSaving) {
                                    return;
                                  }

                                  setState(() {
                                    _toggleAttendance(
                                      student.studentId,
                                      newStatus,
                                    );
                                  });
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: _students.isEmpty
          ? null
          : SafeArea(
              minimum: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 12.h),
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _showSaveConfirmationDialog,
                icon: _isSaving
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_isSaving ? 'Saving...' : 'Save attendance'),
                style: FilledButton.styleFrom(
                  minimumSize: Size(double.infinity, 52.h),
                ),
              ),
            ),
    );
  }

  Widget _buildSummaryHeader(
    BuildContext context,
    int presentCount,
    int absentCount,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final total = _students.length;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCountBlock(
              context: context,
              label: 'Present',
              value: presentCount,
              color: colorScheme.primary,
            ),
          ),
          Container(
            width: 1,
            height: 36.h,
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _buildCountBlock(
              context: context,
              label: 'Absent',
              value: absentCount,
              color: colorScheme.error,
            ),
          ),
          Container(
            width: 1,
            height: 36.h,
            color: colorScheme.outline.withValues(alpha: 0.3),
          ),
          Expanded(
            child: _buildCountBlock(
              context: context,
              label: 'Total',
              value: total,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountBlock({
    required BuildContext context,
    required String label,
    required int value,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Text(
          value.toString(),
          style: theme.textTheme.titleLarge?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.r),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 54.r,
              color: colorScheme.onSurfaceVariant,
            ),
            SizedBox(height: 16.h),
            Text(
              'No students found',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'There are no students cached for this section.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentTile extends StatefulWidget {
  final CachedStudent student;
  final bool initialIsPresent;
  final bool enabled;
  final ValueChanged<bool> onToggle;

  const _StudentTile({
    super.key,
    required this.student,
    required this.initialIsPresent,
    required this.enabled,
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
  void didUpdateWidget(covariant _StudentTile oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialIsPresent != widget.initialIsPresent) {
      _isPresent = widget.initialIsPresent;
    }
  }

  void _handleToggle() {
    if (!widget.enabled) {
      return;
    }

    HapticFeedback.selectionClick();

    final newStatus = !_isPresent;

    setState(() {
      _isPresent = newStatus;
    });

    widget.onToggle(newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final studentId = widget.student.studentId;

    final displayId = studentId.length >= 3
        ? studentId.substring(studentId.length - 3)
        : studentId;

    final stateColor = _isPresent ? colorScheme.primary : colorScheme.error;

    final stateLabel = _isPresent ? 'Present' : 'Absent';

    return Semantics(
      container: true,
      button: true,
      enabled: widget.enabled,
      label:
          '${widget.student.name}, '
          'ID ending $displayId, '
          '$stateLabel',
      onTap: widget.enabled ? _handleToggle : null,
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12.r),
        child: InkWell(
          onTap: widget.enabled ? _handleToggle : null,
          borderRadius: BorderRadius.circular(12.r),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 64.h),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              child: Row(
                children: [
                  Container(
                    width: 4.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: stateColor,
                      borderRadius: BorderRadius.circular(99.r),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  SizedBox(
                    width: 44.w,
                    child: Text(
                      displayId,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      widget.student.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Container(
                    constraints: BoxConstraints(minWidth: 76.w),
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 7.h,
                    ),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: stateColor.withValues(alpha: 0.24),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        stateLabel,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: stateColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
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
