import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

// This generated file will be created in the next step
part 'app_database.g.dart';

/// 1. Schema for the User
class Users extends Table {
  TextColumn get id => text()(); // Firebase UID
  TextColumn get name => text()();
  TextColumn get internalId => text()();
  IntColumn get semester => integer()();
  TextColumn get section => text()();

  // Identity Role (e.g., 'student' or 'teacher')
  TextColumn get role => text().withDefault(const Constant('student'))();

  // Privilege Flags
  BoolColumn get isDev => boolean().withDefault(const Constant(false))();
  BoolColumn get isCR => boolean().withDefault(const Constant(false))();

  IntColumn get avatarId => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastProfileUpdate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 2. Schema for Announcements
class Announcements extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  TextColumn get authorName => text()();

  // COLUMNS FOR DELETION & EDITING
  TextColumn get authorUid => text().withDefault(const Constant(''))();
  BoolColumn get isDeleted => boolean().withDefault(const Constant(false))();

  TextColumn get targetSemesters => text()(); // JSON list like "[1, 2]"
  TextColumn get targetSections => text()();   // JSON list like '["A", "B"]'
  BoolColumn get isGlobal => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 3. Schema for the Routine
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

@DriftDatabase(tables: [Users, Announcements, Routines])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) {
      return m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        await m.addColumn(announcements, announcements.authorUid);
        await m.addColumn(announcements, announcements.isDeleted);
        await m.createTable(routines);
      }
      if (from < 3) {
        await m.addColumn(users, users.isDev);
        await m.addColumn(users, users.isCR);
      }
      if (from < 4) {
        await m.addColumn(routines, routines.teacherId);
      }
    },
  );

  // MODIFICATION: Added a safe, atomic transaction to wipe all local tables on logout.
  // This prevents the next logged-in user from seeing ghost data.
  Future<void> clearAllData() async {
    await transaction(() async {
      await delete(users).go();
      await delete(announcements).go();
      await delete(routines).go();
    });
  }
}

/// Tell Drift where to store the SQLite file on the device
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}