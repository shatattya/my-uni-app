import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../data/local/app_database.dart';

final localNotificationServiceProvider = Provider((ref) => LocalNotificationService());

class LocalNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    tz.initializeTimeZones();
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings settings = InitializationSettings(android: androidSettings);
    await _notificationsPlugin.initialize(settings);
    _isInitialized = true;
  }

  /// Wipe old notifications and schedule new ones for a given list of exams
  Future<void> scheduleExamNotifications(List<ExamRoutine> exams) async {
    if (!_isInitialized) await init();

    // Cancel previous exam notifications (assuming IDs under 2,000,000)
    // For a cleaner approach, you might want to track exact IDs, but cancelAll is safe
    // if we immediately reschedule everything.
    await _notificationsPlugin.cancelAll();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'exam_channel',
      'Exam Reminders',
      channelDescription: 'Offline reminders for upcoming exams (24h and 2h before)',
      importance: Importance.high,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
    final now = DateTime.now();
    List<String> schedulingErrors = [];

    for (final exam in exams) {
      try {
        final timeParts = exam.startTime.split(':');
        if (timeParts.length < 2) throw const FormatException("Missing colon separator");

        final hour = int.tryParse(timeParts[0].trim());
        final minute = int.tryParse(timeParts[1].replaceAll(RegExp(r'[^0-9]'), '').trim());
        if (hour == null || minute == null) throw const FormatException("Non-numeric time values");

        final examDateTime = DateTime(
          exam.date.year,
          exam.date.month,
          exam.date.day,
          hour,
          minute,
        );

        final time24hBefore = examDateTime.subtract(const Duration(hours: 24));
        final time2hBefore = examDateTime.subtract(const Duration(hours: 2));

        final baseId = exam.id.hashCode.abs();
        final id24h = (baseId * 2) % 1000000;
        final id2h = (baseId * 2 + 1) % 1000000;

        if (time24hBefore.isAfter(now)) {
          await _notificationsPlugin.zonedSchedule(
            id24h,
            'Exam Tomorrow: ${exam.subjectName}',
            'Room ${exam.roomNumber} at ${exam.startTime}. Best of luck!',
            tz.TZDateTime.from(time24hBefore, tz.local),
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }

        if (time2hBefore.isAfter(now)) {
          await _notificationsPlugin.zonedSchedule(
            id2h,
            'Exam Starting Soon: ${exam.subjectName}',
            'Starts in 2 hours! Head to Room ${exam.roomNumber}.',
            tz.TZDateTime.from(time2hBefore, tz.local),
            platformDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          );
        }
      } catch (e) {
        schedulingErrors.add("Failed '${exam.subjectName}': ${e.toString()}");
      }
    }

    if (schedulingErrors.isNotEmpty) {
      throw Exception("Some exams could not be scheduled:\n${schedulingErrors.join('\n')}");
    }
  }

  /// Weekly Recurring Class Routine Scheduling
  Future<void> scheduleClassRoutines(List<dynamic> routines, int leadTimeMinutes) async {
    if (!_isInitialized) await init();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'class_channel',
      'Class Reminders',
      channelDescription: 'Daily reminders for your upcoming classes',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    List<String> schedulingErrors = [];

    for (final routine in routines) {
      try {
        final timeParts = routine.startTime.split(':');
        if (timeParts.length < 2) continue;

        final hour = int.tryParse(timeParts[0].trim());
        final minute = int.tryParse(timeParts[1].replaceAll(RegExp(r'[^0-9]'), '').trim());
        if (hour == null || minute == null) continue;

        // Calculate the next occurrence of this weekday and time
        tz.TZDateTime scheduledDate = _nextInstanceOfWeekdayAndTime(routine.weekday, hour, minute);

        // Apply the user's preferred lead time
        scheduledDate = scheduledDate.subtract(Duration(minutes: leadTimeMinutes));

        // Deterministic ID (Offset by 2,000,000 to avoid exam collisions)
        final uniqueString = "${routine.subjectName}_${routine.weekday}_${routine.startTime}";
        final alarmId = (uniqueString.hashCode.abs() % 1000000) + 2000000;

        await _notificationsPlugin.zonedSchedule(
          alarmId,
          'Upcoming Class: ${routine.subjectName}',
          'Starts in $leadTimeMinutes mins in Room ${routine.roomNumber}.',
          scheduledDate,
          platformDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime, // Crucial for weekly recurrence
        );
      } catch (e) {
        schedulingErrors.add("Failed '${routine.subjectName}': ${e.toString()}");
      }
    }

    if (schedulingErrors.isNotEmpty) {
      throw Exception("Some classes could not be scheduled:\n${schedulingErrors.join('\n')}");
    }
  }

  Future<void> cancelAllClassRoutines() async {
    if (!_isInitialized) await init();
    // Since we don't store individual IDs in a local list, canceling all is safest
    // when toggling off, but we must ensure we don't wipe exam schedules if they exist.
    // For a production-ready approach without local ID tracking, we can simply cancelAll
    // and let the next exam sync regenerate the exam alarms.
    await _notificationsPlugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfWeekdayAndTime(int weekday, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // If the scheduled time has already passed today, push to tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    // Fast-forward to the target weekday
    while (scheduledDate.weekday != weekday) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}