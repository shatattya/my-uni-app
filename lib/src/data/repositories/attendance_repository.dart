import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:drift/drift.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../local/app_database.dart';
import '../models/attendance_draft.dart';
import '../../providers/db_provider.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepository(
    ref.watch(dbProvider),
    FirebaseFirestore.instance,
    FirebaseAuth.instance,
  );
});

class AttendanceRepository {
  final AppDatabase _db;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  AttendanceRepository(
      this._db,
      this._firestore,
      this._auth,
      );

  // ---------------------------------------------------------------------------
  // TEACHER CLASS DATA
  //
  // The application already stores the master routine JSON locally in Drift.
  // That remains the source of teacher -> subject -> semester -> section.
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getTeacherClasses(
      String teacherId,
      ) async {
    final cleanId = teacherId.trim().toLowerCase();

    final routines = await (_db.select(_db.routines)
      ..where((r) => r.teacherId.equals(cleanId)))
        .get();

    final uniqueClasses = <String, Map<String, dynamic>>{};

    for (final routine in routines) {
      final subjectName = routine.subjectName.trim();
      final section = routine.section.trim().toUpperCase();

      if (subjectName.isEmpty) {
        continue;
      }

      if (routine.semester < 1 || routine.semester > 8) {
        continue;
      }

      if (!{'A', 'B', 'C'}.contains(section)) {
        continue;
      }

      final key = '${subjectName}_${routine.semester}_$section';

      uniqueClasses.putIfAbsent(
        key,
            () => <String, dynamic>{
          'subjectName': subjectName,
          'semester': routine.semester,
          'section': section,
        },
      );
    }

    final result = uniqueClasses.values.toList();

    result.sort(
          (a, b) => (a['subjectName'] as String).compareTo(
        b['subjectName'] as String,
      ),
    );

    return result;
  }

  // ---------------------------------------------------------------------------
  // STUDENT ROSTER
  // ---------------------------------------------------------------------------

  Future<List<CachedStudent>> getStudents(
      int semester,
      String section,
      ) async {
    final normalizedSection = section.trim().toUpperCase();

    if (semester < 1 || semester > 8) {
      throw const AttendanceValidationException(
        'Invalid semester.',
      );
    }

    if (!{'A', 'B', 'C'}.contains(normalizedSection)) {
      throw const AttendanceValidationException(
        'Invalid section.',
      );
    }

    var localStudents = await (_db.select(_db.cachedStudents)
      ..where((s) => s.semester.equals(semester))
      ..where((s) => s.section.equals(normalizedSection))
      ..orderBy([
            (t) => OrderingTerm(
          expression: t.studentId,
        ),
      ]))
        .get();

    if (localStudents.isNotEmpty) {
      // Refresh in the background. The current local roster remains available
      // immediately, which preserves the existing offline-first behavior.
      _syncStudentsFromCloud(
        semester,
        normalizedSection,
      );

      return localStudents;
    }

    await _syncStudentsFromCloud(
      semester,
      normalizedSection,
    );

    localStudents = await (_db.select(_db.cachedStudents)
      ..where((s) => s.semester.equals(semester))
      ..where((s) => s.section.equals(normalizedSection))
      ..orderBy([
            (t) => OrderingTerm(
          expression: t.studentId,
        ),
      ]))
        .get();

    return localStudents;
  }

  Future<void> _syncStudentsFromCloud(
      int semester,
      String section,
      ) async {
    try {
      final snapshot = await _firestore
          .collection('students')
          .where(
        'semester',
        isEqualTo: semester,
      )
          .where(
        'section',
        isEqualTo: section,
      )
          .get();

      final companions = <CachedStudentsCompanion>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final rawStudentId = data['internalId'];

        final studentId = rawStudentId is String
            ? rawStudentId.trim()
            : doc.id.trim();

        if (studentId.isEmpty) {
          continue;
        }

        final rawName = data['name'];

        final name = rawName is String
            ? rawName.trim()
            : 'Unknown';

        companions.add(
          CachedStudentsCompanion(
            studentId: Value(studentId),
            name: Value(
              name.isEmpty ? 'Unknown' : name,
            ),
            semester: Value(semester),
            section: Value(section),
            isActive: const Value(true),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      if (companions.isEmpty) {
        return;
      }

      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _db.cachedStudents,
          companions,
        );
      });
    } catch (e) {
      debugPrint(
        'Attendance: failed to sync students from cloud: $e',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // AUTHORIZATION
  //
  // Teacher:
  //   authenticated email must be @bgctub.ac.bd
  //   AND teachers/{email} must exist.
  //
  // Developer/admin:
  //   admins/{uid} OR roles/{uid}.isDev == true
  //
  // This matches the application's original simple teacher model.
  // ---------------------------------------------------------------------------

  String _requireUid() {
    final uid = _auth.currentUser?.uid?.trim();

    if (uid == null || uid.isEmpty) {
      throw const AttendanceAuthorizationException(
        'You must be signed in to manage attendance.',
      );
    }

    return uid;
  }

  Future<bool> _isDeveloperOrAdmin(
      String uid,
      ) async {
    final adminSnapshot = await _firestore
        .collection('admins')
        .doc(uid)
        .get();

    if (adminSnapshot.exists) {
      return true;
    }

    final roleSnapshot = await _firestore
        .collection('roles')
        .doc(uid)
        .get();

    final data = roleSnapshot.data();

    return data?['isDev'] == true;
  }

  Future<bool> _isRegisteredTeacher(
      String email,
      ) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (!RegExp(
      r'^[^@]+@bgctub[.]ac[.]bd$',
    ).hasMatch(normalizedEmail)) {
      return false;
    }

    final teacherSnapshot = await _firestore
        .collection('teachers')
        .doc(normalizedEmail)
        .get();

    return teacherSnapshot.exists;
  }

  Future<_AttendanceAuthorization> _resolveAuthorization() async {
    final uid = _requireUid();

    if (await _isDeveloperOrAdmin(uid)) {
      return _AttendanceAuthorization(
        privileged: true,
        uid: uid,
      );
    }

    final email = _auth.currentUser?.email?.trim().toLowerCase();

    if (email == null || email.isEmpty) {
      throw const AttendanceAuthorizationException(
        'Your account does not have a valid university email address.',
      );
    }

    final isTeacher = await _isRegisteredTeacher(email);

    if (!isTeacher) {
      throw const AttendanceAuthorizationException(
        'This account is not registered as a teacher.',
      );
    }

    return _AttendanceAuthorization(
      privileged: false,
      uid: uid,
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE ATTENDANCE
  //
  // Online:
  //   validate → authorize → transaction → local synced record
  //
  // Offline:
  //   if the user was already identified locally as teacher/developer,
  //   preserve the attendance locally and let normal sync retry later.
  // ---------------------------------------------------------------------------

  Future<AttendanceSaveResult> saveAttendance({
    required String subjectName,
    required int semester,
    required String section,
    required String date,
    required List<String> presentStudentIds,
  }) async {
    final draft = AttendanceDraft.create(
      subjectName: subjectName,
      semester: semester,
      section: section,
      date: date,
      presentStudentIds: presentStudentIds,
    );

    final uid = _requireUid();

    final attendanceId = _attendanceIdFor(draft);

    final localExisting = await (_db.select(
      _db.attendanceRecords,
    )
      ..where(
            (a) => a.attendanceId.equals(attendanceId),
      ))
        .getSingleOrNull();

    await _validateStudentIds(
      semester: draft.semester,
      section: draft.section,
      presentStudentIds: draft.presentStudentIds,
    );

    _AttendanceAuthorization? authorization;

    try {
      authorization = await _resolveAuthorization();
    } on FirebaseException catch (error) {
      if (!_isTransientError(error)) {
        rethrow;
      }
    }

    // When Firebase is temporarily unavailable, allow an account that is
    // already known locally as a teacher/developer to retain offline support.
    if (authorization == null) {
      final locallyAuthorized = await _isLocallyAuthorizedUser(uid);

      if (!locallyAuthorized) {
        throw const AttendanceAuthorizationException(
          'The teacher account could not be verified. '
              'Please connect to the internet and try again.',
        );
      }

      await _saveLocalAttendance(
        draft: draft,
        existing: localExisting,
        isSynced: false,
      );

      return AttendanceSaveResult.queuedForSync;
    }

    try {
      await _writeAttendanceToCloud(
        draft: draft,
        authorization: authorization,
        localExisting: localExisting,
      );

      await _saveLocalAttendance(
        draft: draft,
        existing: localExisting,
        isSynced: true,
      );

      return AttendanceSaveResult.cloudSynced;
    } on AttendanceConflictException {
      // Refresh the local copy with the current cloud version so the next
      // screen load starts from the correct revision.
      await _refreshLocalRecordFromCloud(
        attendanceId,
      );

      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const AttendanceAuthorizationException(
          'You are not authorized to save attendance.',
        );
      }

      if (_isTransientError(error)) {
        await _saveLocalAttendance(
          draft: draft,
          existing: localExisting,
          isSynced: false,
        );

        return AttendanceSaveResult.queuedForSync;
      }

      rethrow;
    }
  }

  Future<bool> _isLocallyAuthorizedUser(
      String uid,
      ) async {
    final localUser = await (_db.select(
      _db.users,
    )
      ..where(
            (u) => u.id.equals(uid),
      ))
        .getSingleOrNull();

    if (localUser == null) {
      return false;
    }

    return localUser.role.trim().toLowerCase() ==
        'teacher' ||
        localUser.isDev;
  }

  // ---------------------------------------------------------------------------
  // STUDENT ID VALIDATION
  // ---------------------------------------------------------------------------

  Future<void> _validateStudentIds({
    required int semester,
    required String section,
    required List<String> presentStudentIds,
  }) async {
    if (presentStudentIds.isEmpty) {
      return;
    }

    final students = await getStudents(
      semester,
      section,
    );

    if (students.isEmpty) {
      throw const AttendanceValidationException(
        'The student roster is unavailable. '
            'Please load the class roster before saving attendance.',
      );
    }

    final validIds = students
        .map((student) => student.studentId.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final invalidIds = presentStudentIds
        .where((id) => !validIds.contains(id))
        .toList();

    if (invalidIds.isEmpty) {
      return;
    }

    final displayIds = invalidIds.take(5).join(', ');

    throw AttendanceValidationException(
      'The attendance contains student IDs that do not '
          'belong to this section: $displayIds',
    );
  }

  // ---------------------------------------------------------------------------
  // CLOUD WRITE
  // ---------------------------------------------------------------------------

  Future<void> _writeAttendanceToCloud({
    required AttendanceDraft draft,
    required _AttendanceAuthorization authorization,
    required AttendanceRecord? localExisting,
  }) async {
    final attendanceId = _attendanceIdFor(draft);

    final documentReference = _firestore
        .collection('attendance_records')
        .doc(attendanceId);

    try {
      await _firestore.runTransaction<void>(
            (transaction) async {
          final snapshot = await transaction.get(
            documentReference,
          );

          // ---------------------------------------------------------------
          // CREATE
          // ---------------------------------------------------------------

          if (!snapshot.exists) {
            transaction.set(
              documentReference,
              {
                'attendanceId': attendanceId,
                'subjectId': draft.subjectName,
                'semester': draft.semester,
                'section': draft.section,
                'date': draft.date,
                'presentStudentIds': draft.presentStudentIds,
                'teacherUid': authorization.uid,
                'createdByUid': authorization.uid,
                'updatedByUid': authorization.uid,
                'revision': 1,
                'createdAt': FieldValue.serverTimestamp(),
                'updatedAt': FieldValue.serverTimestamp(),
              },
            );

            return;
          }

          // ---------------------------------------------------------------
          // UPDATE
          // ---------------------------------------------------------------

          final data = snapshot.data();

          if (data == null) {
            throw const AttendanceConflictException(
              'The attendance record could not be read. '
                  'Please try again.',
            );
          }

          final cloudUpdatedAt = _readCloudDateTime(
            data['updatedAt'],
            fallback: DateTime.fromMillisecondsSinceEpoch(0),
          );

          // A local record exists and cloud is newer.
          // This means another device/client changed the record after our
          // local copy was obtained.
          if (localExisting != null &&
              cloudUpdatedAt.isAfter(
                localExisting.updatedAt,
              )) {
            throw const AttendanceConflictException(
              'This attendance record was changed on another device. '
                  'The newer cloud version has been kept. '
                  'Please reload it before making further changes.',
            );
          }

          final existingCreatedAt = data['createdAt'];

          final existingCreatedBy =
          data['createdByUid'] is String
              ? (data['createdByUid'] as String).trim()
              : '';

          final existingTeacherUid =
          data['teacherUid'] is String
              ? (data['teacherUid'] as String).trim()
              : '';

          final existingRevision =
          data['revision'] is int
              ? data['revision'] as int
              : 0;

          final createdByUid = existingCreatedBy.isNotEmpty
              ? existingCreatedBy
              : authorization.uid;

          final teacherUid = existingTeacherUid.isNotEmpty
              ? existingTeacherUid
              : authorization.uid;

          final nextRevision = existingRevision + 1;

          transaction.update(
            documentReference,
            {
              'attendanceId': attendanceId,
              'subjectId': draft.subjectName,
              'semester': draft.semester,
              'section': draft.section,
              'date': draft.date,
              'presentStudentIds': draft.presentStudentIds,
              'teacherUid': teacherUid,
              'createdByUid': createdByUid,
              'updatedByUid': authorization.uid,
              'revision': nextRevision,
              'createdAt': existingCreatedAt,
              'updatedAt': FieldValue.serverTimestamp(),
            },
          );
        },
      );
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        throw const AttendanceAuthorizationException(
          'You are not authorized to save attendance.',
        );
      }

      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // LOCAL SAVE
  // ---------------------------------------------------------------------------

  Future<void> _saveLocalAttendance({
    required AttendanceDraft draft,
    required AttendanceRecord? existing,
    required bool isSynced,
  }) async {
    final now = DateTime.now();
    final attendanceId = _attendanceIdFor(draft);

    await _db.into(_db.attendanceRecords).insertOnConflictUpdate(
      AttendanceRecordsCompanion(
        attendanceId: Value(attendanceId),
        subjectId: Value(draft.subjectName),
        semester: Value(draft.semester),
        section: Value(draft.section),
        date: Value(draft.date),
        presentStudentIds: Value(
          jsonEncode(draft.presentStudentIds),
        ),
        isSynced: Value(isSynced),
        createdAt: Value(
          existing?.createdAt ?? now,
        ),
        updatedAt: Value(now),
      ),
    );
  }

  String _attendanceIdFor(
      AttendanceDraft draft,
      ) {
    final cleanSubject = draft.subjectName
        .replaceAll(
      RegExp(r'[^A-Za-z0-9_-]+'),
      '_',
    )
        .replaceAll(
      RegExp(r'_+'),
      '_',
    )
        .replaceAll(
      RegExp(r'^_+|_+$'),
      '',
    );

    final safeSubject =
    cleanSubject.isEmpty ? 'subject' : cleanSubject;

    return '${safeSubject}_${draft.semester}_'
        '${draft.section}_${draft.date}';
  }

  // ---------------------------------------------------------------------------
  // CLOUD → LOCAL CACHE
  // ---------------------------------------------------------------------------

  Future<void> _refreshLocalRecordFromCloud(
      String attendanceId,
      ) async {
    try {
      final snapshot = await _firestore
          .collection('attendance_records')
          .doc(attendanceId)
          .get();

      if (!snapshot.exists) {
        return;
      }

      final data = snapshot.data();

      if (data == null) {
        return;
      }

      await _cacheCloudRecord(
        attendanceId: attendanceId,
        data: data,
      );
    } catch (e) {
      debugPrint(
        'Attendance: failed to refresh conflicting record: $e',
      );
    }
  }

  Future<void> _cacheCloudRecord({
    required String attendanceId,
    required Map<String, dynamic> data,
  }) async {
    final subjectId = data['subjectId'] is String
        ? (data['subjectId'] as String).trim()
        : '';

    final semester = data['semester'] is int
        ? data['semester'] as int
        : 0;

    final section = data['section'] is String
        ? (data['section'] as String)
        .trim()
        .toUpperCase()
        : '';

    final date = data['date'] is String
        ? (data['date'] as String).trim()
        : '';

    if (subjectId.isEmpty ||
        semester < 1 ||
        semester > 8 ||
        !{'A', 'B', 'C'}.contains(section) ||
        date.isEmpty) {
      return;
    }

    final presentIds = _decodePresentStudentIds(
      data['presentStudentIds'],
    );

    final updatedAt = _readCloudDateTime(
      data['updatedAt'],
      fallback: DateTime.now(),
    );

    final createdAt = _readCloudDateTime(
      data['createdAt'],
      fallback: updatedAt,
    );

    await _db.into(_db.attendanceRecords).insertOnConflictUpdate(
      AttendanceRecordsCompanion(
        attendanceId: Value(attendanceId),
        subjectId: Value(subjectId),
        semester: Value(semester),
        section: Value(section),
        date: Value(date),
        presentStudentIds: Value(
          jsonEncode(presentIds),
        ),
        isSynced: const Value(true),
        createdAt: Value(createdAt),
        updatedAt: Value(updatedAt),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CSV REPORT
  // ---------------------------------------------------------------------------

  Future<String> generateCsvReport({
    required String subjectName,
    required int semester,
    required String section,
    required DateTime startDate,
    required DateTime endDate,
    required double maxMarks,
    required String mode,
  }) async {
    final normalizedSubject = subjectName.trim();
    final normalizedSection = section.trim().toUpperCase();

    final startStr = DateFormat(
      'yyyy-MM-dd',
    ).format(startDate);

    final endStr = DateFormat(
      'yyyy-MM-dd',
    ).format(endDate);

    final records = await (_db.select(
      _db.attendanceRecords,
    )
      ..where(
            (a) => a.subjectId.equals(
          normalizedSubject,
        ),
      )
      ..where(
            (a) => a.semester.equals(
          semester,
        ),
      )
      ..where(
            (a) => a.section.equals(
          normalizedSection,
        ),
      )
      ..where(
            (a) => a.date.isBetweenValues(
          startStr,
          endStr,
        ),
      ))
        .get();

    final students = await getStudents(
      semester,
      normalizedSection,
    );

    final studentCount = <String, int>{
      for (final student in students)
        student.studentId: 0,
    };

    for (final record in records) {
      final presentIds =
      _decodePresentStudentIdsFromJson(
        record.presentStudentIds,
        record.attendanceId,
      );

      for (final studentId in presentIds) {
        if (!studentCount.containsKey(studentId)) {
          continue;
        }

        studentCount[studentId] =
            (studentCount[studentId] ?? 0) + 1;
      }
    }

    final totalClasses = records.length;

    final buffer = StringBuffer();

    buffer.writeln(
      'StudentId,StudentName,TotalClasses,'
          'PresentCount,Percentage,MarksAwarded',
    );

    for (final student in students) {
      final present =
          studentCount[student.studentId] ?? 0;

      final percentage = totalClasses == 0
          ? 0.0
          : (present / totalClasses) * 100.0;

      double marks = 0.0;

      if (mode == 'Linear') {
        marks = (percentage / 100.0) * maxMarks;
      } else if (mode == 'Bucketed') {
        if (percentage >= 90) {
          marks = maxMarks;
        } else if (percentage >= 75) {
          marks = maxMarks * 0.8;
        } else if (percentage >= 60) {
          marks = maxMarks * 0.6;
        }
      }

      buffer.writeln(
        '${_csvEscape(student.studentId)},'
            '${_csvEscape(student.name)},'
            '$totalClasses,'
            '$present,'
            '${percentage.toStringAsFixed(2)},'
            '${marks.toStringAsFixed(2)}',
      );
    }

    final directory = await getTemporaryDirectory();

    final safeSubject = normalizedSubject
        .replaceAll(
      RegExp(r'[^A-Za-z0-9_-]+'),
      '_',
    );

    final fileName =
        'Attendance_${safeSubject}_${semester}_'
        '${normalizedSection}.csv';

    final file = File(
      '${directory.path}/$fileName',
    );

    await file.writeAsString(
      buffer.toString(),
    );

    return file.path;
  }

  String _csvEscape(
      String value,
      ) {
    var safeValue = value;

    // Protect spreadsheet users from formula injection.
    if (safeValue.startsWith('=') ||
        safeValue.startsWith('+') ||
        safeValue.startsWith('-') ||
        safeValue.startsWith('@')) {
      safeValue = "'$safeValue";
    }

    if (safeValue.contains(',') ||
        safeValue.contains('"') ||
        safeValue.contains('\n') ||
        safeValue.contains('\r')) {
      return '"${safeValue.replaceAll('"', '""')}"';
    }

    return safeValue;
  }

  // ---------------------------------------------------------------------------
  // HISTORY
  // ---------------------------------------------------------------------------

  Future<List<AttendanceRecord>> getRecentAttendance({
    int limit = 25,
    int offset = 0,
  }) async {
    final safeLimit = limit < 1
        ? 1
        : limit > 100
        ? 100
        : limit;

    final safeOffset = offset < 0 ? 0 : offset;

    return (_db.select(
      _db.attendanceRecords,
    )
      ..orderBy([
            (t) => OrderingTerm(
          expression: t.date,
          mode: OrderingMode.desc,
        ),
      ])
      ..limit(
        safeLimit,
        offset: safeOffset,
      ))
        .get();
  }

  // ---------------------------------------------------------------------------
  // PENDING SYNC COUNT
  // ---------------------------------------------------------------------------

  Future<int> getPendingSyncCount() async {
    final records = await (_db.select(
      _db.attendanceRecords,
    )..where(
          (a) => a.isSynced.equals(false),
    ))
        .get();

    return records.length;
  }

  // ---------------------------------------------------------------------------
  // TWO-WAY SYNC
  //
  // Upload pending local records first.
  // Then download newer cloud records for the teacher's classes.
  //
  // Teacher class discovery remains based on the routines/master JSON that
  // already powers AttendanceSetupScreen.
  // ---------------------------------------------------------------------------

  Future<bool> syncPendingRecords(
      String teacherId,
      ) async {
    var hasUpdates = false;

    final pendingRecords = await (_db.select(
      _db.attendanceRecords,
    )..where(
          (a) => a.isSynced.equals(false),
    ))
        .get();

    // -----------------------------------------------------------------------
    // PART 1: UPLOAD PENDING LOCAL RECORDS
    // -----------------------------------------------------------------------

    for (final record in pendingRecords) {
      try {
        final draft = AttendanceDraft.create(
          subjectName: record.subjectId,
          semester: record.semester,
          section: record.section,
          date: record.date,
          presentStudentIds:
          _decodePresentStudentIdsFromJson(
            record.presentStudentIds,
            record.attendanceId,
          ),
        );

        final authorization =
        await _resolveAuthorization();

        await _writeAttendanceToCloud(
          draft: draft,
          authorization: authorization,
          localExisting: record,
        );

        await (_db.update(
          _db.attendanceRecords,
        )
          ..where(
                (a) => a.attendanceId.equals(
              record.attendanceId,
            ),
          ))
            .write(
          const AttendanceRecordsCompanion(
            isSynced: Value(true),
          ),
        );

        hasUpdates = true;
      } on AttendanceConflictException {
        // Do not overwrite a newer cloud revision.
        // Refresh the local record and leave it synced against the cloud copy.
        await _refreshLocalRecordFromCloud(
          record.attendanceId,
        );

        rethrow;
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          throw const AttendanceAuthorizationException(
            'A pending attendance record is no longer '
                'authorized for this account.',
          );
        }

        if (_isTransientError(error)) {
          // Stop here and let the next synchronization attempt retry.
          return hasUpdates;
        }

        rethrow;
      }
    }

    // -----------------------------------------------------------------------
    // PART 2: DOWNLOAD CLOUD RECORDS
    // -----------------------------------------------------------------------

    final classes = await getTeacherClasses(
      teacherId,
    );

    if (classes.isEmpty) {
      return hasUpdates;
    }

    final existingLocalRecords =
    await _db.select(
      _db.attendanceRecords,
    ).get();

    final localRecordMap =
    <String, AttendanceRecord>{
      for (final record in existingLocalRecords)
        record.attendanceId: record,
    };

    final cloudCompanions =
    <AttendanceRecordsCompanion>[];

    for (final classInfo in classes) {
      final subjectName =
      classInfo['subjectName'] as String;

      final semester =
      classInfo['semester'] as int;

      final section =
      (classInfo['section'] as String)
          .trim()
          .toUpperCase();

      try {
        final snapshot = await _firestore
            .collection('attendance_records')
            .where(
          'subjectId',
          isEqualTo: subjectName,
        )
            .where(
          'semester',
          isEqualTo: semester,
        )
            .where(
          'section',
          isEqualTo: section,
        )
            .get();

        for (final doc in snapshot.docs) {
          final data = doc.data();

          final cloudId = doc.id;

          final storedAttendanceId =
          data['attendanceId'];

          // Protect against malformed/mis-keyed cloud documents.
          if (storedAttendanceId is String &&
              storedAttendanceId != cloudId) {
            debugPrint(
              'Attendance: skipping malformed record '
                  '$cloudId because attendanceId does not match '
                  'the document ID.',
            );
            continue;
          }

          final cloudUpdatedAt =
          _readCloudDateTime(
            data['updatedAt'],
            fallback:
            DateTime.fromMillisecondsSinceEpoch(0),
          );

          final localRecord =
          localRecordMap[cloudId];

          if (localRecord != null) {
            // Never replace an unsynced local edit merely because the cloud
            // copy is newer.
            if (!localRecord.isSynced) {
              continue;
            }

            if (!cloudUpdatedAt.isAfter(
              localRecord.updatedAt,
            )) {
              continue;
            }
          }

          final presentIds =
          _decodePresentStudentIds(
            data['presentStudentIds'],
          );

          final createdAt =
          _readCloudDateTime(
            data['createdAt'],
            fallback: cloudUpdatedAt,
          );

          final subjectId =
          data['subjectId'] is String
              ? (data['subjectId'] as String).trim()
              : subjectName;

          final cloudSemester =
          data['semester'] is int
              ? data['semester'] as int
              : semester;

          final cloudSection =
          data['section'] is String
              ? (data['section'] as String)
              .trim()
              .toUpperCase()
              : section;

          final cloudDate =
          data['date'] is String
              ? (data['date'] as String).trim()
              : '';

          if (subjectId.isEmpty ||
              cloudDate.isEmpty ||
              cloudSemester < 1 ||
              cloudSemester > 8 ||
              !{'A', 'B', 'C'}
                  .contains(cloudSection)) {
            continue;
          }

          cloudCompanions.add(
            AttendanceRecordsCompanion(
              attendanceId: Value(cloudId),
              subjectId: Value(subjectId),
              semester: Value(cloudSemester),
              section: Value(cloudSection),
              date: Value(cloudDate),
              presentStudentIds: Value(
                jsonEncode(presentIds),
              ),
              isSynced: const Value(true),
              createdAt: Value(createdAt),
              updatedAt: Value(cloudUpdatedAt),
            ),
          );

          hasUpdates = true;
        }
      } on FirebaseException catch (error) {
        if (error.code == 'permission-denied') {
          throw const AttendanceAuthorizationException(
            'You are not authorized to read attendance data.',
          );
        }

        if (_isTransientError(error)) {
          return hasUpdates;
        }

        rethrow;
      }
    }

    if (cloudCompanions.isNotEmpty) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _db.attendanceRecords,
          cloudCompanions,
        );
      });
    }

    return hasUpdates;
  }

  // ---------------------------------------------------------------------------
  // SAFE JSON / CLOUD DATA PARSING
  // ---------------------------------------------------------------------------

  List<String> _decodePresentStudentIds(
      dynamic value,
      ) {
    if (value is List) {
      final ids = value
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      ids.sort();

      return ids;
    }

    if (value is String) {
      return _decodePresentStudentIdsFromJson(
        value,
        'cloud-record',
      );
    }

    return <String>[];
  }

  List<String> _decodePresentStudentIdsFromJson(
      String json,
      String attendanceId,
      ) {
    try {
      final decoded = jsonDecode(json);

      if (decoded is! List) {
        debugPrint(
          'Attendance: presentStudentIds is not a list '
              'for $attendanceId.',
        );

        return <String>[];
      }

      final ids = decoded
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      ids.sort();

      return ids;
    } catch (error) {
      debugPrint(
        'Attendance: malformed presentStudentIds '
            'for $attendanceId: $error',
      );

      return <String>[];
    }
  }

  DateTime _readCloudDateTime(
      dynamic value, {
        required DateTime fallback,
      }) {
    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      final parsed = DateTime.tryParse(value);

      if (parsed != null) {
        return parsed;
      }
    }

    return fallback;
  }

  bool _isTransientError(
      Object error,
      ) {
    if (error is! FirebaseException) {
      return false;
    }

    return error.code == 'unavailable' ||
        error.code == 'deadline-exceeded' ||
        error.code == 'network-request-failed' ||
        error.code == 'cancelled';
  }
}

// -----------------------------------------------------------------------------
// Internal authorization object
// -----------------------------------------------------------------------------

class _AttendanceAuthorization {
  final bool privileged;
  final String uid;

  const _AttendanceAuthorization({
    required this.privileged,
    required this.uid,
  });
}