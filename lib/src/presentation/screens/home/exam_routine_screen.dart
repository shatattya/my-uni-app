import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../../../data/local/app_database.dart';
import '../../../data/repositories/exam_routine_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/local_notification_service.dart';

class ExamRoutineScreen extends ConsumerStatefulWidget {
  const ExamRoutineScreen({super.key});

  @override
  ConsumerState<ExamRoutineScreen> createState() => _ExamRoutineScreenState();
}

class _ExamRoutineScreenState extends ConsumerState<ExamRoutineScreen> {
  Timer? _timer;
  DateTime _currentTime = DateTime.now();
  bool _isOffSeason = false;
  bool _isLoading = true;
  List<String> _retakeIds = [];
  String _examTitle = "Loading...";

  // MODIFICATION: Added vibrant card colors to match RoutineTab
  final List<Color> cardColors = [
    const Color(0xFF5C6BC0),
    const Color(0xFF9C27B0),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFFE91E63),
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
    _syncAndSchedule();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _syncAndSchedule() async {
    final examRepo = ref.read(examRoutineRepositoryProvider);

    // 1. Fetch Local Metadata
    final title = await examRepo.getCurrentExamTitle();
    final retakes = await examRepo.getRetakeIds();
    final offSeason = await examRepo.areExamsOver();

    if (mounted) {
      setState(() {
        _examTitle = title;
        _retakeIds = retakes;
        _isOffSeason = offSeason;
        _isLoading = false;
      });
    }

    // 2. Fetch user info to schedule isolated notifications natively
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser != null) {
      final userStream = ref.read(userRepositoryProvider).watchUser(firebaseUser.uid);
      final userData = await userStream.first;
      if (userData != null) {
        // Schedule alarms for main exams + retakes
        final exams = await examRepo.watchStudentExams(userData.semester, userData.section, _retakeIds).first;
        await ref.read(localNotificationServiceProvider).scheduleExamNotifications(exams);
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime _getExamDateTime(ExamRoutine exam) {
    try {
      final timeParts = exam.startTime.split(':');
      return DateTime(
        exam.date.year,
        exam.date.month,
        exam.date.day,
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
    } catch (_) {
      return exam.date;
    }
  }

  String _formatDuration(Duration duration) {
    if (duration.isNegative) return "00 : 00 : 00 : 00";
    final days = duration.inDays.toString().padLeft(2, '0');
    final hours = (duration.inHours % 24).toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$days : $hours : $minutes : $seconds";
  }

  String _formatWeekday(DateTime date) {
    return DateFormat('EEEE').format(date);
  }

  // Conflict Detection Engine for the Bottom Sheet
  bool _hasConflict(ExamRoutine newExam, List<ExamRoutine> currentExams) {
    final newStart = _getExamDateTime(newExam);
    for (var current in currentExams) {
      if (current.id == newExam.id) continue; // Safety check
      final currentStart = _getExamDateTime(current);
      if (currentStart.year == newStart.year &&
          currentStart.month == newStart.month &&
          currentStart.day == newStart.day &&
          currentStart.hour == newStart.hour &&
          currentStart.minute == newStart.minute) {
        return true;
      }
    }
    return false;
  }

  // Global conflict detector for the main UI list
  Set<String> _getConflictingExamIds(List<ExamRoutine> exams) {
    Set<String> conflicts = {};
    for (int i = 0; i < exams.length; i++) {
      for (int j = i + 1; j < exams.length; j++) {
        final e1 = exams[i];
        final e2 = exams[j];
        final t1 = _getExamDateTime(e1);
        final t2 = _getExamDateTime(e2);

        if (t1.year == t2.year &&
            t1.month == t2.month &&
            t1.day == t2.day &&
            t1.hour == t2.hour &&
            t1.minute == t2.minute) {
          conflicts.add(e1.id);
          conflicts.add(e2.id);
        }
      }
    }
    return conflicts;
  }

  // The Premium Bottom Sheet for selecting Retakes with Real-Time Search
  void _showAddRetakesSheet(int mySem, String mySec, List<ExamRoutine> currentExams) {
    String searchQuery = ""; // Local state for the search bar

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) {
          return StatefulBuilder(
              builder: (context, setSheetState) {
                return DraggableScrollableSheet(
                  initialChildSize: 0.85,
                  minChildSize: 0.5,
                  maxChildSize: 0.95,
                  builder: (context, scrollController) {
                    return Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E1E),
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                      ),
                      child: Column(
                        children: [
                          // Header
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Add Retakes / Improvement",
                                  style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold),
                                ),
                                IconButton(
                                  icon: Icon(Icons.close_rounded, color: Colors.white, size: 28.r),
                                  onPressed: () => Navigator.pop(context),
                                ),
                              ],
                            ),
                          ),

                          // iOS-Style Search Bar
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                            child: TextField(
                              style: TextStyle(color: Colors.white, fontSize: 15.sp),
                              onChanged: (value) {
                                setSheetState(() {
                                  searchQuery = value.toLowerCase();
                                });
                              },
                              decoration: InputDecoration(
                                hintText: "Search course name...",
                                hintStyle: const TextStyle(color: Colors.white54),
                                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.3),
                                contentPadding: EdgeInsets.symmetric(vertical: 12.h),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),

                          Divider(color: Colors.white.withValues(alpha: 0.1), height: 16.h),

                          // List of Other Exams
                          Expanded(
                            child: StreamBuilder<List<ExamRoutine>>(
                              stream: ref.read(examRoutineRepositoryProvider).watchOtherExams(mySem, mySec),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));

                                var otherExams = snapshot.data!;

                                // Apply real-time text filter
                                if (searchQuery.isNotEmpty) {
                                  otherExams = otherExams.where((e) => e.subjectName.toLowerCase().contains(searchQuery)).toList();
                                }

                                if (otherExams.isEmpty) {
                                  return Center(
                                    child: Text(
                                      searchQuery.isEmpty ? "No valid courses available." : "No courses match your search.",
                                      style: TextStyle(color: Colors.white54, fontSize: 15.sp),
                                    ),
                                  );
                                }

                                return ListView.separated(
                                  controller: scrollController,
                                  padding: EdgeInsets.all(20.r),
                                  itemCount: otherExams.length,
                                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                                  itemBuilder: (context, index) {
                                    final exam = otherExams[index];
                                    final isSelected = _retakeIds.contains(exam.id);

                                    return Container(
                                      decoration: BoxDecoration(
                                        color: isSelected ? const Color(0xFF1877F2).withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(16.r),
                                        border: Border.all(
                                          color: isSelected ? const Color(0xFF1877F2) : Colors.transparent,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: ListTile(
                                        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                                        title: Text(
                                          exam.subjectName,
                                          style: TextStyle(color: Colors.white, fontSize: 15.sp, fontWeight: FontWeight.bold),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Padding(
                                          padding: EdgeInsets.only(top: 6.h),
                                          child: Text(
                                            "Sem ${exam.semester} '${exam.section}'  •  ${DateFormat('MMM dd').format(exam.date)} at ${exam.startTime}",
                                            style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                                          ),
                                        ),
                                        trailing: Checkbox(
                                          value: isSelected,
                                          activeColor: const Color(0xFF1877F2),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4.r)),
                                          onChanged: (val) async {
                                            if (val == true) {
                                              if (_hasConflict(exam, currentExams)) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(
                                                      content: Row(
                                                        children: [
                                                          const Icon(Icons.warning_amber_rounded, color: Colors.white),
                                                          SizedBox(width: 12.w),
                                                          const Expanded(child: Text("Time conflict detected with your current routine!", style: TextStyle(color: Colors.white))),
                                                        ],
                                                      ),
                                                      backgroundColor: Colors.orange.shade800,
                                                      behavior: SnackBarBehavior.floating,
                                                      duration: const Duration(seconds: 3),
                                                    )
                                                );
                                              }
                                              _retakeIds.add(exam.id);
                                              currentExams.add(exam);
                                            } else {
                                              _retakeIds.remove(exam.id);
                                              currentExams.removeWhere((e) => e.id == exam.id);
                                            }

                                            // Update UI
                                            setSheetState(() {});
                                            setState(() {});

                                            // Persist to storage
                                            await ref.read(examRoutineRepositoryProvider).saveRetakeIds(_retakeIds);
                                          },
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (firebaseUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final userStream = ref.watch(userRepositoryProvider).watchUser(firebaseUser.uid);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: Column(
          children: [
            Text("Exam Routine", style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 2.h),
            Text(_examTitle, style: TextStyle(color: Colors.white70, fontSize: 12.sp, fontWeight: FontWeight.w400)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)))
          : StreamBuilder(
        stream: userStream,
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const SizedBox();
          final user = userSnapshot.data!;

          return StreamBuilder<List<ExamRoutine>>(
            stream: ref.watch(examRoutineRepositoryProvider).watchStudentExams(user.semester, user.section, _retakeIds),
            builder: (context, examSnapshot) {
              if (!examSnapshot.hasData) return const SizedBox();

              // Filter out exams that have already passed
              final upcomingExams = examSnapshot.data!
                  .where((e) => _getExamDateTime(e).isAfter(_currentTime))
                  .toList();

              // If it's offseason or there are zero exams for the student
              if (_isOffSeason || upcomingExams.isEmpty) {
                return _buildEmptyState();
              }

              final conflictingIds = _getConflictingExamIds(upcomingExams);

              final nextExam = upcomingExams.first;
              final remainingExams = upcomingExams.skip(1).toList();
              final timeRemaining = _getExamDateTime(nextExam).difference(_currentTime);

              return SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCountdownCard(nextExam, timeRemaining, hasConflict: conflictingIds.contains(nextExam.id)),
                    SizedBox(height: 24.h),

                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "Upcoming Exams",
                              style: TextStyle(color: Colors.white, fontSize: 17.sp, fontWeight: FontWeight.w600),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          TextButton.icon(
                            onPressed: () async {
                              final examRepo = ref.read(examRoutineRepositoryProvider);
                              final currentExams = await examRepo.watchStudentExams(user.semester, user.section, _retakeIds).first;
                              if (mounted) _showAddRetakesSheet(user.semester, user.section, currentExams);
                            },
                            icon: Icon(Icons.add_task_rounded, color: const Color(0xFF1877F2), size: 16.r),
                            label: Text(
                                "Add Retake / Imp.",
                                style: TextStyle(color: const Color(0xFF1877F2), fontSize: 12.sp, fontWeight: FontWeight.bold)
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF1877F2).withValues(alpha: 0.15),
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 12.h),
                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                        itemCount: remainingExams.length,
                        itemBuilder: (context, index) {
                          final currentExam = remainingExams[index];
                          // MODIFICATION: Pass dynamic color based on index
                          final cardColor = cardColors[index % cardColors.length];

                          return _buildExamTile(
                              currentExam,
                              cardColor,
                              hasConflict: conflictingIds.contains(currentExam.id)
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCountdownCard(ExamRoutine exam, Duration timeRemaining, {bool hasConflict = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.r),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20.r),
          border: hasConflict ? Border.all(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.5) : null,
          gradient: const LinearGradient(
            colors: [Color(0xFF1877F2), Color(0xFF0B55C4)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1877F2).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              "NEXT EXAM IN",
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.sp, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            SizedBox(height: 12.h),
            Text(
              _formatDuration(timeRemaining),
              style: TextStyle(color: Colors.white, fontSize: 32.sp, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
            SizedBox(height: 4.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTimeUnitLabel("DAYS"),
                _buildTimeUnitLabel("HOURS"),
                _buildTimeUnitLabel("MINS"),
                _buildTimeUnitLabel("SECS"),
              ],
            ),
            SizedBox(height: 24.h),
            Container(
              padding: EdgeInsets.all(16.r),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.r),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(Icons.fact_check_rounded, color: Colors.white, size: 24.r),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.subjectName,
                          style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          "${_formatWeekday(exam.date)}, ${DateFormat('MMM dd, yyyy').format(exam.date)}  \nRoom ${exam.roomNumber}",
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13.sp),
                        ),
                        if (hasConflict) ...[
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 14.r),
                              SizedBox(width: 4.w),
                              Text(
                                "Time conflict detected",
                                style: TextStyle(color: Colors.redAccent, fontSize: 12.sp, fontWeight: FontWeight.bold),
                              ),
                            ],
                          )
                        ]
                      ],
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildTimeUnitLabel(String label) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 10.w),
      child: Text(
        label,
        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10.sp, fontWeight: FontWeight.bold),
      ),
    );
  }

  // MODIFICATION: Accepts dynamic color and adjusts contrast for readability
  Widget _buildExamTile(ExamRoutine exam, Color cardColor, {bool hasConflict = false}) {
    final isRetake = _retakeIds.contains(exam.id);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: cardColor, // Applied dynamic color
        borderRadius: BorderRadius.circular(16.r),
        border: hasConflict
            ? Border.all(color: Colors.redAccent.withValues(alpha: 0.8), width: 1.5)
            : (isRetake ? Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1) : null),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 12.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2), // Whitened for contrast
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Column(
              children: [
                Text(
                  DateFormat('MMM').format(exam.date).toUpperCase(),
                  style: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('dd').format(exam.date),
                  style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold),
                ),
                Text(
                  _formatWeekday(exam.date).substring(0, 3).toUpperCase(),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10.sp, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exam.subjectName,
                  style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 6.h),
                Row(
                  children: [
                    Icon(Icons.access_time_rounded, color: Colors.white70, size: 14.r), // Whitened for contrast
                    SizedBox(width: 4.w),
                    Text(
                      "${exam.startTime} - ${exam.endTime}",
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                    SizedBox(width: 8.w),
                    Icon(Icons.room_rounded, color: Colors.white70, size: 14.r), // Whitened for contrast
                    SizedBox(width: 4.w),
                    Expanded(
                      child: Text(
                        exam.roomNumber,
                        style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (hasConflict) ...[
                  SizedBox(height: 6.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.25), // Pill background guarantees contrast
                      borderRadius: BorderRadius.circular(4.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.redAccent.shade100, size: 12.r),
                        SizedBox(width: 4.w),
                        Text(
                          "Time conflict detected",
                          style: TextStyle(color: Colors.redAccent.shade100, fontSize: 11.sp, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                ]
              ],
            ),
          ),
          if (isRetake)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25), // Pill background guarantees contrast
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                "RETAKE",
                style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.bold),
              ),
            )
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.r),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.celebration_rounded, color: Colors.greenAccent, size: 60.r),
          ),
          SizedBox(height: 24.h),
          Text(
            "Hooray!",
            style: TextStyle(color: Colors.white, fontSize: 24.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            "No exams right now.\nTake a deep breath and relax.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 14.sp, height: 1.5),
          ),
        ],
      ),
    );
  }
}