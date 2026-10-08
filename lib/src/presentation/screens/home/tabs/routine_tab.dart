import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../data/repositories/user_repository.dart';
import '../../../../data/repositories/routine_repository.dart';
import '../../../../providers/sync_controller.dart';
import '../../../../providers/notification_settings_provider.dart';
import '../../../../services/local_notification_service.dart';

class RoutineTab extends ConsumerStatefulWidget {
  const RoutineTab({super.key});

  @override
  ConsumerState<RoutineTab> createState() => _RoutineTabState();
}

class _RoutineTabState extends ConsumerState<RoutineTab> {
  late DateTime selectedDate;
  late List<DateTime> currentWeek;

  final List<Color> cardColors = [
    const Color(0xFF315DDB),
    const Color(0xFF8A2BE2),
    const Color(0xFF10A9A2),
    const Color(0xFFC07A18),
    const Color(0xFFB92A76),
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
    final today = DateTime.now();
    final daysToSubtract =
    today.weekday == 7 ? 0 : today.weekday;
    final startOfWeek = today.subtract(
      Duration(days: daysToSubtract),
    );

    currentWeek = List.generate(
      7,
          (index) => startOfWeek.add(
        Duration(days: index),
      ),
    );
  }

  int _timeToMinutes(String time) {
    try {
      final cleanTime =
      time.replaceAll(RegExp(r'[^0-9:]'), '');
      final parts = cleanTime.split(':');

      return int.parse(parts[0]) * 60 +
          int.parse(parts[1]);
    } catch (e) {
      return 0;
    }
  }

  bool _isClassOngoing(
      String startTime,
      String endTime,
      DateTime classDate,
      ) {
    final nowDate = DateTime.now();

    if (classDate.day != nowDate.day ||
        classDate.month != nowDate.month ||
        classDate.year != nowDate.year) {
      return false;
    }

    final now = TimeOfDay.now();

    final nowMin =
        now.hour * 60 + now.minute;

    final startMin =
    _timeToMinutes(startTime);

    final endMin =
    _timeToMinutes(endTime);

    if (endMin < startMin) {
      return false;
    }

    return nowMin >= startMin &&
        nowMin <= endMin;
  }

  List<dynamic> _generateTimeline(
      List<dynamic> routines,
      ) {
    if (routines.isEmpty) {
      return [];
    }

    final List<dynamic> timeline = [];
    int colorIndex = 0;

    for (final slot in _fixedSlots) {
      final matchingClasses = routines
          .where(
            (r) => r.startTime == slot["start"],
      )
          .toList();

      if (matchingClasses.isNotEmpty) {
        for (final routine in matchingClasses) {
          timeline.add({
            "type": "class",
            "data": routine,
            "color":
            cardColors[colorIndex %
                cardColors.length],
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

  Future<List<dynamic>>
  _fetchAllRoutinesSafely(
      dynamic user,
      ) async {
    final List<dynamic> allRoutines = [];

    for (int i = 1; i <= 7; i++) {
      final daily = user.role == 'teacher'
          ? await ref
          .read(
        routineRepositoryProvider,
      )
          .watchTeacherDailyRoutines(
        user.internalId,
        user.name,
        i,
      )
          .first
          : await ref
          .read(
        routineRepositoryProvider,
      )
          .watchDailyRoutines(
        user.semester,
        user.section,
        i,
      )
          .first;

      allRoutines.addAll(daily);
    }

    return allRoutines;
  }

  void _showNotificationSettingsSheet(
      BuildContext context,
      dynamic user,
      ) {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor:
      const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(
        borderRadius:
        BorderRadius.vertical(
          top: Radius.circular(20.r),
        ),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 24.w,
          vertical: 32.h,
        ),
        child: Consumer(
          builder: (
              context,
              ref,
              child,
              ) {
            final settingsAsync = ref.watch(
              notificationSettingsProvider,
            );

            return settingsAsync.when(
              data: (settings) {
                return Column(
                  mainAxisSize:
                  MainAxisSize.min,
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Class Alarms",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight:
                        FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      "Get notified before your classes start.",
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    SwitchListTile(
                      contentPadding:
                      EdgeInsets.zero,
                      title: Text(
                        "Enable Alarms",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                        ),
                      ),
                      activeColor:
                      const Color(0xFF1877F2),
                      value: settings
                          .isRoutineAlarmEnabled,
                      onChanged:
                          (val) async {
                        HapticFeedback
                            .selectionClick();

                        await ref
                            .read(
                          notificationSettingsProvider
                              .notifier,
                        )
                            .updateSettings(
                          val,
                          settings
                              .alarmLeadTimeMinutes,
                        );

                        if (val) {
                          try {
                            final routines =
                            await _fetchAllRoutinesSafely(
                              user,
                            );

                            await ref
                                .read(
                              localNotificationServiceProvider,
                            )
                                .scheduleClassRoutines(
                              routines,
                              settings
                                  .alarmLeadTimeMinutes,
                            );

                            if (ctx.mounted) {
                              ScaffoldMessenger
                                  .of(ctx)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Alarms scheduled!",
                                  ),
                                  backgroundColor:
                                  Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            debugPrint(
                              "Failed to schedule alarms: $e",
                            );

                            if (ctx.mounted) {
                              ScaffoldMessenger
                                  .of(ctx)
                                  .showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Failed to schedule alarms",
                                  ),
                                  backgroundColor:
                                  Colors.redAccent,
                                ),
                              );
                            }
                          }
                        } else {
                          await ref
                              .read(
                            localNotificationServiceProvider,
                          )
                              .cancelAllClassRoutines();
                        }
                      },
                    ),
                    if (settings
                        .isRoutineAlarmEnabled) ...[
                      SizedBox(height: 16.h),
                      Text(
                        "Remind me before class:",
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 14.sp,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        mainAxisAlignment:
                        MainAxisAlignment
                            .spaceEvenly,
                        children:
                        [5, 10, 15, 30]
                            .map(
                              (mins) {
                            final isSelected =
                                settings
                                    .alarmLeadTimeMinutes ==
                                    mins;

                            return ChoiceChip(
                              label: Text(
                                "${mins}m",
                                style:
                                TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.white70,
                                ),
                              ),
                              selected:
                              isSelected,
                              selectedColor:
                              const Color(
                                0xFF1877F2,
                              ),
                              backgroundColor:
                              Colors.black26,
                              onSelected:
                                  (selected) async {
                                if (selected) {
                                  HapticFeedback
                                      .selectionClick();

                                  await ref
                                      .read(
                                    notificationSettingsProvider
                                        .notifier,
                                  )
                                      .updateSettings(
                                    true,
                                    mins,
                                  );

                                  try {
                                    final routines =
                                    await _fetchAllRoutinesSafely(
                                      user,
                                    );

                                    await ref
                                        .read(
                                      localNotificationServiceProvider,
                                    )
                                        .scheduleClassRoutines(
                                      routines,
                                      mins,
                                    );
                                  } catch (e) {
                                    debugPrint(
                                      "Failed to update alarms: $e",
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ).toList(),
                      ),
                    ],
                    SizedBox(height: 20.h),
                  ],
                );
              },
              loading: () =>
              const Center(
                child:
                CircularProgressIndicator(),
              ),
              error: (_, __) =>
              const Text(
                "Failed to load settings",
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = firebase_auth
        .FirebaseAuth
        .instance
        .currentUser
        ?.uid;

    if (uid == null) {
      return Center(
        child: Text(
          "Please login",
          style: TextStyle(
            color: Colors.white,
            fontSize: 16.sp,
          ),
        ),
      );
    }

    return SafeArea(
      child: StreamBuilder(
        stream: ref
            .watch(userRepositoryProvider)
            .watchUser(uid),
        builder: (
            context,
            userSnapshot,
            ) {
          if (userSnapshot
              .connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
              CircularProgressIndicator(
                color:
                Color(0xFF1877F2),
              ),
            );
          }

          final user =
              userSnapshot.data;

          if (user == null) {
            return const SizedBox();
          }

          return Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              _buildHeader(
                user.role,
                user.semester,
                user,
              ),
              SizedBox(height: 22.h),
              _buildDateSelector(),
              Padding(
                padding:
                EdgeInsets.fromLTRB(
                  20.w,
                  10.h,
                  20.w,
                  0,
                ),
                child: Container(
                  height: 1.h,
                  color: Colors.white
                      .withValues(
                    alpha: 0.24,
                  ),
                ),
              ),
              SizedBox(height: 24.h),
              _buildTimelineHeader(),
              SizedBox(height: 10.h),
              Expanded(
                child: StreamBuilder(
                  stream: user.role == 'teacher'
                      ? ref
                      .watch(
                    routineRepositoryProvider,
                  )
                      .watchTeacherDailyRoutines(
                    user.internalId,
                    user.name,
                    selectedDate.weekday,
                  )
                      : ref
                      .watch(
                    routineRepositoryProvider,
                  )
                      .watchDailyRoutines(
                    user.semester,
                    user.section,
                    selectedDate.weekday,
                  ),
                  builder: (
                      context,
                      routineSnapshot,
                      ) {
                    if (routineSnapshot
                        .connectionState ==
                        ConnectionState
                            .waiting) {
                      return const Center(
                        child:
                        CircularProgressIndicator(
                          color:
                          Color(0xFF1877F2),
                        ),
                      );
                    }

                    final routines =
                        routineSnapshot
                            .data ??
                            [];

                    if (routines.isEmpty) {
                      return _buildFreedomBanner();
                    }

                    final timeline =
                    _generateTimeline(
                      routines,
                    );

                    return ListView.builder(
                      padding:
                      EdgeInsets.fromLTRB(
                        20.w,
                        8.h,
                        20.w,
                        20.h,
                      ),
                      physics:
                      const BouncingScrollPhysics(),
                      itemCount:
                      timeline.length,
                      itemBuilder:
                          (context, index) {
                        final item =
                        timeline[index];

                        if (item["type"] ==
                            "class") {
                          return _buildRoutineSlot(
                            item["data"],
                            item["color"],
                            user.role,
                          );
                        }

                        return _buildBreakSlot(
                          item["startTime"],
                          item["endTime"],
                          item["durationText"],
                        );
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

  Widget _buildHeader(
      String role,
      int semester,
      dynamic user,
      ) {
    final syncState =
    ref.watch(syncControllerProvider);

    final settingsAsync = ref.watch(
      notificationSettingsProvider,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        0,
      ),
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.center,
        children: [
          Text(
            DateFormat('dd')
                .format(selectedDate),
            style: TextStyle(
              color: Colors.white,
              fontSize: 46.sp,
              fontWeight:
              FontWeight.w300,
              height: 0.95,
              letterSpacing: -1.2,
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment:
            CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('EEE')
                    .format(selectedDate),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 17.sp,
                  fontWeight:
                  FontWeight.w400,
                  height: 1.0,
                ),
              ),
              SizedBox(height: 7.h),
              Text(
                DateFormat(
                  'MMMM, yyyy',
                ).format(selectedDate),
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15.sp,
                  fontWeight:
                  FontWeight.w400,
                  height: 1.0,
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              role == 'teacher'
                  ? "Teacher Schedule"
                  : "${semester}th Semester",
              maxLines: 1,
              overflow:
              TextOverflow.ellipsis,
              textAlign:
              TextAlign.right,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16.sp,
                fontWeight:
                FontWeight.w400,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          IconButton(
            icon: Icon(
              settingsAsync.value
                  ?.isRoutineAlarmEnabled ==
                  true
                  ? Icons
                  .notifications_active
                  : Icons
                  .notifications_off_outlined,
              color: settingsAsync.value
                  ?.isRoutineAlarmEnabled ==
                  true
                  ? Colors.amber
                  : Colors.white70,
              size: 25.sp,
            ),
            padding: EdgeInsets.zero,
            constraints:
            const BoxConstraints(),
            tooltip: "Class Alarms",
            onPressed: () =>
                _showNotificationSettingsSheet(
                  context,
                  user,
                ),
          ),
          SizedBox(width: 6.w),
          syncState.isLoading
              ? SizedBox(
            width: 22.w,
            height: 22.w,
            child:
            const CircularProgressIndicator(
              color:
              Color(0xFF1877F2),
              strokeWidth: 2.2,
            ),
          )
              : IconButton(
            icon: Icon(
              Icons.sync_rounded,
              color:
              const Color(
                0xFF1877F2,
              ),
              size: 27.sp,
            ),
            padding:
            EdgeInsets.zero,
            constraints:
            const BoxConstraints(),
            tooltip:
            "Sync Routine",
            onPressed: () async {
              HapticFeedback
                  .lightImpact();

              try {
                await ref
                    .read(
                  syncControllerProvider
                      .notifier,
                )
                    .syncAllData();

                if (context.mounted) {
                  ScaffoldMessenger
                      .of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Routine synced successfully!",
                      ),
                      backgroundColor:
                      Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger
                      .of(context)
                      .showSnackBar(
                    SnackBar(
                      content: Text(
                        e
                            .toString()
                            .replaceAll(
                          "Exception: ",
                          "",
                        ),
                      ),
                      backgroundColor:
                      Colors.redAccent,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDateSelector() {
    return Padding(
      padding:
      EdgeInsets.symmetric(
        horizontal: 14.w,
      ),
      child: Row(
        mainAxisAlignment:
        MainAxisAlignment.spaceBetween,
        children: currentWeek.map(
              (date) {
            final isSelected =
                date.day ==
                    selectedDate.day &&
                    date.month ==
                        selectedDate.month &&
                    date.year ==
                        selectedDate.year;

            return GestureDetector(
              onTap: () => setState(
                    () => selectedDate = date,
              ),
              child: AnimatedContainer(
                duration: const Duration(
                  milliseconds: 250,
                ),
                curve: Curves.easeOutCubic,
                width: 44.w,
                height: 72.h,
                decoration:
                BoxDecoration(
                  color: isSelected
                      ? const Color(
                    0xFF1877F2,
                  )
                      : Colors.transparent,
                  borderRadius:
                  BorderRadius.circular(
                    20.r,
                  ),
                  boxShadow: isSelected
                      ? [
                    BoxShadow(
                      color:
                      const Color(
                        0xFF1877F2,
                      ).withValues(
                        alpha: 0.18,
                      ),
                      blurRadius: 18,
                      spreadRadius: -4,
                    ),
                  ]
                      : const [],
                ),
                padding:
                EdgeInsets.symmetric(
                  vertical: 10.h,
                ),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,
                  children: [
                    Text(
                      DateFormat('E')
                          .format(date)
                          .substring(
                        0,
                        1,
                      ),
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : Colors.white70,
                        fontSize: 15.sp,
                        fontWeight:
                        FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      DateFormat('dd')
                          .format(date),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17.sp,
                        fontWeight:
                        isSelected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        height: 1.0,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  Widget _buildTimelineHeader() {
    return Padding(
      padding:
      EdgeInsets.symmetric(
        horizontal: 20.w,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60.w,
            child: Text(
              "Time",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16.sp,
                fontWeight:
                FontWeight.w400,
              ),
            ),
          ),
          SizedBox(width: 20.w),
          Text(
            "Courses",
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16.sp,
              fontWeight:
              FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineSlot(
      dynamic routine,
      Color cardColor,
      String userRole,
      ) {
    final ongoing =
    _isClassOngoing(
      routine.startTime,
      routine.endTime,
      selectedDate,
    );

    final cardBorderRadius =
    BorderRadius.circular(20.r);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 60.w,
            child: Padding(
              padding: EdgeInsets.only(
                top: 18.h,
                bottom: 20.h,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    routine.startTime,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17.sp,
                      fontWeight:
                      FontWeight.w600,
                      height: 1.0,
                    ),
                  ),
                  SizedBox(height: 7.h),
                  Text(
                    routine.endTime,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14.sp,
                      fontWeight:
                      FontWeight.w400,
                      height: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1.5.w,
            color: Colors.white30,
            margin: EdgeInsets.symmetric(
              horizontal: 16.w,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: 20.h,
              ),
              child: Container(
                constraints:
                BoxConstraints(
                  minHeight: 128.h,
                ),
                padding:
                EdgeInsets.fromLTRB(
                  18.w,
                  18.h,
                  18.w,
                  16.h,
                ),
                decoration: BoxDecoration(
                  borderRadius:
                  cardBorderRadius,
                  gradient:
                  LinearGradient(
                    begin:
                    Alignment.topLeft,
                    end:
                    Alignment.bottomRight,
                    colors: [
                      Color.lerp(
                        const Color(
                          0xFF0C111D,
                        ),
                        cardColor,
                        0.38,
                      ) ??
                          const Color(
                            0xFF0C111D,
                          ),
                      const Color(
                        0xFF11131A,
                      ),
                      cardColor.withValues(
                        alpha: 0.70,
                      ),
                    ],
                    stops: const [
                      0.0,
                      0.46,
                      1.0,
                    ],
                  ),
                  border: Border.all(
                    color: ongoing
                        ? Colors.white
                        : cardColor.withValues(
                      alpha: 0.28,
                    ),
                    width: ongoing
                        ? 1.6.w
                        : 1.w,
                  ),
                  boxShadow: ongoing
                      ? [
                    BoxShadow(
                      color: cardColor
                          .withValues(
                        alpha: 0.28,
                      ),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                  ]
                      : [
                    BoxShadow(
                      color:
                      Colors.black
                          .withValues(
                        alpha: 0.20,
                      ),
                      blurRadius: 10,
                      offset:
                      const Offset(
                        0,
                        5,
                      ),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
                  children: [
                    Text(
                      routine.subjectName,
                      maxLines: 1,
                      overflow:
                      TextOverflow
                          .ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight:
                        FontWeight.w500,
                        height: 1.05,
                        letterSpacing:
                        -0.15,
                      ),
                    ),
                    SizedBox(height: 21.h),
                    _buildRoutineMetaRow(
                      icon: Icons
                          .location_on_outlined,
                      iconColor: Colors.white,
                      accentColor:
                      cardColor,
                      text:
                      "Room ${routine.roomNumber}",
                    ),
                    SizedBox(height: 8.h),
                    _buildRoutineMetaRow(
                      icon: userRole ==
                          'teacher'
                          ? Icons
                          .groups_outlined
                          : Icons
                          .person_outline,
                      iconColor: Colors.white,
                      accentColor:
                      cardColor,
                      text: userRole ==
                          'teacher'
                          ? "Sem ${routine.semester} - Sec ${routine.section}"
                          : routine.teacherName,
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

  Widget _buildRoutineMetaRow({
    required IconData icon,
    required Color iconColor,
    required Color accentColor,
    required String text,
  }) {
    return Row(
      children: [
        Container(
          width: 30.r,
          height: 30.r,
          decoration: BoxDecoration(
            color: accentColor
                .withValues(
              alpha: 0.18,
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: 17.r,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow:
            TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14.sp,
              fontWeight:
              FontWeight.w400,
              height: 1.0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakSlot(
      String startTime,
      String endTime,
      String durationText,
      ) {
    final goofyMessages = [
      "Time to chill",
      "Grab a snack",
      "Power nap time",
      "Coffee break",
      "Touch some grass",
      "Brain cooling down",
      "Scroll some memes",
    ];

    final randomMsg =
    goofyMessages[
    (startTime.hashCode +
        endTime.hashCode)
        .abs() %
        goofyMessages.length
    ];

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment:
        CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 60.w,
            child: Padding(
              padding: EdgeInsets.only(
                top: 18.h,
                bottom: 20.h,
              ),
              child: Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  Text(
                    startTime,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14.sp,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    endTime,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1.5.w,
            color: Colors.white30,
            margin: EdgeInsets.symmetric(
              horizontal: 16.w,
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                bottom: 20.h,
              ),
              child: Container(
                constraints:
                BoxConstraints(
                  minHeight: 94.h,
                ),
                padding:
                EdgeInsets.symmetric(
                  vertical: 18.h,
                  horizontal: 16.w,
                ),
                decoration: BoxDecoration(
                  gradient:
                  LinearGradient(
                    begin:
                    Alignment.topLeft,
                    end:
                    Alignment.bottomRight,
                    colors: [
                      const Color(
                        0xFF0F192B,
                      ).withValues(
                        alpha: 0.90,
                      ),
                      const Color(
                        0xFF0C1018,
                      ),
                    ],
                  ),
                  borderRadius:
                  BorderRadius.circular(
                    18.r,
                  ),
                  border: Border.all(
                    color:
                    const Color(
                      0xFF1877F2,
                    ).withValues(
                      alpha: 0.25,
                    ),
                    width: 1.w,
                  ),
                ),
                child: Column(
                  mainAxisAlignment:
                  MainAxisAlignment
                      .center,
                  children: [
                    Row(
                      mainAxisAlignment:
                      MainAxisAlignment
                          .center,
                      children: [
                        Icon(
                          Icons
                              .coffee_outlined,
                          color:
                          Colors.amber,
                          size: 22.sp,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          "Break ($durationText)",
                          style: TextStyle(
                            color:
                            Colors.amber,
                            fontSize: 17.sp,
                            fontWeight:
                            FontWeight
                                .w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      randomMsg,
                      textAlign:
                      TextAlign.center,
                      style: TextStyle(
                        color:
                        Colors.white60,
                        fontSize: 13.sp,
                        fontStyle:
                        FontStyle.italic,
                      ),
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
        mainAxisAlignment:
        MainAxisAlignment.center,
        children: [
          Container(
            width: 92.r,
            height: 92.r,
            decoration: BoxDecoration(
              color: const Color(
                0xFF1877F2,
              ).withValues(
                alpha: 0.08,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons
                  .celebration_outlined,
              color: const Color(
                0xFF1877F2,
              ).withValues(
                alpha: 0.85,
              ),
              size: 54.sp,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            "Freedom!",
            style: TextStyle(
              color: Colors.white,
              fontSize: 30.sp,
              fontWeight:
              FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "No classes scheduled for this day.",
            style: TextStyle(
              color: Colors.white54,
              fontSize: 16.sp,
            ),
          ),
        ],
      ),
    );
  }
}