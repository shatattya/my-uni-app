import 'dart:convert'; // ADDED: Required to decode the raw JSON string from Firestore
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
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
  static const String _prefExamTitle = 'currentExamTitle'; // ADDED: To display in the UI

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

  /// OFFLINE FIRST: Watch exams for a specific student's semester/section PLUS any added retakes
  Stream<List<ExamRoutine>> watchStudentExams(int semester, String section, List<String> retakeIds) {
    return (_db.select(_db.examRoutines)
      ..where((r) {
        // MODIFICATION: Handle explicit sections OR "N/A" / "NA" for universal semester exams
        final isMainExam = r.semester.equals(semester) &
        (r.section.equals(section) | r.section.equals('N/A') | r.section.equals('NA'));
        final isRetake = retakeIds.isNotEmpty ? r.id.isIn(retakeIds) : const Constant(false);
        return isMainExam | isRetake;
      })
      ..orderBy([
            (t) => OrderingTerm(expression: t.date),
            (t) => OrderingTerm(expression: t.startTime)
      ])
    ).watch();
  }

  /// OFFLINE FIRST: Watch all OTHER exams to populate the "Add Retake" selection screen
  /// MODIFICATION: Now strictly filters out future semesters (semester > currentSemester)
  Stream<List<ExamRoutine>> watchOtherExams(int currentSemester, String currentSection) {
    return (_db.select(_db.examRoutines)
      ..where((r) {
        // Guardrail: Must be less than or equal to current semester
        final isValidSem = r.semester.isSmallerOrEqualValue(currentSemester);
        // Exclude the student's main routine (including universal N/A exams for their semester)
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
    if (endDateStr == null) return true; // Default to 'over' if no data exists

    final endDate = DateTime.tryParse(endDateStr);
    if (endDate == null) return true;

    final today = DateTime.now();
    // Normalize to midnight to ensure exact day comparisons
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final normalizedEnd = DateTime(endDate.year, endDate.month, endDate.day);

    return normalizedToday.isAfter(normalizedEnd);
  }

  /// SYNC: Fetch the master exam data from Firestore and safely replace SQLite
  /// MODIFICATION: Removed smart cooldown. It now fetches unconditionally when called.
  Future<void> syncExamRoutines() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final docSnapshot = await _firestore.collection("routines").doc("exam_routine").get();

      if (!docSnapshot.exists) {
        print("DEBUG: Exam routine document not found in Firebase.");
        return;
      }

      final docData = docSnapshot.data();
      if (docData == null || !docData.containsKey("data")) return;

      // MODIFICATION: Decode the raw JSON string stored in the 'data' field
      final String rawJsonString = docData["data"];
      final Map<String, dynamic> data = json.decode(rawJsonString);

      final prefs = await SharedPreferences.getInstance();

      // 1. Update Metadata
      final String? newEndDate = data['examEndDate'];
      if (newEndDate != null) await prefs.setString(_prefExamEndDate, newEndDate);

      final String? newExamId = data['examId'];
      if (newExamId != null) await prefs.setString(_prefExamId, newExamId);

      final String globalExamTitle = (data["examTitle"]?.toString() ?? "Final Examination").trim();
      await prefs.setString(_prefExamTitle, globalExamTitle);

      if (!data.containsKey("data")) return;

      final List<dynamic> daysData = data["data"];
      List<ExamRoutinesCompanion> companions = [];

      final String masterExamId = newExamId ?? "default_exam";

      for (var dayEntry in daysData) {
        final String dateStr = dayEntry["date"] ?? "";
        final DateTime? parsedDate = DateTime.tryParse(dateStr);
        if (parsedDate == null) continue;

        final List<dynamic> exams = dayEntry["exams"] ?? [];

        for (var exam in exams) {
          final int parsedSem = int.tryParse(exam["sem"]?.toString() ?? "1") ?? 1;
          final String parsedSec = (exam["sec"]?.toString() ?? "A").trim().toUpperCase();
          final String subject = (exam["sub"]?.toString() ?? "Unknown Subject").trim();
          final String roomNum = (exam["room"]?.toString() ?? "TBA").trim();
          final String startTime = (exam["startTime"]?.toString() ?? "00:00").trim();
          final String endTime = (exam["endTime"]?.toString() ?? "00:00").trim();

          // Bind the primary key to the root examId to prevent future ghost retakes
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

      // Safe Wipe & Replace Transaction
      await _db.transaction(() async {
        await _db.delete(_db.examRoutines).go();
        await _db.batch((batch) {
          batch.insertAll(_db.examRoutines, companions, mode: InsertMode.insertOrReplace);
        });
      });

      print("DEBUG: Exam Routines synced. Total exams processed: ${companions.length}");

    } catch (e) {
      print("DEBUG: Exam Routine Sync Error: $e");
    } finally {
      _isSyncing = false;
    }
  }
}