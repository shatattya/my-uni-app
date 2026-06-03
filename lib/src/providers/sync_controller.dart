import 'dart:io';
import 'dart:async'; // ADDED: Required for TimeoutException
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import '../data/repositories/user_repository.dart';
import '../data/repositories/announcement_repository.dart';
import '../data/repositories/routine_repository.dart';
import '../data/repositories/exam_routine_repository.dart';
import '../data/repositories/book_repository.dart'; // ADDED: For Books sync
import '../data/repositories/note_repository.dart'; // ADDED: For Notes sync

final syncControllerProvider = AsyncNotifierProvider<SyncController, DateTime?>(() {
  return SyncController();
});

class SyncController extends AsyncNotifier<DateTime?> {

  // Helper to get the persistent file path
  Future<File> _getSyncTimestampFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/last_sync_time.txt');
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
      print("DEBUG: Failed to load persistent sync timestamp: $e");
    }
    return null;
  }

  Future<void> syncAllData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception("User not logged in.");

    final userRepo = ref.read(userRepositoryProvider);
    final localUser = await userRepo.getUserLocally(uid);

    // Identify if the user has privileges to bypass the sync lock
    final bool canBypassSyncLock = localUser != null && (localUser.role == 'teacher' || localUser.isDev == true);

    // 1. Enforce Cooldown Check ONLY for normal students
    final lastSync = state.value;
    if (!canBypassSyncLock && lastSync != null) {
      final difference = DateTime.now().difference(lastSync);
      if (difference.inMinutes < 5) {
        throw Exception("Sync is on cooldown to save data. Please try again in ${5 - difference.inMinutes} minutes.");
      }
    }

    // Set state to loading immediately
    state = const AsyncLoading();

    try {
      // 2. Network Check BEFORE starting Firestore sync
      final hasInternet = await _checkInternet();
      if (!hasInternet) {
        throw Exception("Slow or no internet connection. Please check your network and try again.");
      }

      // 3. Execute Full App Sync Concurrently
      await Future.wait([
        userRepo.syncUser(uid),
        ref.read(announcementRepositoryProvider).syncAnnouncements(),
        ref.read(routineRepositoryProvider).syncRoutines(),
        ref.read(examRoutineRepositoryProvider).syncExamRoutines(),
        ref.read(bookRepositoryProvider).syncBooks(), // MODIFICATION: Added Book Sync
        if (localUser != null) ref.read(noteRepositoryProvider).syncNotes(localUser.semester, localUser.section), // MODIFICATION: Added Note Sync with safe user properties
      ]);

      // 4. Update the state and persist the timestamp to the file
      final now = DateTime.now();
      state = AsyncData(now);

      try {
        final file = await _getSyncTimestampFile();
        await file.writeAsString(now.toIso8601String());
      } catch (e) {
        print("DEBUG: Failed to save persistent sync timestamp: $e");
      }

    } catch (e) {
      // Revert state back to the previous timestamp so they aren't locked out due to a failure
      state = AsyncData(lastSync);
      rethrow;
    }
  }

  // Helper method to ping Google to guarantee an active connection exists
  Future<bool> _checkInternet() async {
    try {
      // UX ENHANCEMENT: Added a 5-second timeout.
      // Prevents infinite loading spinners if DNS resolution hangs on spotty networks.
      final result = await InternetAddress.lookup('firestore.googleapis.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      // Catches both SocketException (no network) and TimeoutException (slow network)
      return false;
    }
  }
}