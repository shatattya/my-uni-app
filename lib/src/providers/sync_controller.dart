import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../data/repositories/academic_calendar_repository.dart';
import '../data/repositories/announcement_repository.dart';
import '../data/repositories/book_repository.dart';
import '../data/repositories/exam_routine_repository.dart';
import '../data/repositories/live_event_repository.dart';
import '../data/repositories/note_repository.dart';
import '../data/repositories/routine_repository.dart';
import '../data/repositories/user_repository.dart';
import '../services/local_notification_service.dart';
import 'academic_calendar_provider.dart';
import 'notification_settings_provider.dart';

final syncControllerProvider =
AsyncNotifierProvider<SyncController, DateTime?>(() {
  return SyncController();
});

class SyncController extends AsyncNotifier<DateTime?> {
  /// Shared in-flight operation.
  ///
  /// This is deliberately separate from [state.isLoading]. There is an async
  /// gap before state becomes loading, so state alone cannot reliably prevent
  /// duplicate sync operations from concurrent UI callers.
  Future<void>? _syncInFlight;

  Future<File> _getSyncTimestampFile() async {
    final directory = await getApplicationDocumentsDirectory();

    return File(
      '${directory.path}/last_sync_time.txt',
    );
  }

  @override
  Future<DateTime?> build() async {
    try {
      final file = await _getSyncTimestampFile();

      if (await file.exists()) {
        final timestampString = await file.readAsString();
        return DateTime.tryParse(timestampString);
      }
    } catch (e) {
      debugPrint(
        'DEBUG: Failed to load persistent sync timestamp: $e',
      );
    }

    return null;
  }

  /// Starts a sync or reuses the currently active one.
  Future<void> syncAllData() {
    final existingOperation = _syncInFlight;

    if (existingOperation != null) {
      debugPrint(
        'DEBUG: Sync already in progress; reusing the active operation.',
      );
      return existingOperation;
    }

    late final Future<void> operation;

    operation = _performSyncAllData().whenComplete(() {
      if (identical(_syncInFlight, operation)) {
        _syncInFlight = null;
      }
    });

    _syncInFlight = operation;
    return operation;
  }

  Future<void> _performSyncAllData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || uid.trim().isEmpty) {
      throw Exception('User not logged in.');
    }

    final userRepo = ref.read(userRepositoryProvider);
    final localUser = await userRepo.getUserLocally(uid);

    final bool canBypassSyncLock =
        localUser != null &&
            (localUser.role == 'teacher' || localUser.isDev);

    final lastSync = state.value;

    if (!canBypassSyncLock && lastSync != null) {
      final difference = DateTime.now().difference(lastSync);

      if (difference.inMinutes < 15) {
        throw Exception(
          'Sync is on cooldown to save data. Please try again in '
              '${15 - difference.inMinutes} minutes.',
        );
      }
    }

    state = const AsyncLoading();

    try {
      final hasInternet = await _checkInternet();

      if (!hasInternet) {
        throw Exception(
          'Slow or no internet connection. Please check your network and try again.',
        );
      }

      await Future.wait([
        userRepo.syncUser(uid),
        ref.read(announcementRepositoryProvider).syncAnnouncements(),
        ref.read(routineRepositoryProvider).syncRoutines(),
        ref.read(examRoutineRepositoryProvider).syncExamRoutines(),
        ref.read(bookRepositoryProvider).syncBooks(),
        ref.read(academicCalendarRepositoryProvider).syncCalendar(),
        if (localUser != null)
          ref
              .read(noteRepositoryProvider)
              .syncNotes(localUser.semester, localUser.section),
        ref.read(liveEventRepositoryProvider).syncLiveEvents(),
      ]);

      // The repository has already updated SharedPreferences. Invalidating the
      // provider makes an open calendar screen pick up that cache immediately;
      // this invalidation itself performs no Firestore read.
      ref.invalidate(academicCalendarProvider);

      final now = DateTime.now();
      state = AsyncData(now);

      await _rescheduleRoutineAlarmsIfNeeded(
        uid: uid,
        fallbackUser: localUser,
      );

      try {
        final file = await _getSyncTimestampFile();
        await file.writeAsString(now.toIso8601String());
      } catch (e) {
        debugPrint(
          'DEBUG: Failed to save persistent sync timestamp: $e',
        );
      }
    } catch (e) {
      // Failed syncs do not advance the cooldown timestamp.
      state = AsyncData(lastSync);
      rethrow;
    }
  }

  Future<void> _rescheduleRoutineAlarmsIfNeeded({
    required String uid,
    required dynamic fallbackUser,
  }) async {
    try {
      final settings = ref.read(notificationSettingsProvider).value;

      if (settings == null || !settings.isRoutineAlarmEnabled) {
        return;
      }

      final syncedUser =
          await ref.read(userRepositoryProvider).getUserLocally(uid) ??
              fallbackUser;

      if (syncedUser == null) {
        return;
      }

      final routineRepository = ref.read(routineRepositoryProvider);

      final routines = syncedUser.role == 'teacher'
          ? await routineRepository.getTeacherRoutines(
        syncedUser.internalId,
        syncedUser.name,
      )
          : await routineRepository.getStudentRoutines(
        syncedUser.semester,
        syncedUser.section,
      );

      await ref
          .read(localNotificationServiceProvider)
          .scheduleClassRoutines(
        routines,
        settings.alarmLeadTimeMinutes,
      );
    } catch (e) {
      // Notification rescheduling is secondary to the successful data sync.
      debugPrint(
        'DEBUG: Failed to reschedule alarms after sync: $e',
      );
    }
  }

  Future<bool> _checkInternet() async {
    try {
      final result = await InternetAddress.lookup(
        'firestore.googleapis.com',
      ).timeout(const Duration(seconds: 5));

      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}