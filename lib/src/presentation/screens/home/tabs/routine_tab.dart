import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/routine_repository.dart';

class RoutineTab extends ConsumerStatefulWidget {
  const RoutineTab({super.key});

  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  late DateTime selectedDate;
  late List<DateTime> currentWeek;

  final List<Color> cardColors = [
    const Color(0xFF5C6BC0),
    const Color(0xFF9C27B0),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFFE91E63),
  ];

  static const List<Map<String, String>> _fixedSlots = [
    {"start": "09:30", "end": "10:20"},
    {"start": "10:25", "end": "11:15"},
    {"start": "11:20", "end": "12:10"},
    {"start": "12:15", "end": "13:05"},
    {"start": "13:10", "end": "14:00"},
    {"start": "14:05", "end": "14:55"},
  ];

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
    _generateCurrentWeek();
  }

  void _generateCurrentWeek() {
    DateTime today = DateTime.now();
    int daysToSubtract = today.weekday == 7 ? 0 : today.weekday;
    DateTime startOfWeek = today.subtract(Duration(days: daysToSubtract));
    currentWeek = List.generate(7, (index) => startOfWeek.add(Duration(days: index)));
  }

  int _timeToMinutes(String time) {
    try {
      final cleanTime = time.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = cleanTime.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }

  bool _isClassOngoing(String startTime, String endTime, DateTime classDate) {
    if (classDate.day != DateTime.now().day || classDate.month != DateTime.now().month) return false;

    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;

    int startMin = _timeToMinutes(startTime);
    int endMin = _timeToMinutes(endTime);

    if (endMin < startMin) return false;

    return nowMin >= startMin && nowMin <= endMin;
  }

  List<dynamic> _generateFixedTimeline(List<dynamic> routines) {
    if (routines.isEmpty) return [];

    List<dynamic> timeline = [];
    int colorIndex = 0;

    for (var slot in _fixedSlots) {
      final matchingClasses = routines.where((r) => r.startTime == slot["start"]).toList();

      if (matchingClasses.isNotEmpty) {
        for (var routine in matchingClasses) {
          timeline.add({
            "type": "class",
            "data": routine,
            "color": cardColors[colorIndex % cardColors.length],
          });
          colorIndex++;
        }
      } else {
        timeline.add({
          "type": "break",
          "startTime": slot["start"]!,
          "endTime": slot["end"]!,
          "durationText": "50m",
        });
      }
    }
    return timeline;
  }

  @override
  Widget build(BuildContext context) {
    final uid = firebase_auth.FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Center(child: Text("Please login", style: TextStyle(color: Colors.white, fontSize: 16.sp)));
    }

    return SafeArea(
      child: StreamBuilder(
        stream: ref.watch(userRepositoryProvider).watchUser(uid),
        builder: (context, userSnapshot) {
          if (userSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));
          }

          final user = userSnapshot.data;
          if (user == null) return const SizedBox();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(user.role, user.semester),
              SizedBox(height: 20.h),
              _buildDateSelector(),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                child: const Divider(color: Colors.white24, thickness: 1),
              ),
              _buildTimelineHeader(),
              SizedBox(height: 10.h),

              Expanded(
                child: StreamBuilder(
                  // MODIFICATION: Passing both user.internalId and user.name for the hybrid query
                  stream: user.role == 'teacher'
                      ? ref.watch(routineRepositoryProvider).watchTeacherDailyRoutines(user.internalId, user.name, selectedDate.weekday)
                      : ref.watch(routineRepositoryProvider).watchDailyRoutines(user.semester, user.section, selectedDate.weekday),
                  builder: (context, routineSnapshot) {
                    if (routineSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFF1877F2)));
                    }

                    final routines = routineSnapshot.data ?? [];

                    if (routines.isEmpty) {
                      return _buildFreedomBanner();
                    }

                    final timeline = _generateFixedTimeline(routines);

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                      itemCount: timeline.length,
                      itemBuilder: (context, index) {
                        final item = timeline[index];

                        if (item["type"] == "class") {
                          return _buildRoutineSlot(item["data"], item["color"], user.role);
                        } else {
                          return _buildBreakSlot(item["startTime"], item["endTime"], item["durationText"]);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(String role, int semester) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            DateFormat('dd').format(selectedDate),
            style: TextStyle(color: Colors.white, fontSize: 46.sp, fontWeight: FontWeight.bold, height: 1.0),
          ),
          SizedBox(width: 8.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEE').format(selectedDate),
                style: TextStyle(color: Colors.white54, fontSize: 16.sp),
              ),
              Text(
                DateFormat('MMMM, yyyy').format(selectedDate),
                style: TextStyle(color: Colors.white54, fontSize: 14.sp),
              ),
            ],
          ),
          const Spacer(),
          Text(
            role == 'teacher' ? "Teacher Schedule" : "${semester}th Semester",
            style: TextStyle(color: Colors.white70, fontSize: 16.sp, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: currentWeek.map((date) {
          bool isSelected = date.day == selectedDate.day && date.month == selectedDate.month;

          return GestureDetector(
            onTap: () => setState(() => selectedDate = date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF1877F2) : Colors.transparent,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('E').format(date).substring(0, 1),
                    style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontSize: 14.sp),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    DateFormat('dd').format(date),
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18.sp,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTimelineHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        children: [
          SizedBox(width: 60.w, child: Text("Time", style: TextStyle(color: Colors.white54, fontSize: 16.sp))),
          SizedBox(width: 20.w),
          Text("Courses", style: TextStyle(color: Colors.white54, fontSize: 16.sp)),
        ],
      ),
    );
  }

  Widget _buildRoutineSlot(dynamic routine, Color cardColor, String userRole) {
    bool ongoing = _isClassOngoing(routine.startTime, routine.endTime, selectedDate);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 60.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                Text(routine.startTime, style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                SizedBox(height: 4.h),
                Text(routine.endTime, style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
              ],
            ),
          ),

          Container(
            width: 1.5.w,
            color: Colors.white24,
            margin: EdgeInsets.symmetric(horizontal: 16.w),
          ),

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 20.h),
              child: Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(16.r),
                  border: ongoing ? Border.all(color: Colors.white, width: 2.5.w) : null,
                  boxShadow: ongoing ? [BoxShadow(color: Colors.white.withValues(alpha: 0.3), blurRadius: 10, spreadRadius: 1)] : [],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routine.subjectName,
                      style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 24.h),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, color: Colors.white70, size: 16.sp),
                        SizedBox(width: 8.w),
                        Text("Room ${routine.roomNumber}", style: TextStyle(color: Colors.white70, fontSize: 14.sp)),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        CircleAvatar(
                            radius: 10.r,
                            backgroundColor: Colors.white24,
                            child: Icon(
                                userRole == 'teacher' ? Icons.groups_outlined : Icons.person_outline,
                                size: 12.sp,
                                color: Colors.white
                            )
                        ),
                        SizedBox(width: 8.w),
                        Text(
                            userRole == 'teacher'
                                ? "Sem ${routine.semester} - Sec ${routine.section}"
                                : routine.teacherName,
                            style: TextStyle(color: Colors.white70, fontSize: 14.sp)
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakSlot(String startTime, String endTime, String durationText) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 60.w,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 16.h),
                Text(startTime, style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
                const Spacer(),
                Text(endTime, style: TextStyle(color: Colors.white54, fontSize: 14.sp)),
              ],
            ),
          ),

          Container(
            width: 1.5.w,
            color: Colors.white24,
            margin: EdgeInsets.symmetric(horizontal: 16.w),
          ),

          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: 20.h),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: Colors.white12, width: 1.5.w),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.coffee_outlined, color: Colors.white54, size: 22.sp),
                    SizedBox(width: 12.w),
                    Text(
                      "Break Time ($durationText)",
                      style: TextStyle(color: Colors.white54, fontSize: 18.sp, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreedomBanner() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.celebration_outlined, color: const Color(0xFF1877F2).withValues(alpha: 0.8), size: 80.sp),
          SizedBox(height: 20.h),
          Text(
            "Freedom!",
            style: TextStyle(color: Colors.white, fontSize: 32.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8.h),
          Text(
            "No classes scheduled for this day.",
            style: TextStyle(color: Colors.white54, fontSize: 16.sp),
          ),
        ],
      ),
    );
  }
}