import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

part 'app_database.g.dart';

class Users extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get internalId => text()();
  IntColumn get semester => integer()();
  TextColumn get section => text()();
  TextColumn get role => text().withDefault(const Constant('student'))();
  BoolColumn get isDev => boolean().withDefault(const Constant(false))();
  BoolColumn get isCR => boolean().withDefault(const Constant(false))();
  IntColumn get avatarId => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastProfileUpdate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Announcements extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get authorName => text()();
  TextColumn get authorUid => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();
  TextColumn get targetSemesters => text()();
  TextColumn get targetSections => text()();
  BoolColumn get isGlobal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Routines extends Table {
  TextColumn get id => text()();
  TextColumn get subjectName => text()();
  TextColumn get teacherName => text()();
  TextColumn get teacherId => text().withDefault(const Constant(''))();
  TextColumn get roomNumber => text()();
  IntColumn get dayOfWeek => integer()();
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  IntColumn get semester => integer()();
  TextColumn get section => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExamRoutines extends Table {
  TextColumn get id => text()();
  DateTimeColumn get date => dateTime()();
  TextColumn get subjectName => text()();
  TextColumn get roomNumber => text()();
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  IntColumn get semester => integer()();
  TextColumn get section => text()();
  TextColumn get examType => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class CachedStudents extends Table {
  TextColumn get studentId => text()();
  TextColumn get name => text()();
  IntColumn get semester => integer()();
  TextColumn get section => text()();
  DateTimeColumn get updatedAt => dateTime().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {studentId};
}

class AttendanceRecords extends Table {
  TextColumn get attendanceId => text()();
  TextColumn get subjectId => text()();
  IntColumn get semester => integer()();
  TextColumn get section => text()();
  TextColumn get date => text()();
  TextColumn get presentStudentIds => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {attendanceId};
}

class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get author => text()();
  TextColumn get coverUrl => text()();
  TextColumn get downloadUrl => text()();
  IntColumn get semester => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class Notes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get subjectName => text()();
  TextColumn get authorName => text()();
  TextColumn get fileUrl => text()();
  IntColumn get semester => integer()();
  TextColumn get section => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ADDED: Generic polymorphic table for live event schedules (World Cup, Cricket, Festivals)
class LiveEvents extends Table {
  TextColumn get id => text()();
  TextColumn get groupLabel => text().withDefault(const Constant(''))(); // e.g., "Group A"
  TextColumn get heading => text()(); // e.g., "Group Stage" or "Day 1"
  TextColumn get titlePrimary => text()(); // e.g., "Mexico" or "Opening Ceremony"
  TextColumn get titleSecondary => text().withDefault(const Constant(''))(); // e.g., "USA"
  TextColumn get subtitle => text().withDefault(const Constant(''))(); // e.g., "Estadio Azteca" or "Main Hall"
  TextColumn get utcTime => text()(); // Stored in UTC to parse locally to user's timezone

  @override
  Set<Column> get primaryKey => {id};
}

// MODIFICATION: Added LiveEvents to the tables list
@DriftDatabase(tables: [Users, Announcements, Routines, ExamRoutines, CachedStudents, AttendanceRecords, Books, Notes, LiveEvents])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // MODIFICATION: Bumped schema version to 9
  @override
  int get schemaVersion => 9;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) {
      return m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // MODIFICATION: Wrapped all schema additions in try-catch blocks to safely
      // ignore duplicate column/table errors caused by inconsistent dev states.
      if (from < 2) {
        try { await m.addColumn(announcements, announcements.authorUid); } catch (_) {}
        try { await m.addColumn(announcements, announcements.isDeleted); } catch (_) {}
        try { await m.createTable(routines); } catch (_) {}
      }
      if (from < 3) {
        try { await m.addColumn(users, users.isDev); } catch (_) {}
        try { await m.addColumn(users, users.isCR); } catch (_) {}
      }
      if (from < 4) {
        try { await m.addColumn(routines, routines.teacherId); } catch (_) {}
      }
      if (from < 5) {
        try { await m.createTable(cachedStudents); } catch (_) {}
        try { await m.createTable(attendanceRecords); } catch (_) {}
      }
      if (from < 6) {
        try { await m.addColumn(attendanceRecords, attendanceRecords.isSynced); } catch (_) {}
      }
      if (from < 7) {
        try { await m.createTable(examRoutines); } catch (_) {}
      }
      if (from < 8) {
        try { await m.createTable(books); } catch (_) {}
        try { await m.createTable(notes); } catch (_) {}
      }
      // MODIFICATION: Migration for schema 9 to create LiveEvents table
      if (from < 9) {
        try { await m.createTable(liveEvents); } catch (_) {}
      }
    },
  );

  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(users).go();
      await delete(announcements).go();
      await delete(routines).go();
      await delete(examRoutines).go();
      await delete(cachedStudents).go();
      await delete(attendanceRecords).go();
      await delete(books).go();
      await delete(notes).go();
      await delete(liveEvents).go(); // MODIFICATION: Clear live events on logout
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}