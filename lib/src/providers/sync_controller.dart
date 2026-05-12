import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart'; // FIXED: Correct import path
import '../data/repositories/user_repository.dart';
import '../data/repositories/announcement_repository.dart';

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

    // Identify if the user has privileges to bypass the sync cooldown
    final isPrivileged = localUser != null && (localUser.role == 'teacher' || localUser.isDev);

    // 1. Enforce 15-Minute Cooldown ONLY for non-privileged users
    final lastSync = state.value;
    if (!isPrivileged && lastSync != null) {
      final diff = DateTime.now().difference(lastSync);
      if (diff.inMinutes < 15) {
        final remaining = 15 - diff.inMinutes;
        throw Exception("Sync on cooldown. Please wait $remaining minute(s).");
      }
    }

    state = const AsyncLoading();

    try {
      // 2. Pre-flight Internet Check (Catches offline state before suppressing errors)
      bool hasInternet = await _checkInternet();
      if (!hasInternet) {
        throw Exception("No internet connection. Cannot sync data.");
      }

      // 3. Execute Full App Sync Concurrently
      await Future.wait([
        userRepo.syncUser(uid),
        ref.read(announcementRepositoryProvider).syncAnnouncements(),
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
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    }
  }
}