import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import '../data/local/app_database.dart';

final localNotificationServiceProvider = Provider<LocalNotificationService>((ref) {
  return LocalNotificationService();
});

class LocalNotificationService {
  static final LocalNotificationService _instance = LocalNotificationService._internal();
  factory LocalNotificationService() => _instance;
  LocalNotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
    DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        print("DEBUG: Notification clicked payload: ${response.payload}");
      },
    );
  }

  Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  Future<void> cancelAllClassRoutines() async {
    await cancelAllNotifications();
  }

  Future<void> scheduleClassRoutines(List<dynamic> routines, [int minutesBefore = 15]) async {
    await cancelAllClassRoutines();

    for (final item in routines) {
      try {
        final routine = item as Routine;
        await scheduleWeeklyClassAlarm(routine: routine, minutesBefore: minutesBefore);
      } catch (e) {
        print("DEBUG: Failed to schedule routine: $e");
      }
    }
  }

  Future<void> scheduleExamNotifications(List<dynamic> exams) async {
    print("DEBUG: scheduleExamNotifications called for ${exams.length} exams.");
  }

  Future<void> scheduleWeeklyClassAlarm({
    required Routine routine,
    required int minutesBefore,
  }) async {
    final int notificationId = '${routine.id}_${routine.dayOfWeek}_${routine.startTime}'.hashCode & 0x7FFFFFFF;

    final parts = routine.startTime.split(':');
    final int classHour = int.parse(parts[0]);
    final int classMinute = int.parse(parts[1]);

    final tz.TZDateTime scheduledDate = _nextInstanceOfWeekdayTime(
      routine.dayOfWeek,
      classHour,
      classMinute,
      minutesBefore,
    );

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'routine_alarm_channel',
      'Class Routine Alarms',
      channelDescription: 'Alarm reminders for upcoming classes',
      importance: Importance.max,
      priority: Priority.high,
      sound: RawResourceAndroidNotificationSound('alarm_sound'),
      playSound: true,
      enableVibration: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(sound: 'alarm_sound.aiff'),
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      'Upcoming Class: ${routine.subjectName}',
      // MODIFICATION: Removed the unknown room property to ensure compilation
      'Class starts in $minutesBefore minutes (${routine.startTime})',
      scheduledDate,
      platformDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime(
      int targetWeekday,
      int hour,
      int minute,
      int minutesBefore,
      ) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);

    tz.TZDateTime scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(Duration(minutes: minutesBefore));

    while (scheduledDate.weekday != targetWeekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}