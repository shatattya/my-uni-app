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

    // Initialize timezone data required for scheduled notifications
    tz.initializeTimeZones();

    // Setup Android settings using the default mipmap icon
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // We only pass Android settings since iOS isn't explicitly configured in your current pubspec,
    // but the structure easily supports it if you add iOS later.
    const InitializationSettings settings = InitializationSettings(android: androidSettings);

    await _notificationsPlugin.initialize(settings);
    _isInitialized = true;
  }

  /// Wipe old notifications and schedule new ones for a given list of exams
  Future<void> scheduleExamNotifications(List<ExamRoutine> exams) async {
    if (!_isInitialized) await init();

    // Cancel all previously scheduled exam notifications to prevent duplicates or obsolete alarms
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
        // Robustly parse the 24h format "HH:MM" start time to prevent silent crashes
        final timeParts = exam.startTime.split(':');
        if (timeParts.length < 2) {
          throw const FormatException("Missing colon separator");
        }

        final hour = int.tryParse(timeParts[0].trim());
        // Cleanse the minute string of any accidental letters (like AM/PM) or whitespace
        final minute = int.tryParse(timeParts[1].replaceAll(RegExp(r'[^0-9]'), '').trim());

        if (hour == null || minute == null) {
          throw const FormatException("Non-numeric time values");
        }

        // Combine the exam date with the precise start time
        final examDateTime = DateTime(
          exam.date.year,
          exam.date.month,
          exam.date.day,
          hour,
          minute,
        );

        // Calculate trigger times
        final time24hBefore = examDateTime.subtract(const Duration(hours: 24));
        final time2hBefore = examDateTime.subtract(const Duration(hours: 2));

        // Generate deterministic IDs using the exam ID hash to safely update/overwrite specific exams
        final baseId = exam.id.hashCode.abs();
        final id24h = (baseId * 2) % 1000000;
        final id2h = (baseId * 2 + 1) % 1000000;

        // Schedule 24 Hours Before (if it hasn't passed yet)
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

        // Schedule 2 Hours Before (if it hasn't passed yet)
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
        // Collect errors instead of failing the entire loop so valid exams still get scheduled
        schedulingErrors.add("Failed '${exam.subjectName}': ${e.toString()}");
      }
    }

    // Rethrow any accumulated errors so the caller UI can gracefully inform the user
    if (schedulingErrors.isNotEmpty) {
      throw Exception("Some exams could not be scheduled:\n${schedulingErrors.join('\n')}");
    }
  }
}