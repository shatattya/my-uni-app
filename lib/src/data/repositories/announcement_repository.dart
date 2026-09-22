import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:drift/drift.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../local/app_database.dart';
import '../models/announcement_target.dart';
import '../../providers/db_provider.dart';

final announcementRepositoryProvider =
Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(
    ref.watch(dbProvider),
    FirebaseFirestore.instance,
  );
});

class AnnouncementRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final Dio _dio;

  static const String _notificationUrl =
      'https://stagecall-api.vercel.app/api/notify';

  AnnouncementRepository(
      this._db,
      this._firestore,
      ) : _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      sendTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 8),
    ),
  );

  Stream<List<Announcement>> watchMyAnnouncements(
      int semester,
      String section,
      String role,
      String uid,
      ) {
    final normalizedSection = section.trim().toUpperCase();

    return _db.select(_db.announcements).watch().map((all) {
      final visible = all.where((notice) {
        if (notice.isDeleted) {
          return false;
        }

        if (notice.isGlobal) {
          return true;
        }

        if (notice.authorUid == uid) {
          return true;
        }

        // Teachers see global and authored notices only.
        if (role == 'teacher') {
          return false;
        }

        final targets = _getLocalTargets(notice);

        return targets.any(
              (target) =>
          target.semester == semester &&
              target.normalizedSection == normalizedSection,
        );
      }).toList();

      visible.sort(
            (a, b) => b.createdAt.compareTo(a.createdAt),
      );

      return visible;
    });
  }

  Future<void> syncAnnouncements() async {
    final snapshot = await _firestore
        .collection('announcements')
        .get();

    final companions = <AnnouncementsCompanion>[];

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final createdDate = _readCreatedAt(
        data['createdAt'],
      );

      final targets = _getRemoteTargets(data);

      companions.add(
        AnnouncementsCompanion(
          id: Value(doc.id),
          title: Value(
            data['title']?.toString() ?? 'No Title',
          ),
          body: Value(
            data['body']?.toString() ?? 'No Content',
          ),
          authorName: Value(
            data['authorName']?.toString() ?? 'Anonymous',
          ),
          authorUid: Value(
            data['authorUid']?.toString() ?? '',
          ),
          isDeleted: Value(
            data['isDeleted'] == true,
          ),
          targetSemesters: Value(
            jsonEncode(
              _readIntList(data['targetSemesters']),
            ),
          ),
          targetSections: Value(
            jsonEncode(
              _readStringList(data['targetSections']),
            ),
          ),
          targetGroups: Value(
            AnnouncementTarget.encodeList(targets),
          ),
          isGlobal: Value(
            data['isGlobal'] == true,
          ),
          createdAt: Value(createdDate),
        ),
      );
    }

    await _db.batch(
          (batch) {
        batch.insertAllOnConflictUpdate(
          _db.announcements,
          companions,
        );
      },
    );
  }

  Future<void> createAnnouncement({
    required String title,
    required String body,
    required String authorName,
    required String authorUid,
    required List<AnnouncementTarget> targetGroups,
    required bool isGlobal,
  }) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    if (currentUid == null) {
      throw StateError('User is not logged in.');
    }

    if (authorUid != currentUid) {
      throw StateError(
        'Announcement author does not match the signed-in user.',
      );
    }

    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Announcement title cannot be empty.');
    }

    if (normalizedBody.isEmpty) {
      throw ArgumentError('Announcement body cannot be empty.');
    }

    if (normalizedTitle.length > 200) {
      throw ArgumentError(
        'Announcement title is too long.',
      );
    }

    if (normalizedBody.length > 10000) {
      throw ArgumentError(
        'Announcement body is too long.',
      );
    }

    final normalizedTargets = <AnnouncementTarget>[];

    for (final target in targetGroups) {
      if (!normalizedTargets.contains(target)) {
        normalizedTargets.add(target);
      }
    }

    if (isGlobal && normalizedTargets.isNotEmpty) {
      throw ArgumentError(
        'A global announcement cannot contain target groups.',
      );
    }

    if (!isGlobal && normalizedTargets.isEmpty) {
      throw ArgumentError(
        'At least one target group is required.',
      );
    }

    if (normalizedTargets.length > 20) {
      throw ArgumentError(
        'Too many target groups.',
      );
    }

    final targetMaps =
    normalizedTargets.map((target) => target.toMap()).toList();

    final legacySemesters = normalizedTargets
        .map((target) => target.semester)
        .toSet()
        .toList()
      ..sort();

    final legacySections = normalizedTargets
        .map((target) => target.normalizedSection)
        .toSet()
        .toList()
      ..sort();

    final docRef =
    _firestore.collection('announcements').doc();

    await docRef.set({
      'title': normalizedTitle,
      'body': normalizedBody,
      'authorName': authorName.trim(),
      'authorUid': authorUid,
      'isDeleted': false,
      'targetGroups': targetMaps,
      'targetSemesters':
      isGlobal ? <int>[] : legacySemesters,
      'targetSections':
      isGlobal ? <String>[] : legacySections,
      'isGlobal': isGlobal,
      'createdAt': FieldValue.serverTimestamp(),
    });

    try {
      await _db.into(_db.announcements).insertOnConflictUpdate(
        AnnouncementsCompanion(
          id: Value(docRef.id),
          title: Value(normalizedTitle),
          body: Value(normalizedBody),
          authorName: Value(authorName.trim()),
          authorUid: Value(authorUid),
          isDeleted: const Value(false),
          targetSemesters: Value(
            jsonEncode(
              isGlobal ? <int>[] : legacySemesters,
            ),
          ),
          targetSections: Value(
            jsonEncode(
              isGlobal ? <String>[] : legacySections,
            ),
          ),
          targetGroups: Value(
            AnnouncementTarget.encodeList(
              normalizedTargets,
            ),
          ),
          isGlobal: Value(isGlobal),
          createdAt: Value(DateTime.now()),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Announcement cloud write succeeded, '
            'but local cache update failed: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    await _sendNotificationBestEffort(
      title: normalizedTitle,
      body: normalizedBody,
      targets: normalizedTargets,
      isGlobal: isGlobal,
    );
  }

  Future<void> softDeleteAnnouncement(
      String noticeId,
      ) async {
    if (noticeId.trim().isEmpty) {
      throw ArgumentError('Announcement ID cannot be empty.');
    }

    await _firestore
        .collection('announcements')
        .doc(noticeId)
        .update({
      'isDeleted': true,
    });

    try {
      await (_db.update(_db.announcements)
        ..where((table) => table.id.equals(noticeId)))
          .write(
        const AnnouncementsCompanion(
          isDeleted: Value(true),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Cloud delete succeeded, but local cache update failed: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateAnnouncement({
    required String noticeId,
    required String title,
    required String body,
    required List<AnnouncementTarget> targetGroups,
    required bool isGlobal,
  }) async {
    if (noticeId.trim().isEmpty) {
      throw ArgumentError('Announcement ID cannot be empty.');
    }

    final normalizedTitle = title.trim();
    final normalizedBody = body.trim();

    if (normalizedTitle.isEmpty) {
      throw ArgumentError('Announcement title cannot be empty.');
    }

    if (normalizedBody.isEmpty) {
      throw ArgumentError('Announcement body cannot be empty.');
    }

    final normalizedTargets = <AnnouncementTarget>[];

    for (final target in targetGroups) {
      if (!normalizedTargets.contains(target)) {
        normalizedTargets.add(target);
      }
    }

    if (isGlobal && normalizedTargets.isNotEmpty) {
      throw ArgumentError(
        'A global announcement cannot contain target groups.',
      );
    }

    if (!isGlobal && normalizedTargets.isEmpty) {
      throw ArgumentError(
        'At least one target group is required.',
      );
    }

    final legacySemesters = normalizedTargets
        .map((target) => target.semester)
        .toSet()
        .toList()
      ..sort();

    final legacySections = normalizedTargets
        .map((target) => target.normalizedSection)
        .toSet()
        .toList()
      ..sort();

    await _firestore
        .collection('announcements')
        .doc(noticeId)
        .update({
      'title': normalizedTitle,
      'body': normalizedBody,
      'targetGroups':
      normalizedTargets.map((target) => target.toMap()).toList(),
      'targetSemesters':
      isGlobal ? <int>[] : legacySemesters,
      'targetSections':
      isGlobal ? <String>[] : legacySections,
      'isGlobal': isGlobal,
    });

    try {
      await (_db.update(_db.announcements)
        ..where((table) => table.id.equals(noticeId)))
          .write(
        AnnouncementsCompanion(
          title: Value(normalizedTitle),
          body: Value(normalizedBody),
          targetSemesters: Value(
            jsonEncode(
              isGlobal ? <int>[] : legacySemesters,
            ),
          ),
          targetSections: Value(
            jsonEncode(
              isGlobal ? <String>[] : legacySections,
            ),
          ),
          targetGroups: Value(
            AnnouncementTarget.encodeList(
              normalizedTargets,
            ),
          ),
          isGlobal: Value(isGlobal),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint(
        'Cloud announcement update succeeded, '
            'but local cache update failed: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }

    await _sendNotificationBestEffort(
      title: 'UPDATE: $normalizedTitle',
      body: normalizedBody,
      targets: normalizedTargets,
      isGlobal: isGlobal,
    );
  }

  List<AnnouncementTarget> _getRemoteTargets(
      Map<String, dynamic> data,
      ) {
    final rawTargetGroups = data['targetGroups'];

    if (rawTargetGroups is List) {
      return _decodeTargetList(rawTargetGroups);
    }

    // Existing records created before targetGroups existed.
    return AnnouncementTarget.fromLegacyLists(
      data['targetSemesters'],
      data['targetSections'],
    );
  }

  List<AnnouncementTarget> _getLocalTargets(
      Announcement notice,
      ) {
    final canonical =
    AnnouncementTarget.decodeList(notice.targetGroups);

    if (canonical.isNotEmpty) {
      return canonical;
    }

    if (notice.targetSemesters.trim().isEmpty &&
        notice.targetSections.trim().isEmpty) {
      return const [];
    }

    // Backwards compatibility for local records created before schema 10.
    return AnnouncementTarget.fromLegacyLists(
      notice.targetSemesters,
      notice.targetSections,
    );
  }

  List<AnnouncementTarget> _decodeTargetList(
      List<dynamic> source,
      ) {
    final result = <AnnouncementTarget>[];

    for (final item in source) {
      final target = AnnouncementTarget.fromMap(item);

      if (target != null && !result.contains(target)) {
        result.add(target);
      }
    }

    return result;
  }

  List<int> _readIntList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    final result = <int>[];

    for (final item in value) {
      final parsed = switch (item) {
        int value => value,
        num value => value.toInt(),
        _ => int.tryParse(item?.toString() ?? ''),
      };

      if (parsed != null) {
        result.add(parsed);
      }
    }

    return result;
  }

  List<String> _readStringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList();
  }

  DateTime _readCreatedAt(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.now();
  }

  Future<void> _sendNotificationBestEffort({
    required String title,
    required String body,
    required List<AnnouncementTarget> targets,
    required bool isGlobal,
  }) async {
    final topics = isGlobal
        ? <String>['global']
        : targets
        .map((target) => target.topic)
        .toSet()
        .toList();

    if (topics.isEmpty) {
      return;
    }

    try {
      await _dio.post(
        _notificationUrl,
        data: {
          'title': title,
          'body': body,
          'topics': topics,
        },
      );
    } catch (e, stackTrace) {
      // The announcement itself is already persisted.
      // Notification delivery is a secondary operation.
      debugPrint(
        'Announcement persisted, but notification delivery failed: $e',
      );
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}