import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/db_provider.dart';
import '../local/app_database.dart';

final routineRepositoryProvider = Provider<RoutineRepository>((ref) {
  return RoutineRepository(
    ref.watch(dbProvider),
    FirebaseFirestore.instance,
  );
});

class RoutineRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;

  bool _isSyncing = false;
  DateTime? _lastSync;

  static const Map<String, Map<String, String>> _timeSlots = {
    'class1': {
      'start': '09:30',
      'end': '10:20',
    },
    'class2': {
      'start': '10:25',
      'end': '11:15',
    },
    'class3': {
      'start': '11:20',
      'end': '12:10',
    },
    'class4': {
      'start': '12:15',
      'end': '13:05',
    },
    'class5': {
      'start': '13:10',
      'end': '14:00',
    },
    'class6': {
      'start': '14:05',
      'end': '14:55',
    },
  };

  static const Map<String, int> _dayMap = {
    'Monday': 1,
    'Tuesday': 2,
    'Wednesday': 3,
    'Thursday': 4,
    'Friday': 5,
    'Saturday': 6,
    'Sunday': 7,
  };

  RoutineRepository(
      this._db,
      this._firestore,
      );

  /// Clears in-memory sync metadata when the authenticated user changes.
  void resetSyncMetadata() {
    _lastSync = null;
    _isSyncing = false;
  }

  /// Watches one student's routine for one weekday.
  ///
  /// This remains a stream because the routine UI needs to react immediately
  /// when the local Drift cache changes.
  Stream<List<Routine>> watchDailyRoutines(
      int semester,
      String section,
      int weekday,
      ) {
    return (_db.select(_db.routines)
      ..where(
            (r) => r.dayOfWeek.equals(weekday),
      )
      ..where(
            (r) => r.semester.equals(semester),
      )
      ..where(
            (r) => r.section.equals(section),
      )
      ..orderBy([
            (t) => OrderingTerm(
          expression: t.startTime,
        ),
      ]))
        .watch();
  }

  /// Watches one teacher's routine for one weekday.
  ///
  /// Teacher matching prefers teacherId but retains teacher-name fallback for
  /// compatibility with older routine data.
  Stream<List<Routine>> watchTeacherDailyRoutines(
      String teacherId,
      String teacherName,
      int weekday,
      ) {
    final cleanId = teacherId.trim().toLowerCase();
    final cleanName = teacherName.trim().toLowerCase();

    return (_db.select(_db.routines)
      ..where(
            (r) => r.dayOfWeek.equals(weekday),
      )
      ..where(
            (r) {
          final Expression<bool> matchId = cleanId.isNotEmpty
              ? r.teacherId.equals(cleanId)
              : const Constant(false);

          final Expression<bool> matchName = cleanName.isNotEmpty
              ? r.teacherName.lower().equals(cleanName)
              : const Constant(false);

          return matchId | matchName;
        },
      )
      ..orderBy([
            (t) => OrderingTerm(
          expression: t.startTime,
        ),
      ]))
        .watch();
  }

  /// Performs one local SQLite query for all routines belonging to a student.
  ///
  /// This is intentionally a Future rather than a Stream because callers such
  /// as notification scheduling only need a point-in-time snapshot.
  Future<List<Routine>> getStudentRoutines(
      int semester,
      String section,
      ) {
    return (_db.select(_db.routines)
      ..where(
            (r) => r.semester.equals(semester),
      )
      ..where(
            (r) => r.section.equals(section),
      )
      ..orderBy([
            (t) => OrderingTerm(
          expression: t.dayOfWeek,
        ),
            (t) => OrderingTerm(
          expression: t.startTime,
        ),
      ]))
        .get();
  }

  /// Performs one local SQLite query for all routines belonging to a teacher.
  ///
  /// teacherId is preferred, while teacherName remains a compatibility
  /// fallback for legacy rows that may not contain a teacherId.
  Future<List<Routine>> getTeacherRoutines(
      String teacherId,
      String teacherName,
      ) {
    final cleanId = teacherId.trim().toLowerCase();
    final cleanName = teacherName.trim().toLowerCase();

    return (_db.select(_db.routines)
      ..where(
            (r) {
          final Expression<bool> matchId = cleanId.isNotEmpty
              ? r.teacherId.equals(cleanId)
              : const Constant(false);

          final Expression<bool> matchName = cleanName.isNotEmpty
              ? r.teacherName.lower().equals(cleanName)
              : const Constant(false);

          return matchId | matchName;
        },
      )
      ..orderBy([
            (t) => OrderingTerm(
          expression: t.dayOfWeek,
        ),
            (t) => OrderingTerm(
          expression: t.startTime,
        ),
      ]))
        .get();
  }

  /// Fetches master routine data from Firestore and replaces the local routine
  /// cache atomically after successful parsing.
  Future<void> syncRoutines() async {
    if (_isSyncing) {
      return;
    }

    // Keep the existing "don't repeatedly download a populated cache"
    // behavior. An empty cache is always allowed to bootstrap.
    final countQuery = _db.selectOnly(_db.routines)
      ..addColumns([
        _db.routines.id.count(),
      ]);

    final count = await countQuery
        .map(
          (row) => row.read<int>(
        _db.routines.id.count(),
      ),
    )
        .getSingle();

    if ((count ?? 0) > 0 &&
        _lastSync != null &&
        DateTime.now().difference(_lastSync!) <
            const Duration(minutes: 5)) {
      print(
        'DEBUG: Sync skipped due to active cooldown and existing data.',
      );
      return;
    }

    _isSyncing = true;

    try {
      final docSnapshot = await _firestore
          .collection('routines')
          .doc('master')
          .get();

      if (!docSnapshot.exists) {
        print(
          'DEBUG: Master routine document not found.',
        );
        return;
      }

      final data = docSnapshot.data();

      if (data == null || !data.containsKey('data')) {
        return;
      }

      final rawJson = data['data'];

      if (rawJson is! String || rawJson.trim().isEmpty) {
        throw const FormatException(
          'Routine master document contains invalid JSON data.',
        );
      }

      final dynamic decodedData = jsonDecode(rawJson);

      final List<RoutinesCompanion> companions = [];

      if (decodedData is Map<String, dynamic>) {
        final Map<String, Map<String, String>> dynamicSlots = {};

        final rawSlots = decodedData['slots'];

        if (rawSlots is Map<String, dynamic>) {
          rawSlots.forEach(
                (slotKey, timeData) {
              if (timeData is Map<String, dynamic>) {
                dynamicSlots[slotKey] = {
                  'start': timeData['startTime']?.toString() ?? '00:00',
                  'end': timeData['endTime']?.toString() ?? '00:00',
                };
              }
            },
          );
        }

        final Map<String, dynamic> semesters =
        decodedData['semesters'] is Map<String, dynamic>
            ? decodedData['semesters'] as Map<String, dynamic>
            : {};

        semesters.forEach(
              (semKey, sectionsMap) {
            final int parsedSem = int.tryParse(
              semKey,
            ) ??
                1;

            if (sectionsMap is! Map<String, dynamic>) {
              return;
            }

            sectionsMap.forEach(
                  (secKey, daysMap) {
                final String parsedSec =
                secKey.trim().toUpperCase();

                if (daysMap is! Map<String, dynamic>) {
                  return;
                }

                daysMap.forEach(
                      (dayName, classesList) {
                    final int dayOfWeek =
                        _dayMap[dayName] ?? 1;

                    if (classesList is! List) {
                      return;
                    }

                    for (final classBlock in classesList) {
                      if (classBlock is! Map<String, dynamic>) {
                        continue;
                      }

                      final String slotKey =
                          classBlock['slot']?.toString() ??
                              'class1';

                      final String startTime =
                          dynamicSlots[slotKey]?['start'] ??
                              _timeSlots[slotKey]?['start'] ??
                              '00:00';

                      final String endTime =
                          dynamicSlots[slotKey]?['end'] ??
                              _timeSlots[slotKey]?['end'] ??
                              '00:00';

                      final String subjectName =
                          classBlock['subjectName']?.toString() ??
                              'Unknown Subject';

                      final String roomNum =
                          classBlock['roomNumber']?.toString() ??
                              'TBA';

                      final String teacherId =
                      (classBlock['teacherId']?.toString() ?? '')
                          .trim()
                          .toLowerCase();

                      final String teacherName =
                      (classBlock['teacherName']?.toString() ??
                          'TBA')
                          .trim();

                      final String uniqueId =
                          '${parsedSem}_'
                          '${parsedSec}_'
                          '${dayOfWeek}_'
                          '${slotKey}_'
                          '${startTime.replaceAll(':', '')}_'
                          '${teacherId.isNotEmpty ? teacherId : teacherName}_'
                          '$roomNum';

                      companions.add(
                        RoutinesCompanion(
                          id: Value(uniqueId),
                          subjectName: Value(subjectName),
                          teacherName: Value(teacherName),
                          teacherId: Value(teacherId),
                          roomNumber: Value(roomNum),
                          dayOfWeek: Value(dayOfWeek),
                          startTime: Value(startTime),
                          endTime: Value(endTime),
                          semester: Value(parsedSem),
                          section: Value(parsedSec),
                        ),
                      );
                    }
                  },
                );
              },
            );
          },
        );
      } else if (decodedData is List) {
        // Legacy support for the previous teacher-wise routine format.
        for (final teacher in decodedData) {
          if (teacher is! Map<String, dynamic>) {
            continue;
          }

          final String teacherName =
          (teacher['teacherName']?.toString() ?? 'TBA')
              .trim();

          final String teacherId =
          (teacher['teacherId']?.toString() ?? '')
              .trim()
              .toLowerCase();

          final dynamic rawDays = teacher['days'];

          if (rawDays is! Map<String, dynamic>) {
            continue;
          }

          for (final dayEntry in rawDays.entries) {
            final int dayOfWeek =
                _dayMap[dayEntry.key] ?? 1;

            final dynamic rawClasses = dayEntry.value;

            if (rawClasses is! Map<String, dynamic>) {
              continue;
            }

            for (final classEntry in rawClasses.entries) {
              final String slotKey = classEntry.key;

              final dynamic rawDetails = classEntry.value;

              if (rawDetails is! Map<String, dynamic>) {
                continue;
              }

              final String startTime =
                  _timeSlots[slotKey]?['start'] ??
                      '00:00';

              final String endTime =
                  _timeSlots[slotKey]?['end'] ??
                      '00:00';

              final int parsedSem =
                  int.tryParse(
                    rawDetails['sem']?.toString() ??
                        '1',
                  ) ??
                      1;

              final String parsedSec =
              (rawDetails['sec']?.toString() ?? 'A')
                  .trim()
                  .toUpperCase();

              final String roomNum =
              (rawDetails['room']?.toString() ?? 'TBA')
                  .trim();

              final String uniqueId =
                  '${teacherName}_'
                  '${dayOfWeek}_'
                  '${slotKey}_'
                  '${parsedSem}_'
                  '${parsedSec}_'
                  '$roomNum';

              companions.add(
                RoutinesCompanion(
                  id: Value(uniqueId),
                  subjectName: Value(
                    rawDetails['sub']?.toString() ??
                        'Unknown Subject',
                  ),
                  teacherName: Value(teacherName),
                  teacherId: Value(teacherId),
                  roomNumber: Value(roomNum),
                  dayOfWeek: Value(dayOfWeek),
                  startTime: Value(startTime),
                  endTime: Value(endTime),
                  semester: Value(parsedSem),
                  section: Value(parsedSec),
                ),
              );
            }
          }
        }
      } else {
        throw const FormatException(
          'Unsupported routine master data format.',
        );
      }

      await _db.transaction(
            () async {
          await _db.delete(_db.routines).go();

          if (companions.isEmpty) {
            return;
          }

          await _db.batch(
                (batch) {
              batch.insertAll(
                _db.routines,
                companions,
                mode: InsertMode.insertOrReplace,
              );
            },
          );
        },
      );

      _lastSync = DateTime.now();

      print(
        'DEBUG: Routines synced. '
            'Total classes processed: ${companions.length}',
      );
    } catch (e) {
      print(
        'DEBUG: Routine Sync Error: $e',
      );

      throw Exception(
        'Failed to sync routines: $e',
      );
    } finally {
      _isSyncing = false;
    }
  }
}