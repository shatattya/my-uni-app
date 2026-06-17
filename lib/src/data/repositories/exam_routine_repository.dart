import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart'; // ADDED: For debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../local/app_database.dart';
import '../../providers/db_provider.dart';

final examRoutineRepositoryProvider = Provider<ExamRoutineRepository>((ref) {
  return ExamRoutineRepository(ref.watch(dbProvider), FirebaseFirestore.instance);
});

class ExamRoutineRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  bool _isSyncing = false;

  static const String _prefExamEndDate = 'examEndDate';
  static const String _prefExamId = 'currentExamId';
  static const String _prefExamTitle = 'currentExamTitle';
  static const String _prefRoomAllocations = 'roomAllocations'; // ADDED: Key for global rooms

  ExamRoutineRepository(this._db, this._firestore);

  /// Get the current master Exam ID (e.g., 'midjj26')
  Future<String> getCurrentExamId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefExamId) ?? "default_exam";
  }

  /// Get the current master Exam Title (e.g., 'Midterm Examination - Spring 2026')
  Future<String> getCurrentExamTitle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefExamTitle) ?? "Exam Routine";
  }

  /// Fetch the list of locally saved retake exam IDs bound to the current master Exam ID
  Future<List<String>> getRetakeIds() async {
    final prefs = await SharedPreferences.getInstance();
    final currentExamId = prefs.getString(_prefExamId) ?? "default_exam";
    return prefs.getStringList('retakes_$currentExamId') ?? [];
  }

  /// Save the updated list of retake exam IDs
  Future<void> saveRetakeIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    final currentExamId = prefs.getString(_prefExamId) ?? "default_exam";
    await prefs.setStringList('retakes_$currentExamId', ids);
  }

  /// OFFLINE FIRST: Watch exams for a specific student's semester/section PLUS any added retakes.
  /// MODIFICATION: Intercepts the DB stream to dynamically inject room allocations or hide retake rooms.
  Stream<List<ExamRoutine>> watchStudentExams(int semester, String section, List<String> retakeIds) {
    return (_db.select(_db.examRoutines)
      ..where((r) {
        final isMainExam = r.semester.equals(semester) &
        (r.section.equals(section) | r.section.equals('N/A') | r.section.equals('NA'));
        final isRetake = retakeIds.isNotEmpty ? r.id.isIn(retakeIds) : const Constant(false);
        return isMainExam | isRetake;
      })
      ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.startTime)
      ])
    ).watch().asyncMap((exams) async {
      // Fetch dynamic room allocations map
      final prefs = await SharedPreferences.getInstance();
      final allocationsStr = prefs.getString(_prefRoomAllocations) ?? '{}';
      Map<String, dynamic> allocations = {};

      // BUG FIX: Safe JSON parsing to avoid TypeError if stored string is not a Map
      try {
        final decoded = json.decode(allocationsStr);
        if (decoded is Map) {
          allocations = Map<String, dynamic>.from(decoded);
        }
      } catch (e) {
        debugPrint("DEBUG: Failed to parse room allocations: $e");
      }

      // Map over the database results to apply business logic
      return exams.map((e) {
        final isRetake = retakeIds.contains(e.id);

        if (isRetake) {
          // Rule: Retakes never show room or section. Override to N/A.
          return e.copyWith(roomNumber: "N/A", section: "N/A");
        } else {
          // Rule: Match main exam with global room allocation
          final allocKey = "$semester$section"; // e.g., "1A"
          final mappedRoom = allocations[allocKey];

          if (mappedRoom != null && mappedRoom.toString().trim() != "N/A" && mappedRoom.toString().trim().isNotEmpty) {
            // Apply the specific room and reveal the true section
            return e.copyWith(roomNumber: mappedRoom.toString().trim(), section: section);
          } else {
            // Data missing/not provided yet: Mask both to hide in UI
            return e.copyWith(roomNumber: "N/A", section: "N/A");
          }
        }
      }).toList();
    });
  }

  /// OFFLINE FIRST: Watch all OTHER exams to populate the "Add Retake" selection screen
  Stream<List<ExamRoutine>> watchOtherExams(int currentSemester, String currentSection) {
    return (_db.select(_db.examRoutines)
      ..where((r) {
        final isValidSem = r.semester.isSmallerOrEqualValue(currentSemester);
        final isNotMain = (r.semester.equals(currentSemester) &
        (r.section.equals(currentSection) | r.section.equals('N/A') | r.section.equals('NA'))).not();
        return isValidSem & isNotMain;
      })
      ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.startTime)
      ])
    ).watch();
  }

  /// Check if we are currently past the exam end date (used for "Hooray no exams" UI)
  Future<bool> areExamsOver() async {
    final prefs = await SharedPreferences.getInstance();
    final endDateStr = prefs.getString(_prefExamEndDate);
    if (endDateStr == null) return true;

    final endDate = DateTime.tryParse(endDateStr);
    if (endDate == null) return true;

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    return normalizedToday.isAfter(normalizedEnd);
  }

  /// SYNC: Fetch the master exam data from Firestore and safely replace SQLite
  Future<void> syncExamRoutines() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final docSnapshot = await _firestore.collection("routines").doc("exam_routine").get();

      if (!docSnapshot.exists) {
        debugPrint("DEBUG: Exam routine document not found in Firebase.");
        return;
      }

      final docData = docSnapshot.data();
      if (docData == null || !docData.containsKey("data")) return;

      final String rawJsonString = docData["data"];

      // BUG FIX: Safe parsing for routine JSON data to prevent global sync failures
      Map<String, dynamic> data = {};
      try {
        final decoded = json.decode(rawJsonString);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        } else {
          return; // Abort sync if the structural wrapper isn't a Map
        }
      } catch (e) {
        debugPrint("DEBUG: Malformed JSON string in exam routine: $e");
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      // 1. Update Metadata
      final String? newEndDate = data['examEndDate'];
      if (newEndDate != null) await prefs.setString(_prefExamEndDate, newEndDate);

      final String? newExamId = data['examId'];
      if (newExamId != null) await prefs.setString(_prefExamId, newExamId);

      final String globalExamTitle = (data["examTitle"]?.toString() ?? "Final Examination").trim();
      await prefs.setString(_prefExamTitle, globalExamTitle);

      // MODIFICATION: Save decoupled room allocations to SharedPreferences
      if (data.containsKey("roomAllocations")) {
        await prefs.setString(_prefRoomAllocations, json.encode(data["roomAllocations"]));
      }

      if (!data.containsKey("data")) return;
      if (data["data"] is! List) return; // BUG FIX: Ensure data is an array before processing

      final List<dynamic> daysData = data["data"];
      List<ExamRoutinesCompanion> companions = [];

      final String masterExamId = newExamId ?? "default_exam";

      for (var dayEntry in daysData) {
        if (dayEntry is! Map) continue; // BUG FIX: Skip malformed day objects

        final String dateStr = dayEntry["date"]?.toString() ?? "";
        final DateTime? parsedDate = DateTime.tryParse(dateStr);
        if (parsedDate == null) continue;

        final dynamic rawExams = dayEntry["exams"];
        final List<dynamic> exams = rawExams is List ? rawExams : [];

        for (var exam in exams) {
          if (exam is! Map) continue; // BUG FIX: Skip malformed individual exams

          final int parsedSem = int.tryParse(exam["sem"]?.toString() ?? "1") ?? 1;
          final String parsedSec = (exam["sec"]?.toString() ?? "N/A").trim().toUpperCase();
          final String subject = (exam["sub"]?.toString() ?? "Unknown Subject").trim();

          // MODIFICATION: Hardcode default DB room to "N/A" since logic is handled on stream output
          final String roomNum = "N/A";

          final String startTime = (exam["startTime"]?.toString() ?? "00:00").trim();
          final String endTime = (exam["endTime"]?.toString() ?? "00:00").trim();

          final uniqueId = "${masterExamId}_${dateStr}_${parsedSem}_${parsedSec}_${subject}_$roomNum";

          companions.add(
              ExamRoutinesCompanion(
                id: Value(uniqueId),
                date: Value(parsedDate),
                subjectName: Value(subject),
                roomNumber: Value(roomNum),
                startTime: Value(startTime),
                endTime: Value(endTime),
                semester: Value(parsedSem),
                section: Value(parsedSec),
                examType: Value(globalExamTitle),
              )
          );
        }
      }

      await _db.transaction(() async {
        await _db.delete(_db.examRoutines).go();
        await _db.batch((batch) {
          batch.insertAll(_db.examRoutines, companions, mode: InsertMode.insertOrReplace);
        });
      });

      debugPrint("DEBUG: Exam Routines synced. Total exams processed: ${companions.length}");

    } catch (e) {
      debugPrint("DEBUG: Exam Routine Sync Error: $e");
    } finally {
      _isSyncing = false;
    }
  }
}