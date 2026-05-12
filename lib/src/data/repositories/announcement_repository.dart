import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../local/app_database.dart';
import '../../providers/db_provider.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository(ref.watch(dbProvider), FirebaseFirestore.instance);
});

class AnnouncementRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final Dio _dio = Dio();

  final String _vercelUrl = "https://stagecall-api.vercel.app/api/notify";

  AnnouncementRepository(this._db, this._firestore);

  /// WATCH: Only show announcements that target the student AND are NOT deleted
  Stream<List<Announcement>> watchMyAnnouncements(int semester, String section, String role, String uid) {
    return _db.select(_db.announcements).watch().map((all) {
      return all.where((notice) {
        // 1. SILENT FILTER: Hide soft-deleted notices instantly
        if (notice.isDeleted) return false;

        // 2. Global and authored notices are always visible
        if (notice.isGlobal) return true;
        if (notice.authorUid == uid) return true;

        // 3. Teachers should ONLY see global and authored announcements.
        // This prevents them from seeing random student section notices.
        if (role == 'teacher') return false;

        // 4. Students see targeted announcements
        final targetSems = List<int>.from(jsonDecode(notice.targetSemesters));
        final targetSecs = List<String>.from(jsonDecode(notice.targetSections))
            .map((s) => s.toUpperCase().trim());

        return targetSems.contains(semester) && targetSecs.contains(section.toUpperCase().trim());
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  /// SYNC: Fetch from Firebase and update local DB
  Future<void> syncAnnouncements() async {
    try {
      final snapshot = await _firestore.collection("announcements").get();

      // 1. Prepare a list of companions
      List<AnnouncementsCompanion> companions = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        DateTime createdDate = (data["createdAt"] != null && data["createdAt"] is Timestamp)
            ? (data["createdAt"] as Timestamp).toDate()
            : DateTime.now();

        companions.add(AnnouncementsCompanion(
          id: Value(doc.id),
          title: Value(data["title"] ?? "No Title"),
          body: Value(data["body"] ?? "No Content"),
          authorName: Value(data["authorName"] ?? "Anonymous"),
          authorUid: Value(data["authorUid"] ?? ""),
          isDeleted: Value(data["isDeleted"] ?? false),
          targetSemesters: Value(jsonEncode(data["targetSemesters"] ?? [])),
          targetSections: Value(jsonEncode(data["targetSections"] ?? [])),
          isGlobal: Value(data["isGlobal"] ?? false),
          createdAt: Value(createdDate),
        ));
      }

      // 2. Perform a massive BATCH insert (100x faster)
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(_db.announcements, companions);
      });

    } catch (e) {
      print("DEBUG: Announcement Sync Error: $e");
    }
  }

  /// CREATE: Now demands the authorUid to prove ownership
  Future<void> createAnnouncement({
    required String title,
    required String body,
    required String authorName,
    required String authorUid, // NEW PARAMETER
    required List<int> targetSemesters,
    required List<String> targetSections,
    required bool isGlobal,
  }) async {
    try {
      final docRef = await _firestore.collection("announcements").add({
        "title": title,
        "body": body,
        "authorName": authorName,
        "authorUid": authorUid, // Saved to cloud
        "isDeleted": false,     // Defaults to visible
        "targetSemesters": targetSemesters,
        "targetSections": targetSections,
        "isGlobal": isGlobal,
        "createdAt": FieldValue.serverTimestamp(),
      });

      await _db.into(_db.announcements).insertOnConflictUpdate(
        AnnouncementsCompanion(
          id: Value(docRef.id),
          title: Value(title),
          body: Value(body),
          authorName: Value(authorName),
          authorUid: Value(authorUid),
          isDeleted: Value(false),
          targetSemesters: Value(jsonEncode(targetSemesters)),
          targetSections: Value(jsonEncode(targetSections)),
          isGlobal: Value(isGlobal),
          createdAt: Value(DateTime.now()),
        ),
      );

      List<String> topics = [];
      if (isGlobal) {
        topics.add("global");
      } else {
        for (var sem in targetSemesters) {
          for (var sec in targetSections) {
            topics.add("sem_${sem}_sec_${sec.toUpperCase().trim()}");
          }
        }
      }

      await _dio.post(
        _vercelUrl,
        data: {
          "title": title,
          "body": body,
          "topics": topics,
        },
      );
    } catch (e) {
      print("DEBUG: General error in createAnnouncement: $e");
    }
  }

  /// THE MAGIC: Soft Delete
  Future<void> softDeleteAnnouncement(String noticeId) async {
    try {
      // 1. Tell Firestore to hide it (Legal compliance maintained)
      await _firestore.collection("announcements").doc(noticeId).update({
        "isDeleted": true,
      });

      // 2. Tell the Local DB to hide it INSTANTLY (UX perfection)
      await (_db.update(_db.announcements)..where((t) => t.id.equals(noticeId))).write(
        const AnnouncementsCompanion(
          isDeleted: Value(true),
        ),
      );

      print("DEBUG: Successfully soft-deleted notice: $noticeId");
    } catch (e) {
      print("DEBUG: Failed to delete notice: $e");
    }
  }

  /// UPDATE: Modifies an existing announcement securely
  Future<void> updateAnnouncement({
    required String noticeId,
    required String title,
    required String body,
    required List<int> targetSemesters,
    required List<String> targetSections,
    required bool isGlobal,
  }) async {
    try {
      // 1. Update Remote Firestore
      await _firestore.collection("announcements").doc(noticeId).update({
        "title": title,
        "body": body,
        "targetSemesters": targetSemesters,
        "targetSections": targetSections,
        "isGlobal": isGlobal,
        // We strictly DO NOT update authorUid, authorName, or createdAt
      });

      // 2. Update Local SQLite instantly
      await (_db.update(_db.announcements)..where((t) => t.id.equals(noticeId))).write(
        AnnouncementsCompanion(
          title: Value(title),
          body: Value(body),
          targetSemesters: Value(jsonEncode(targetSemesters)),
          targetSections: Value(jsonEncode(targetSections)),
          isGlobal: Value(isGlobal),
        ),
      );

      // 3. Trigger 'Updated' Notification
      List<String> topics = [];
      if (isGlobal) {
        topics.add("global");
      } else {
        for (var sem in targetSemesters) {
          for (var sec in targetSections) {
            topics.add("sem_${sem}_sec_${sec.toUpperCase().trim()}");
          }
        }
      }

      await _dio.post(
        _vercelUrl,
        data: {
          "title": "UPDATE: $title",
          "body": body,
          "topics": topics,
        },
      );

      print("DEBUG: Successfully updated notice: $noticeId");
    } catch (e) {
      print("DEBUG: Failed to update notice: $e");
      throw Exception("Failed to update announcement. Please check your connection.");
    }
  }
}