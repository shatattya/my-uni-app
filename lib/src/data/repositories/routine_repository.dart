import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../local/app_database.dart';
import '../../providers/db_provider.dart';

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepository(ref.watch(dbProvider), FirebaseFirestore.instance);
});

class RoutineRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  bool _isSyncing = false;
  DateTime? _lastSync;

  static const Map<String, Map<String, String>> _timeSlots = {
    "class1": {"start": "09:30", "end": "10:20"},
    "class2": {"start": "10:25", "end": "11:15"},
    "class3": {"start": "11:20", "end": "12:10"},
    "class4": {"start": "12:15", "end": "13:05"},
    "class5": {"start": "13:10", "end": "14:00"},
    "class6": {"start": "14:05", "end": "14:55"},
  };

  static const Map<String, int> _dayMap = {
    "Monday": 1, "Tuesday": 2, "Wednesday": 3,
    "Thursday": 4, "Friday": 5, "Saturday": 6, "Sunday": 7,
  };

  RoutineRepository(this._db, this._firestore);

  /// Clears sync metadata on logout to allow the next user to sync immediately
  void resetSyncMetadata() {
    _lastSync = null;
    _isSyncing = false;
  }

  /// OFFLINE FIRST: Watch the local SQLite routine table for students
  Stream<List<Routine>> watchDailyRoutines(int semester, String section, int weekday) {
    return (_db.select(_db.routines)
      ..where((r) => r.dayOfWeek.equals(weekday))
      ..where((r) => r.semester.equals(semester))
      ..where((r) => r.section.equals(section))
      ..orderBy([(t) => OrderingTerm(expression: t.startTime)])
    ).watch();
  }

  /// OFFLINE FIRST: Indestructible Hybrid Query for Teachers
  Stream<List<Routine>> watchTeacherDailyRoutines(String teacherId, String teacherName, int weekday) {
    final cleanId = teacherId.trim().toLowerCase();
    final cleanName = teacherName.trim().toLowerCase();

    return (_db.select(_db.routines)
      ..where((r) => r.dayOfWeek.equals(weekday))
      ..where((r) {
        Expression<bool> matchId = cleanId.isNotEmpty
            ? r.teacherId.equals(cleanId)
            : const Constant(false);

        Expression<bool> matchName = cleanName.isNotEmpty
            ? r.teacherName.lower().equals(cleanName)
            : const Constant(false);

        return matchId | matchName;
      })
      ..orderBy([(t) => OrderingTerm(expression: t.startTime)])
    ).watch();
  }

  /// SYNC: Fetch the master data from Firestore and safely wipe/replace SQLite
  Future<void> syncRoutines() async {
    if (_isSyncing) return;

    // Check local database count to bypass cooldown if empty
    final countQuery = _db.selectOnly(_db.routines)..addColumns([_db.routines.id.count()]);
    final count = await countQuery.map((row) => row.read<int>(_db.routines.id.count())).getSingle();

    // BUG FIX: Handle nullable count to avoid 'null' receiver error on operator '>'
    if ((count ?? 0) > 0 && _lastSync != null && DateTime.now().difference(_lastSync!) < const Duration(minutes: 5)) {
      print("DEBUG: Sync skipped due to active cooldown and existing data.");
      return;
    }

    _isSyncing = true;

    try {
      final docSnapshot = await _firestore.collection("routines").doc("master").get();

      if (!docSnapshot.exists) {
        print("DEBUG: Master routine document not found.");
        return;
      }

      final data = docSnapshot.data();
      if (data == null || !data.containsKey("data")) return;

      final String jsonString = data["data"];
      final List<dynamic> teachersData = jsonDecode(jsonString);

      List<RoutinesCompanion> companions = [];

      for (var teacher in teachersData) {
        final String teacherName = (teacher["teacherName"]?.toString() ?? "TBA").trim();
        final String teacherId = (teacher["teacherId"]?.toString() ?? "").trim().toLowerCase();
        final Map<String, dynamic> days = teacher["days"] ?? {};

        for (var dayEntry in days.entries) {
          final int dayOfWeek = _dayMap[dayEntry.key] ?? 1;
          final Map<String, dynamic> classes = dayEntry.value;

          for (var classEntry in classes.entries) {
            final String slotKey = classEntry.key;
            final Map<String, dynamic> details = classEntry.value;

            final startTime = _timeSlots[slotKey]?["start"] ?? "00:00";
            final endTime = _timeSlots[slotKey]?["end"] ?? "00:00";

            final int parsedSem = int.tryParse(details["sem"]?.toString() ?? "1") ?? 1;
            final String parsedSec = (details["sec"]?.toString() ?? "A").trim().toUpperCase();
            final String roomNum = (details["room"]?.toString() ?? "TBA").trim();

            final uniqueId = "${teacherName}_${dayOfWeek}_${slotKey}_${parsedSem}_${parsedSec}_$roomNum";

            companions.add(
                RoutinesCompanion(
                  id: Value(uniqueId),
                  subjectName: Value(details["sub"] ?? "Unknown Subject"),
                  teacherName: Value(teacherName),
                  teacherId: Value(teacherId),
                  roomNumber: Value(roomNum),
                  dayOfWeek: Value(dayOfWeek),
                  startTime: Value(startTime),
                  endTime: Value(endTime),
                  semester: Value(parsedSem),
                  section: Value(parsedSec),
                )
            );
          }
        }
      }

      await _db.transaction(() async {
        await _db.delete(_db.routines).go();

        await _db.batch((batch) {
          batch.insertAll(_db.routines, companions, mode: InsertMode.insertOrReplace);
        });
      });

      _lastSync = DateTime.now();
      print("DEBUG: Routines synced. Total classes processed: ${companions.length}");

    } catch (e) {
      print("DEBUG: Routine Sync Error: $e");
      throw Exception("Failed to sync routines: $e");
    } finally {
      _isSyncing = false;
    }
  }
}