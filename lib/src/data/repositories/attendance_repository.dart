import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

import '../local/app_database.dart';
import '../../providers/db_provider.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(ref.watch(dbProvider), FirebaseFirestore.instance);
});

class AttendanceRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  AttendanceRepository(this._db, this._firestore);

  /// 1. Get unique classes (subject, sem, sec) for a teacher from local routines
  Future<List<Map<String, dynamic>>> getTeacherClasses(String teacherId) async {
    final cleanId = teacherId.trim().toLowerCase();

    final routines = await (_db.select(_db.routines)
      ..where((r) => r.teacherId.equals(cleanId)))
        .get();

    final uniqueClasses = <String, Map<String, dynamic>>{};

    for (var r in routines) {
      final key = "${r.subjectName}_${r.semester}_${r.section}";
      if (!uniqueClasses.containsKey(key)) {
        uniqueClasses[key] = {
          "subjectName": r.subjectName,
          "semester": r.semester,
          "section": r.section,
        };
      }
    }

    final result = uniqueClasses.values.toList();
    result.sort((a, b) => a["subjectName"].compareTo(b["subjectName"]));
    return result;
  }

  /// 2. Fetch students (Offline first, fallback to Firestore)
  Future<List<CachedStudent>> getStudents(int semester, String section) async {
    final normalizedSection = section.toUpperCase().trim();

    var localStudents = await (_db.select(_db.cachedStudents)
      ..where((s) => s.semester.equals(semester))
      ..where((s) => s.section.equals(normalizedSection))
      ..orderBy([(t) => OrderingTerm(expression: t.studentId)]))
        .get();

    if (localStudents.isNotEmpty) {
      _syncStudentsFromCloud(semester, normalizedSection);
      return localStudents;
    }

    await _syncStudentsFromCloud(semester, normalizedSection);

    return await (_db.select(_db.cachedStudents)
      ..where((s) => s.semester.equals(semester))
      ..where((s) => s.section.equals(normalizedSection))
      ..orderBy([(t) => OrderingTerm(expression: t.studentId)]))
        .get();
  }

  Future<void> _syncStudentsFromCloud(int semester, String section) async {
    try {
      final snapshot = await _firestore
          .collection("students")
          .where("semester", isEqualTo: semester)
          .where("section", isEqualTo: section)
          .get();

      List<CachedStudentsCompanion> companions = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        companions.add(CachedStudentsCompanion(
          studentId: Value(data["internalId"] ?? doc.id),
          name: Value(data["name"] ?? "Unknown"),
          semester: Value(semester),
          section: Value(section),
          isActive: const Value(true),
          updatedAt: Value(DateTime.now()),
        ));
      }

      if (companions.isNotEmpty) {
        await _db.batch((batch) {
          batch.insertAllOnConflictUpdate(_db.cachedStudents, companions);
        });
      }
    } catch (e) {
      print("DEBUG: Failed to sync students from cloud: $e");
    }
  }

  /// 3. Save Attendance (Local + Sync to Cloud)
  Future<void> saveAttendance({
    required String subjectName,
    required int semester,
    required String section,
    required String date,
    required List<String> presentStudentIds,
  }) async {
    final normalizedSection = section.toUpperCase().trim();
    final cleanSubject = subjectName.replaceAll(' ', '_');
    final String attendanceId = "${cleanSubject}_${semester}_${normalizedSection}_$date";

    final existingRecord = await (_db.select(_db.attendanceRecords)
      ..where((a) => a.attendanceId.equals(attendanceId)))
        .getSingleOrNull();

    final now = DateTime.now();
    final createdAt = existingRecord?.createdAt ?? now;

    await _db.into(_db.attendanceRecords).insertOnConflictUpdate(
      AttendanceRecordsCompanion(
        attendanceId: Value(attendanceId),
        subjectId: Value(subjectName),
        semester: Value(semester),
        section: Value(normalizedSection),
        date: Value(date),
        presentStudentIds: Value(jsonEncode(presentStudentIds)),
        isSynced: const Value(false),
        createdAt: Value(createdAt),
        updatedAt: Value(now),
      ),
    );

    try {
      await _firestore.collection("attendance_records").doc(attendanceId).set({
        "attendanceId": attendanceId,
        "subjectId": subjectName,
        "semester": semester,
        "section": normalizedSection,
        "date": date,
        "presentStudentIds": presentStudentIds,
        "createdAt": createdAt.toIso8601String(),
        "updatedAt": now.toIso8601String(),
      });

      await (_db.update(_db.attendanceRecords)
        ..where((a) => a.attendanceId.equals(attendanceId)))
          .write(const AttendanceRecordsCompanion(isSynced: Value(true)));

    } catch (e) {
      print("DEBUG: Offline mode - Attendance saved locally, waiting for manual sync.");
    }
  }

  /// 4. Generate CSV Report
  Future<String> generateCsvReport({
    required String subjectName,
    required int semester,
    required String section,
    required DateTime startDate,
    required DateTime endDate,
    required double maxMarks,
    required String mode,
  }) async {
    final normalizedSection = section.toUpperCase().trim();
    final startStr = DateFormat('yyyy-MM-dd').format(startDate);
    final endStr = DateFormat('yyyy-MM-dd').format(endDate);

    final records = await (_db.select(_db.attendanceRecords)
      ..where((a) => a.subjectId.equals(subjectName))
      ..where((a) => a.semester.equals(semester))
      ..where((a) => a.section.equals(normalizedSection))
      ..where((a) => a.date.isBetweenValues(startStr, endStr)))
        .get();

    final students = await getStudents(semester, normalizedSection);

    final studentCount = <String, int>{};
    for (var s in students) {
      studentCount[s.studentId] = 0;
    }

    for (var record in records) {
      final presentIds = List<String>.from(jsonDecode(record.presentStudentIds));
      for (var sid in presentIds) {
        if (studentCount.containsKey(sid)) {
          studentCount[sid] = studentCount[sid]! + 1;
        }
      }
    }

    final totalClasses = records.length;
    final buffer = StringBuffer();
    buffer.writeln("StudentId,StudentName,TotalClasses,PresentCount,Percentage,MarksAwarded");

    for (var student in students) {
      final present = studentCount[student.studentId] ?? 0;
      final double percentage = totalClasses == 0 ? 0.0 : (present / totalClasses) * 100;
      double marks = 0.0;

      if (mode == 'Linear') {
        marks = (percentage / 100.0) * maxMarks;
      } else if (mode == 'Bucketed') {
        if (percentage >= 90) marks = maxMarks;
        else if (percentage >= 75) marks = maxMarks * 0.8;
        else if (percentage >= 60) marks = maxMarks * 0.6;
        else marks = 0.0;
      }

      buffer.writeln("${student.studentId},${student.name},$totalClasses,$present,${percentage.toStringAsFixed(2)},${marks.toStringAsFixed(2)}");
    }

    final directory = await getTemporaryDirectory();
    final safeSubject = subjectName.replaceAll(' ', '_');
    final fileName = "Attendance_${safeSubject}_${semester}_${normalizedSection}.csv";
    final file = File('${directory.path}/$fileName');

    await file.writeAsString(buffer.toString());
    return file.path;
  }

  /// 5. Get Recent Attendance History
  Future<List<AttendanceRecord>> getRecentAttendance({int limit = 25, int offset = 0}) async {
    return await (_db.select(_db.attendanceRecords)
      ..orderBy([(t) => OrderingTerm(expression: t.date, mode: OrderingMode.desc)])
      ..limit(limit, offset: offset))
        .get();
  }

  /// 6. Count Pending Syncs
  Future<int> getPendingSyncCount() async {
    final records = await (_db.select(_db.attendanceRecords)..where((a) => a.isSynced.equals(false))).get();
    return records.length;
  }

  /// 7. Execute TWO-WAY Cloud Sync
  /// Returns [true] if new updates were synced (up or down), [false] if everything was already up to date.
  Future<bool> syncPendingRecords(String teacherId) async {
    bool hasUpdates = false;

    try {
      // --- PART 1: UPLOAD PENDING LOCAL RECORDS ---
      final pendingRecords = await (_db.select(_db.attendanceRecords)..where((a) => a.isSynced.equals(false))).get();
      if (pendingRecords.isNotEmpty) {
        final batch = _firestore.batch();

        for (var record in pendingRecords) {
          final docRef = _firestore.collection("attendance_records").doc(record.attendanceId);
          final presentIds = List<String>.from(jsonDecode(record.presentStudentIds));

          batch.set(docRef, {
            "attendanceId": record.attendanceId,
            "subjectId": record.subjectId,
            "semester": record.semester,
            "section": record.section,
            "date": record.date,
            "presentStudentIds": presentIds,
            "createdAt": record.createdAt.toIso8601String(),
            "updatedAt": record.updatedAt.toIso8601String(),
          });
        }

        await batch.commit();

        // Mark local as synced
        await (_db.update(_db.attendanceRecords)..where((a) => a.isSynced.equals(false)))
            .write(const AttendanceRecordsCompanion(isSynced: Value(true)));

        hasUpdates = true;
      }

      // --- PART 2: DOWNLOAD CLOUD RECORDS ---
      final classes = await getTeacherClasses(teacherId);
      if (classes.isNotEmpty) {
        // Fetch existing local records to compare
        final existingLocalRecords = await _db.select(_db.attendanceRecords).get();
        final localRecordMap = {for (var r in existingLocalRecords) r.attendanceId: r};

        List<AttendanceRecordsCompanion> cloudCompanions = [];

        for (var c in classes) {
          final snapshot = await _firestore.collection("attendance_records")
              .where("subjectId", isEqualTo: c["subjectName"])
              .where("semester", isEqualTo: c["semester"])
              .where("section", isEqualTo: c["section"])
              .get();

          for (var doc in snapshot.docs) {
            final data = doc.data();
            final String cloudId = data["attendanceId"];
            final DateTime cloudUpdatedAt = DateTime.parse(data["updatedAt"]);

            bool needsUpdate = false;

            if (!localRecordMap.containsKey(cloudId)) {
              needsUpdate = true; // New record from cloud
            } else {
              final localUpdatedAt = localRecordMap[cloudId]!.updatedAt;
              if (cloudUpdatedAt.isAfter(localUpdatedAt)) {
                needsUpdate = true; // Cloud record is newer than local
              }
            }

            if (needsUpdate) {
              hasUpdates = true;
              cloudCompanions.add(AttendanceRecordsCompanion(
                attendanceId: Value(cloudId),
                subjectId: Value(data["subjectId"]),
                semester: Value(data["semester"]),
                section: Value(data["section"]),
                date: Value(data["date"]),
                presentStudentIds: Value(jsonEncode(data["presentStudentIds"])),
                isSynced: const Value(true), // Marked true since it matches cloud perfectly
                createdAt: Value(DateTime.parse(data["createdAt"])),
                updatedAt: Value(cloudUpdatedAt),
              ));
            }
          }
        }

        if (cloudCompanions.isNotEmpty) {
          await _db.batch((batch) {
            batch.insertAllOnConflictUpdate(_db.attendanceRecords, cloudCompanions);
          });
        }
      }

      return hasUpdates;
    } catch (e) {
      // Throwing the exact error so the UI layer can display the error code dialog
      throw Exception(e.toString());
    }
  }
}