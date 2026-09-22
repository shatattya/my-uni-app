import 'dart:convert';
import '../../../providers/db_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/local/app_database.dart';
import '../../../data/models/attendance_draft.dart';
import '../../../data/repositories/attendance_repository.dart';

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

      // Load the class roster.
      final students = await repo.getStudents(
        widget.semester,
        widget.section,
      );

      final normalizedSubject = _normalizeSubject(widget.subjectName);
      final normalizedSection = widget.section.trim().toUpperCase();
      final normalizedDate = widget.date.trim();

      // Look up the existing local attendance record using its actual
      // identifying fields instead of duplicating the repository's
      // attendance-ID generation logic here.
      final existingRecord = await (db.select(
        db.attendanceRecords,
      )
        ..where(
              (a) => a.subjectId.equals(normalizedSubject),
        )
        ..where(
              (a) => a.semester.equals(widget.semester),
        )
        ..where(
              (a) => a.section.equals(normalizedSection),
        )
        ..where(
              (a) => a.date.equals(normalizedDate),
        ))
          .getSingleOrNull();

      if (existingRecord != null) {
        _presentStudentIds
          ..clear()
          ..addAll(
            _decodePresentStudentIds(
              existingRecord.presentStudentIds,
            ),
          );
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
      debugPrint('$stackTrace');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Failed to load attendance data.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Attendance: failed to load students or existing record: $e',
      );
      debugPrint('$stackTrace');

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
    return value.trim().replaceAll(
      RegExp(r'\s+'),
      ' ',
    );
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
      debugPrint(
        'Attendance: malformed local presentStudentIds: $e',
      );

      return <String>{};
    }
  }

  void _toggleAttendance(
      String studentId,
      bool isPresent,
      ) {
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
      barrierDismissible: !_isSaving,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: const Color(0xFF2C2C2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: 30.h,
              horizontal: 24.w,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Present  :  ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                      ),
                    ),
                    Text(
                      presentCount.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: const Color(0xFF34C759),
                        fontSize: 22.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Absent   :  ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                      ),
                    ),
                    Text(
                      absentCount.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: const Color(0xFFFF3B30),
                        fontSize: 22.sp,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 40.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop(false);
                      },
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: const Color(0xFFFF3B30),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.heavyImpact();
                        Navigator.of(dialogContext).pop(true);
                      },
                      child: Text(
                        'Save',
                        style: TextStyle(
                          color: const Color(0xFF5667FD),
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w500,
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

    if (shouldSave == true && mounted) {
      await _saveAttendance();
    }
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
          message =
          'Attendance saved locally and queued for synchronization.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor:
          result == AttendanceSaveResult.cloudSynced
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

      _showError(
        e.message ?? 'Failed to save attendance.',
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Attendance: unexpected save error: $e',
      );
      debugPrint('$stackTrace');

      _showError(
        'Failed to save attendance.',
      );
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
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
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
        centerTitle: true,
        iconTheme: const IconThemeData(
          color: Colors.white,
        ),
        title: Text(
          'Attendance',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF5667FD),
        ),
      )
          : SafeArea(
        child: Column(
          children: [
            SizedBox(height: 10.h),

            if (_students.isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.w,
                ),
                child: Row(
                  mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed:
                      _isSaving ? null : _markAllAbsent,
                      child: Text(
                        'Absent All',
                        style: TextStyle(
                          color: _isSaving
                              ? const Color(0xFFFF3B30)
                              .withValues(alpha: 0.4)
                              : const Color(0xFFFF3B30),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed:
                      _isSaving ? null : _markAllPresent,
                      child: Text(
                        'Present All',
                        style: TextStyle(
                          color: _isSaving
                              ? const Color(0xFF34C759)
                              .withValues(alpha: 0.4)
                              : const Color(0xFF34C759),
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: _students.isEmpty
                  ? Center(
                child: Text(
                  'No students found for this section.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 16.sp,
                  ),
                ),
              )
                  : ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: 28.w,
                  vertical: 8.h,
                ),
                itemCount: _students.length,
                physics:
                const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  final student = _students[index];

                  final isPresent =
                  _presentStudentIds.contains(
                    student.studentId,
                  );

                  return _StudentTile(
                    key: ValueKey(
                      '${student.studentId}_$isPresent',
                    ),
                    student: student,
                    initialIsPresent: isPresent,
                    onToggle: (newStatus) {
                      if (_isSaving) {
                        return;
                      }

                      _toggleAttendance(
                        student.studentId,
                        newStatus,
                      );
                    },
                  );
                },
              ),
            ),

            if (_students.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  left: 28.w,
                  right: 28.w,
                  bottom: 40.h,
                  top: 10.h,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _isSaving
                        ? null
                        : _showSaveConfirmationDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                      const Color(0xFF5667FD),
                      disabledBackgroundColor:
                      const Color(0xFF5667FD)
                          .withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                        BorderRadius.circular(24.r),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                      width: 24.w,
                      height: 24.w,
                      child:
                      const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      'Save',
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
  void didUpdateWidget(
      covariant _StudentTile oldWidget,
      ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.initialIsPresent !=
        widget.initialIsPresent) {
      _isPresent = widget.initialIsPresent;
    }
  }

  void _handleTap() {
    HapticFeedback.selectionClick();

    final newStatus = !_isPresent;

    setState(() {
      _isPresent = newStatus;
    });

    widget.onToggle(newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final studentId = widget.student.studentId;

    final displayId = studentId.length >= 3
        ? studentId.substring(studentId.length - 3)
        : studentId;

    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedContainer(
        duration: const Duration(
          milliseconds: 150,
        ),
        margin: EdgeInsets.only(
          bottom: 16.h,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: 24.w,
          vertical: 20.h,
        ),
        decoration: BoxDecoration(
          color: _isPresent
              ? const Color(0xFF34C759)
              : const Color(0xFFFF3B30),
          borderRadius: BorderRadius.circular(
            30.r,
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 50.w,
              child: Text(
                displayId,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                widget.student.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Text(
              _isPresent ? 'P' : 'A',
              style: TextStyle(
                color: Colors.black87,
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}