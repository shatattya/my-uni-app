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

  // Privilege Flags (NEW IN v3)
  BoolColumn get isDev => boolean().withDefault(const Constant(false))();
  BoolColumn get isCR => boolean().withDefault(const Constant(false))();

  IntColumn get avatarId => integer().withDefault(const Constant(1))();
  DateTimeColumn get lastProfileUpdate => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// 2. Schema for Announcements (Upgraded for Edit/Delete)
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

/// 3. Schema for the Routine (Timetable Feature)
class Routines extends Table {
  TextColumn get id => text()(); // Firestore Document ID
  TextColumn get subjectName => text()();
  TextColumn get teacherName => text()();
  TextColumn get roomNumber => text()();

  // 1 = Monday, 2 = Tuesday, etc. (Integers make sorting easy)
  IntColumn get dayOfWeek => integer()();

  // Stored as strings for easy display (e.g., "09:00 AM", "10:30 AM")
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();

  // Filtering variables to show the right routine to the right student
  IntColumn get semester => integer()();
  TextColumn get section => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Users, Announcements, Routines])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  // Pro Coder: Bumped to version 3 to separate identity from privileges
  @override
  int get schemaVersion => 3;

  // Safely upgrades the database for existing users incrementally
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) {
      return m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Step-by-step sequential upgrades ensure no data is lost
      // regardless of what version the user updates from.
      if (from < 2) {
        // Upgrades from v1 to v2
        await m.addColumn(announcements, announcements.authorUid);
        await m.addColumn(announcements, announcements.isDeleted);
        await m.createTable(routines);
      }
      if (from < 3) {
        // Upgrades from v2 to v3
        await m.addColumn(users, users.isDev);
        await m.addColumn(users, users.isCR);
      }
    },
  );
}

/// Tell Drift where to store the SQLite file on the device
LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'app_db.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}