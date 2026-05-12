import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import '../local/app_database.dart';
import '../../providers/db_provider.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(dbProvider), FirebaseFirestore.instance);
});

class UserRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  UserRepository(this._db, this._firestore);

  /// OFFLINE-FIRST: Watch the local database.
  Stream<User?> watchUser(String uid) {
    return (_db.select(_db.users)..where((u) => u.id.equals(uid))).watchSingleOrNull();
  }

  /// HELPER: Fast local fetch for SyncController role checking
  Future<User?> getUserLocally(String uid) async {
    return await (_db.select(_db.users)..where((u) => u.id.equals(uid))).getSingleOrNull();
  }

  /// HELPER: Handle FCM Topic Subscriptions
  Future<void> _updateFCMSubscriptions(int newSem, String newSec, {int? oldSem, String? oldSec}) async {
    try {
      await _fcm.subscribeToTopic("global");
      if (oldSem != null && oldSec != null) {
        String oldTopic = "sem_${oldSem}_sec_${oldSec.toUpperCase()}";
        await _fcm.unsubscribeFromTopic(oldTopic);
      }
      String newTopic = "sem_${newSem}_sec_${newSec.toUpperCase()}";
      await _fcm.subscribeToTopic(newTopic);
    } catch (e) {
      print("DEBUG: FCM Subscription Error: $e");
    }
  }

  /// SYNC: Accurately sync identity (role) and privileges (isDev, isCR)
  Future<void> syncUser(String uid) async {
    try {
      // Query 'students' collection first
      var snapshot = await _firestore.collection("students").where("uid", isEqualTo: uid).limit(1).get();
      Map<String, dynamic>? data;

      if (snapshot.docs.isNotEmpty) {
        data = snapshot.docs.first.data();
      } else {
        // Fallback to checking the 'teachers' collection
        snapshot = await _firestore.collection("teachers").where("uid", isEqualTo: uid).limit(1).get();
        if (snapshot.docs.isNotEmpty) {
          data = snapshot.docs.first.data();
        }
      }

      if (data != null) {
        final localUser = await (_db.select(_db.users)..where((u) => u.id.equals(uid))).getSingleOrNull();

        final String role = data["role"] ?? "student";
        final bool firestoreIsDev = data["isDev"] == true;
        final bool firestoreIsCR = data["isCR"] == true;

        final newSem = data["semester"] ?? 1;
        final newSec = data["section"] ?? "A";

        await _updateFCMSubscriptions(
            newSem,
            newSec,
            oldSem: localUser?.semester,
            oldSec: localUser?.section
        );

        final lastUpdate = (data["lastProfileUpdate"] as Timestamp?)?.toDate();

        await _db.into(_db.users).insertOnConflictUpdate(
          UsersCompanion(
            id: Value(uid),
            name: Value(data["name"] ?? "Unknown"),
            internalId: Value(data["internalId"] ?? ""),
            semester: Value(newSem),
            section: Value(newSec),
            role: Value(role),
            isDev: Value(firestoreIsDev),
            isCR: Value(firestoreIsCR),
            avatarId: Value(data["avatarId"] ?? 1),
            lastProfileUpdate: Value(lastUpdate),
          ),
        );
      } else {
        print("DEBUG: Sync failed. User document does not exist.");
        await firebase_auth.FirebaseAuth.instance.signOut();
        throw Exception("Profile data missing or corrupted. You have been safely logged out.");
      }
    } catch (e) {
      print("DEBUG: User Sync error: $e");
    }
  }

  /// UPDATE: Modifies profile
  Future<void> updateProfile({
    required String uid,
    required String name,
    required int semester,
    required String section,
    required int avatarId,
  }) async {
    final localUser = await (_db.select(_db.users)..where((u) => u.id.equals(uid))).getSingleOrNull();
    if (localUser == null) throw Exception("User data not found locally. Please sync first.");

    final normalizedSection = section.toUpperCase().trim();

    // MODIFICATION: Enforce 15-day cooldown ONLY if they are a regular student
    if (localUser.role != 'teacher' && !localUser.isDev) {
      const cooldownDays = 15;
      if (localUser.lastProfileUpdate != null) {
        final difference = DateTime.now().difference(localUser.lastProfileUpdate!);
        if (difference.inDays < cooldownDays) {
          final remaining = Duration(days: cooldownDays) - difference;
          throw Exception("Cooldown: ${remaining.inDays}d ${remaining.inHours % 24}h remaining.");
        }
      }
    }

    await _updateFCMSubscriptions(semester, normalizedSection, oldSem: localUser.semester, oldSec: localUser.section);

    await _firestore.collection("students").doc(localUser.internalId).update({
      "name": name,
      "semester": semester,
      "section": normalizedSection,
      "avatarId": avatarId,
      "lastProfileUpdate": FieldValue.serverTimestamp(),
    });

    await _db.into(_db.users).insertOnConflictUpdate(
      UsersCompanion(
        id: Value(uid),
        name: Value(name),
        semester: Value(semester),
        section: Value(normalizedSection),
        internalId: Value(localUser.internalId),
        role: Value(localUser.role),
        isDev: Value(localUser.isDev),
        isCR: Value(localUser.isCR),
        avatarId: Value(avatarId),
        lastProfileUpdate: Value(DateTime.now()),
      ),
    );
  }

  /// UPDATE AVATAR: Lightweight update for teachers
  Future<void> updateTeacherAvatar(String uid, int avatarId) async {
    try {
      final localUser = await (_db.select(_db.users)..where((u) => u.id.equals(uid))).getSingleOrNull();
      if (localUser != null) {
        await _firestore.collection("teachers").doc(localUser.internalId).update({"avatarId": avatarId});

        await (_db.update(_db.users)..where((u) => u.id.equals(uid))).write(
          UsersCompanion(avatarId: Value(avatarId)),
        );
      }
    } catch (e) {
      print("DEBUG: Failed to update teacher avatar: $e");
      throw Exception("Failed to update avatar.");
    }
  }
}