import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import '../../providers/db_provider.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(
    ref.watch(dbProvider),
    FirebaseFirestore.instance,
  );
});

class UserRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;

  UserRepository(
      this._db,
      this._firestore,
      );

  Stream<User?> watchUser(String uid) {
    return (_db.select(_db.users)
      ..where((user) => user.id.equals(uid)))
        .watchSingleOrNull();
  }

  Future<User?> getUserLocally(String uid) async {
    return (_db.select(_db.users)
      ..where((user) => user.id.equals(uid)))
        .getSingleOrNull();
  }

  Future<void> _updateFCMSubscriptions(
      int newSem,
      String newSec, {
        int? oldSem,
        String? oldSec,
      }) async {
    try {
      await _fcm.subscribeToTopic('global');

      if (oldSem != null && oldSec != null) {
        final oldTopic =
            'sem_${oldSem}_sec_${oldSec.trim().toUpperCase()}';

        await _fcm.unsubscribeFromTopic(oldTopic);
      }

      final newTopic =
          'sem_${newSem}_sec_${newSec.trim().toUpperCase()}';

      await _fcm.subscribeToTopic(newTopic);
    } catch (e, stackTrace) {
      debugPrint(
        'FCM subscription update failed: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> syncUser(String uid) async {
    try {
      final currentUser =
          firebase_auth.FirebaseAuth.instance.currentUser;

      if (currentUser == null) {
        return;
      }

      final email = currentUser.email ?? '';

      Map<String, dynamic>? data;
      String resolvedInternalId = '';
      bool fetchFailed = false;

      try {
        if (email.endsWith('@bgctub.ac.bd')) {
          final doc = await _firestore
              .collection('teachers')
              .doc(email)
              .get();

          if (doc.exists) {
            data = doc.data();
            resolvedInternalId =
                data?['internalId']?.toString() ?? email;
          }
        } else if (email.isNotEmpty) {
          final internalIdFromEmail = email.split('@').first;

          if (internalIdFromEmail.isNotEmpty) {
            final doc = await _firestore
                .collection('students')
                .doc(internalIdFromEmail)
                .get();

            if (doc.exists) {
              data = doc.data();
              resolvedInternalId =
                  data?['internalId']?.toString() ??
                      internalIdFromEmail;
            }
          }
        }

        if (data == null) {
          var snapshot = await _firestore
              .collection('students')
              .where('uid', isEqualTo: uid)
              .limit(1)
              .get();

          if (snapshot.docs.isNotEmpty) {
            data = snapshot.docs.first.data();
            resolvedInternalId =
                data['internalId']?.toString() ?? '';
          } else {
            snapshot = await _firestore
                .collection('teachers')
                .where('uid', isEqualTo: uid)
                .limit(1)
                .get();

            if (snapshot.docs.isNotEmpty) {
              data = snapshot.docs.first.data();
              resolvedInternalId =
                  data['internalId']?.toString() ?? email;
            }
          }
        }
      } catch (firestoreError, stackTrace) {
        fetchFailed = true;

        debugPrint(
          'Firestore user fetch failed: $firestoreError',
        );
        debugPrintStack(stackTrace: stackTrace);
      }

      if (data == null) {
        if (fetchFailed) {
          throw Exception(
            'Network error or offline. Could not sync profile.',
          );
        }

        await firebase_auth.FirebaseAuth.instance.signOut();

        throw Exception(
          'Profile data missing. You have been safely logged out.',
        );
      }

      // Security-sensitive privileges are no longer read from the
      // mutable student profile.
      //
      // The authoritative source is roles/{uid}.
      final roleSnapshot = await _firestore
          .collection('roles')
          .doc(uid)
          .get();

      final roleData = roleSnapshot.data();

      final bool isDev =
          roleData?['isDev'] == true;

      final bool isCR =
          roleData?['isCR'] == true;

      final localUser = await (_db.select(_db.users)
        ..where((user) => user.id.equals(uid)))
          .getSingleOrNull();

      final role =
          data['role']?.toString().trim().toLowerCase() ??
              'student';

      final int newSem =
          int.tryParse(
            data['semester']?.toString() ?? '',
          ) ??
              1;

      final String newSec =
      (data['section']?.toString() ?? 'A')
          .trim()
          .toUpperCase();

      final int avatarId =
          int.tryParse(
            data['avatarId']?.toString() ?? '',
          ) ??
              1;

      await _updateFCMSubscriptions(
        newSem,
        newSec,
        oldSem: localUser?.semester,
        oldSec: localUser?.section,
      );

      DateTime? lastProfileUpdate;

      final rawLastProfileUpdate =
      data['lastProfileUpdate'];

      if (rawLastProfileUpdate is Timestamp) {
        lastProfileUpdate =
            rawLastProfileUpdate.toDate();
      }

      await _db.into(_db.users).insertOnConflictUpdate(
        UsersCompanion(
          id: Value(uid),
          name: Value(
            data['name']?.toString() ?? 'Unknown',
          ),
          internalId: Value(resolvedInternalId),
          semester: Value(newSem),
          section: Value(newSec),
          role: Value(role),
          isDev: Value(isDev),
          isCR: Value(isCR),
          avatarId: Value(avatarId),
          lastProfileUpdate: Value(lastProfileUpdate),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'User sync error: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateProfile({
    required String uid,
    required String name,
    required int semester,
    required String section,
    required int avatarId,
  }) async {
    final localUser =
    await getUserLocally(uid);

    if (localUser == null) {
      throw Exception(
        'User data not found locally. Please sync first.',
      );
    }

    if (semester < 1 || semester > 8) {
      throw ArgumentError(
        'Semester must be between 1 and 8.',
      );
    }

    final normalizedSection =
    section.trim().toUpperCase();

    if (!const {'A', 'B', 'C'}.contains(normalizedSection)) {
      throw ArgumentError(
        'Invalid section.',
      );
    }

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError(
        'Name cannot be empty.',
      );
    }

    if (normalizedName.length > 100) {
      throw ArgumentError(
        'Name is too long.',
      );
    }

    if (localUser.role != 'teacher' &&
        !localUser.isDev) {
      const cooldownDays = 15;

      if (localUser.lastProfileUpdate != null) {
        final difference = DateTime.now().difference(
          localUser.lastProfileUpdate!,
        );

        if (difference.inDays < cooldownDays) {
          final remaining =
              Duration(days: cooldownDays) - difference;

          throw Exception(
            'Cooldown: '
                '${remaining.inDays}d '
                '${remaining.inHours % 24}h remaining.',
          );
        }
      }
    }

    await _updateFCMSubscriptions(
      semester,
      normalizedSection,
      oldSem: localUser.semester,
      oldSec: localUser.section,
    );

    await _firestore
        .collection('students')
        .doc(localUser.internalId)
        .update({
      'name': normalizedName,
      'semester': semester,
      'section': normalizedSection,
      'avatarId': avatarId,
      'lastProfileUpdate':
      FieldValue.serverTimestamp(),
    });

    await _db.into(_db.users).insertOnConflictUpdate(
      UsersCompanion(
        id: Value(uid),
        name: Value(normalizedName),
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

  Future<void> updateTeacherProfile(
      String uid,
      String name,
      int avatarId,
      ) async {
    final localUser =
    await getUserLocally(uid);

    if (localUser == null) {
      throw Exception(
        'User data not found locally.',
      );
    }

    final normalizedName = name.trim();

    if (normalizedName.isEmpty) {
      throw ArgumentError(
        'Name cannot be empty.',
      );
    }

    await _firestore
        .collection('teachers')
        .doc(localUser.internalId)
        .update({
      'name': normalizedName,
      'avatarId': avatarId,
    });

    await (_db.update(_db.users)
      ..where((user) => user.id.equals(uid)))
        .write(
      UsersCompanion(
        name: Value(normalizedName),
        avatarId: Value(avatarId),
      ),
    );
  }

  /// Changes administrator-controlled privilege state.
  ///
  /// The roles document is authoritative.
  /// The student profile flags are maintained only as a
  /// backwards-compatible local/cloud projection.
  Future<void> updateStudentPrivileges({
    required String studentDocId,
    required String uid,
    required bool isDev,
    required bool isCR,
  }) async {
    if (studentDocId.trim().isEmpty) {
      throw ArgumentError(
        'Student document ID cannot be empty.',
      );
    }

    if (uid.trim().isEmpty) {
      throw ArgumentError(
        'Student UID cannot be empty.',
      );
    }

    final batch = _firestore.batch();

    final roleRef =
    _firestore.collection('roles').doc(uid);

    final studentRef =
    _firestore.collection('students').doc(studentDocId);

    batch.set(
      roleRef,
      {
        'isDev': isDev,
        'isCR': isCR,
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.update(
      studentRef,
      {
        'isDev': isDev,
        'isCR': isCR,
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();

    final localUser =
    await getUserLocally(uid);

    if (localUser != null) {
      await _db.into(_db.users).insertOnConflictUpdate(
        UsersCompanion(
          id: Value(uid),
          name: Value(localUser.name),
          internalId: Value(localUser.internalId),
          semester: Value(localUser.semester),
          section: Value(localUser.section),
          role: Value(localUser.role),
          isDev: Value(isDev),
          isCR: Value(isCR),
          avatarId: Value(localUser.avatarId),
          lastProfileUpdate:
          Value(localUser.lastProfileUpdate),
        ),
      );
    }
  }

  Future<void> updateStudentAcademicRoute({
    required String studentDocId,
    required int semester,
    required String section,
  }) async {
    if (studentDocId.trim().isEmpty) {
      throw ArgumentError(
        'Student document ID cannot be empty.',
      );
    }

    if (semester < 1 || semester > 8) {
      throw ArgumentError(
        'Semester must be between 1 and 8.',
      );
    }

    final normalizedSection =
    section.trim().toUpperCase();

    if (!const {'A', 'B', 'C'}.contains(normalizedSection)) {
      throw ArgumentError(
        'Invalid section.',
      );
    }

    final batch = _firestore.batch();

    batch.update(
      _firestore
          .collection('students')
          .doc(studentDocId),
      {
        'semester': semester,
        'section': normalizedSection,
        'updatedAt':
        FieldValue.serverTimestamp(),
      },
    );

    await batch.commit();
  }
}