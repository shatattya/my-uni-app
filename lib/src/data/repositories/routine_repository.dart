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

  RoutineRepository(this._db, this._firestore);

  /// OFFLINE FIRST: Watch the local SQLite routine table for students
  Stream<List<Routine>> watchDailyRoutines(int semester, String section, int weekday) {
    return (_db.select(_db.routines)
      ..where((r) => r.dayOfWeek.equals(weekday))
      ..where((r) => r.semester.equals(semester))
      ..where((r) => r.section.equals(section))
      ..orderBy([(t) => OrderingTerm(expression: t.startTime)]) // Chronological order
    ).watch();
  }

  /// OFFLINE FIRST: Watch the local SQLite routine table for teachers
  Stream<List<Routine>> watchTeacherDailyRoutines(String teacherName, int weekday) {
    return (_db.select(_db.routines)
      ..where((r) => r.dayOfWeek.equals(weekday))
      ..where((r) => r.teacherName.equals(teacherName))
      ..orderBy([(t) => OrderingTerm(expression: t.startTime)]) // Chronological order
    ).watch();
  }

  /// SYNC: Fetch the master data from Firestore and safely wipe/replace SQLite
  Future<void> syncRoutines() async {
    try {
      // 1. Fetch from Firestore FIRST.
      // If there is no internet, it throws an error here and aborts before wiping the local DB.
      final snapshot = await _firestore.collection("routines").get();

      List<RoutinesCompanion> companions = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        companions.add(
            RoutinesCompanion(
              id: Value(doc.id),
              subjectName: Value(data["subjectName"] ?? "Unknown Subject"),
              teacherName: Value(data["teacherName"] ?? "TBA"),
              roomNumber: Value(data["roomNumber"] ?? "TBA"),
              dayOfWeek: Value(data["dayOfWeek"] ?? 1),
              startTime: Value(data["startTime"] ?? "00:00"),
              endTime: Value(data["endTime"] ?? "00:00"),
              semester: Value(data["semester"] ?? 1),
              section: Value(data["section"] ?? "A"),
            )
        );
      }

      // 2. ATOMIC TRANSACTION: Wipe and Replace
      // Ensures the DB is never left in a broken/empty state if an error occurs mid-write.
      await _db.transaction(() async {
        // A. Annihilate the old local data
        await _db.delete(_db.routines).go();

        // B. Insert the fresh data
        await _db.batch((batch) {
          // We use insertAll (no conflict update needed since table is now empty)
          batch.insertAll(_db.routines, companions);
        });
      });

      print("DEBUG: Routines synced and local DB cleaned successfully.");

    } catch (e) {
      print("DEBUG: Routine Sync Error: $e");
      // Re-throw so the SyncController can catch it and show the red SnackBar
      throw Exception("Failed to sync routines: $e");
    }
  }
}