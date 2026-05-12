// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _internalIdMeta =
      const VerificationMeta('internalId');
  @override
  late final GeneratedColumn<String> internalId = GeneratedColumn<String>(
      'internal_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _semesterMeta =
      const VerificationMeta('semester');
  @override
  late final GeneratedColumn<int> semester = GeneratedColumn<int>(
      'semester', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sectionMeta =
      const VerificationMeta('section');
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
      'section', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('student'));
  static const VerificationMeta _isDevMeta = const VerificationMeta('isDev');
  @override
  late final GeneratedColumn<bool> isDev = GeneratedColumn<bool>(
      'is_dev', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_dev" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isCRMeta = const VerificationMeta('isCR');
  @override
  late final GeneratedColumn<bool> isCR = GeneratedColumn<bool>(
      'is_c_r', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_c_r" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _avatarIdMeta =
      const VerificationMeta('avatarId');
  @override
  late final GeneratedColumn<int> avatarId = GeneratedColumn<int>(
      'avatar_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _lastProfileUpdateMeta =
      const VerificationMeta('lastProfileUpdate');
  @override
  late final GeneratedColumn<DateTime> lastProfileUpdate =
      GeneratedColumn<DateTime>('last_profile_update', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        internalId,
        semester,
        section,
        role,
        isDev,
        isCR,
        avatarId,
        lastProfileUpdate
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'users';
  @override
  VerificationContext validateIntegrity(Insertable<User> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('internal_id')) {
      context.handle(
          _internalIdMeta,
          internalId.isAcceptableOrUnknown(
              data['internal_id']!, _internalIdMeta));
    } else if (isInserting) {
      context.missing(_internalIdMeta);
    }
    if (data.containsKey('semester')) {
      context.handle(_semesterMeta,
          semester.isAcceptableOrUnknown(data['semester']!, _semesterMeta));
    } else if (isInserting) {
      context.missing(_semesterMeta);
    }
    if (data.containsKey('section')) {
      context.handle(_sectionMeta,
          section.isAcceptableOrUnknown(data['section']!, _sectionMeta));
    } else if (isInserting) {
      context.missing(_sectionMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    }
    if (data.containsKey('is_dev')) {
      context.handle(
          _isDevMeta, isDev.isAcceptableOrUnknown(data['is_dev']!, _isDevMeta));
    }
    if (data.containsKey('is_c_r')) {
      context.handle(
          _isCRMeta, isCR.isAcceptableOrUnknown(data['is_c_r']!, _isCRMeta));
    }
    if (data.containsKey('avatar_id')) {
      context.handle(_avatarIdMeta,
          avatarId.isAcceptableOrUnknown(data['avatar_id']!, _avatarIdMeta));
    }
    if (data.containsKey('last_profile_update')) {
      context.handle(
          _lastProfileUpdateMeta,
          lastProfileUpdate.isAcceptableOrUnknown(
              data['last_profile_update']!, _lastProfileUpdateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      internalId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}internal_id'])!,
      semester: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}semester'])!,
      section: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}section'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      isDev: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_dev'])!,
      isCR: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_c_r'])!,
      avatarId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}avatar_id'])!,
      lastProfileUpdate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_profile_update']),
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String id;
  final String name;
  final String internalId;
  final int semester;
  final String section;
  final String role;
  final bool isDev;
  final bool isCR;
  final int avatarId;
  final DateTime? lastProfileUpdate;
  const User(
      {required this.id,
      required this.name,
      required this.internalId,
      required this.semester,
      required this.section,
      required this.role,
      required this.isDev,
      required this.isCR,
      required this.avatarId,
      this.lastProfileUpdate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['internal_id'] = Variable<String>(internalId);
    map['semester'] = Variable<int>(semester);
    map['section'] = Variable<String>(section);
    map['role'] = Variable<String>(role);
    map['is_dev'] = Variable<bool>(isDev);
    map['is_c_r'] = Variable<bool>(isCR);
    map['avatar_id'] = Variable<int>(avatarId);
    if (!nullToAbsent || lastProfileUpdate != null) {
      map['last_profile_update'] = Variable<DateTime>(lastProfileUpdate);
    }
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      id: Value(id),
      name: Value(name),
      internalId: Value(internalId),
      semester: Value(semester),
      section: Value(section),
      role: Value(role),
      isDev: Value(isDev),
      isCR: Value(isCR),
      avatarId: Value(avatarId),
      lastProfileUpdate: lastProfileUpdate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastProfileUpdate),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      internalId: serializer.fromJson<String>(json['internalId']),
      semester: serializer.fromJson<int>(json['semester']),
      section: serializer.fromJson<String>(json['section']),
      role: serializer.fromJson<String>(json['role']),
      isDev: serializer.fromJson<bool>(json['isDev']),
      isCR: serializer.fromJson<bool>(json['isCR']),
      avatarId: serializer.fromJson<int>(json['avatarId']),
      lastProfileUpdate:
          serializer.fromJson<DateTime?>(json['lastProfileUpdate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'internalId': serializer.toJson<String>(internalId),
      'semester': serializer.toJson<int>(semester),
      'section': serializer.toJson<String>(section),
      'role': serializer.toJson<String>(role),
      'isDev': serializer.toJson<bool>(isDev),
      'isCR': serializer.toJson<bool>(isCR),
      'avatarId': serializer.toJson<int>(avatarId),
      'lastProfileUpdate': serializer.toJson<DateTime?>(lastProfileUpdate),
    };
  }

  User copyWith(
          {String? id,
          String? name,
          String? internalId,
          int? semester,
          String? section,
          String? role,
          bool? isDev,
          bool? isCR,
          int? avatarId,
          Value<DateTime?> lastProfileUpdate = const Value.absent()}) =>
      User(
        id: id ?? this.id,
        name: name ?? this.name,
        internalId: internalId ?? this.internalId,
        semester: semester ?? this.semester,
        section: section ?? this.section,
        role: role ?? this.role,
        isDev: isDev ?? this.isDev,
        isCR: isCR ?? this.isCR,
        avatarId: avatarId ?? this.avatarId,
        lastProfileUpdate: lastProfileUpdate.present
            ? lastProfileUpdate.value
            : this.lastProfileUpdate,
      );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      internalId:
          data.internalId.present ? data.internalId.value : this.internalId,
      semester: data.semester.present ? data.semester.value : this.semester,
      section: data.section.present ? data.section.value : this.section,
      role: data.role.present ? data.role.value : this.role,
      isDev: data.isDev.present ? data.isDev.value : this.isDev,
      isCR: data.isCR.present ? data.isCR.value : this.isCR,
      avatarId: data.avatarId.present ? data.avatarId.value : this.avatarId,
      lastProfileUpdate: data.lastProfileUpdate.present
          ? data.lastProfileUpdate.value
          : this.lastProfileUpdate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('internalId: $internalId, ')
          ..write('semester: $semester, ')
          ..write('section: $section, ')
          ..write('role: $role, ')
          ..write('isDev: $isDev, ')
          ..write('isCR: $isCR, ')
          ..write('avatarId: $avatarId, ')
          ..write('lastProfileUpdate: $lastProfileUpdate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, internalId, semester, section, role,
      isDev, isCR, avatarId, lastProfileUpdate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == this.id &&
          other.name == this.name &&
          other.internalId == this.internalId &&
          other.semester == this.semester &&
          other.section == this.section &&
          other.role == this.role &&
          other.isDev == this.isDev &&
          other.isCR == this.isCR &&
          other.avatarId == this.avatarId &&
          other.lastProfileUpdate == this.lastProfileUpdate);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> internalId;
  final Value<int> semester;
  final Value<String> section;
  final Value<String> role;
  final Value<bool> isDev;
  final Value<bool> isCR;
  final Value<int> avatarId;
  final Value<DateTime?> lastProfileUpdate;
  final Value<int> rowid;
  const UsersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.internalId = const Value.absent(),
    this.semester = const Value.absent(),
    this.section = const Value.absent(),
    this.role = const Value.absent(),
    this.isDev = const Value.absent(),
    this.isCR = const Value.absent(),
    this.avatarId = const Value.absent(),
    this.lastProfileUpdate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    required String id,
    required String name,
    required String internalId,
    required int semester,
    required String section,
    this.role = const Value.absent(),
    this.isDev = const Value.absent(),
    this.isCR = const Value.absent(),
    this.avatarId = const Value.absent(),
    this.lastProfileUpdate = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        internalId = Value(internalId),
        semester = Value(semester),
        section = Value(section);
  static Insertable<User> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? internalId,
    Expression<int>? semester,
    Expression<String>? section,
    Expression<String>? role,
    Expression<bool>? isDev,
    Expression<bool>? isCR,
    Expression<int>? avatarId,
    Expression<DateTime>? lastProfileUpdate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (internalId != null) 'internal_id': internalId,
      if (semester != null) 'semester': semester,
      if (section != null) 'section': section,
      if (role != null) 'role': role,
      if (isDev != null) 'is_dev': isDev,
      if (isCR != null) 'is_c_r': isCR,
      if (avatarId != null) 'avatar_id': avatarId,
      if (lastProfileUpdate != null) 'last_profile_update': lastProfileUpdate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? internalId,
      Value<int>? semester,
      Value<String>? section,
      Value<String>? role,
      Value<bool>? isDev,
      Value<bool>? isCR,
      Value<int>? avatarId,
      Value<DateTime?>? lastProfileUpdate,
      Value<int>? rowid}) {
    return UsersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      internalId: internalId ?? this.internalId,
      semester: semester ?? this.semester,
      section: section ?? this.section,
      role: role ?? this.role,
      isDev: isDev ?? this.isDev,
      isCR: isCR ?? this.isCR,
      avatarId: avatarId ?? this.avatarId,
      lastProfileUpdate: lastProfileUpdate ?? this.lastProfileUpdate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (internalId.present) {
      map['internal_id'] = Variable<String>(internalId.value);
    }
    if (semester.present) {
      map['semester'] = Variable<int>(semester.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (isDev.present) {
      map['is_dev'] = Variable<bool>(isDev.value);
    }
    if (isCR.present) {
      map['is_c_r'] = Variable<bool>(isCR.value);
    }
    if (avatarId.present) {
      map['avatar_id'] = Variable<int>(avatarId.value);
    }
    if (lastProfileUpdate.present) {
      map['last_profile_update'] = Variable<DateTime>(lastProfileUpdate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('internalId: $internalId, ')
          ..write('semester: $semester, ')
          ..write('section: $section, ')
          ..write('role: $role, ')
          ..write('isDev: $isDev, ')
          ..write('isCR: $isCR, ')
          ..write('avatarId: $avatarId, ')
          ..write('lastProfileUpdate: $lastProfileUpdate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnouncementsTable extends Announcements
    with TableInfo<$AnnouncementsTable, Announcement> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnouncementsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'body', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorNameMeta =
      const VerificationMeta('authorName');
  @override
  late final GeneratedColumn<String> authorName = GeneratedColumn<String>(
      'author_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _authorUidMeta =
      const VerificationMeta('authorUid');
  @override
  late final GeneratedColumn<String> authorUid = GeneratedColumn<String>(
      'author_uid', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _isDeletedMeta =
      const VerificationMeta('isDeleted');
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
      'is_deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _targetSemestersMeta =
      const VerificationMeta('targetSemesters');
  @override
  late final GeneratedColumn<String> targetSemesters = GeneratedColumn<String>(
      'target_semesters', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetSectionsMeta =
      const VerificationMeta('targetSections');
  @override
  late final GeneratedColumn<String> targetSections = GeneratedColumn<String>(
      'target_sections', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isGlobalMeta =
      const VerificationMeta('isGlobal');
  @override
  late final GeneratedColumn<bool> isGlobal = GeneratedColumn<bool>(
      'is_global', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_global" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        body,
        authorName,
        authorUid,
        isDeleted,
        targetSemesters,
        targetSections,
        isGlobal,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'announcements';
  @override
  VerificationContext validateIntegrity(Insertable<Announcement> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('body')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['body']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('author_name')) {
      context.handle(
          _authorNameMeta,
          authorName.isAcceptableOrUnknown(
              data['author_name']!, _authorNameMeta));
    } else if (isInserting) {
      context.missing(_authorNameMeta);
    }
    if (data.containsKey('author_uid')) {
      context.handle(_authorUidMeta,
          authorUid.isAcceptableOrUnknown(data['author_uid']!, _authorUidMeta));
    }
    if (data.containsKey('is_deleted')) {
      context.handle(_isDeletedMeta,
          isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta));
    }
    if (data.containsKey('target_semesters')) {
      context.handle(
          _targetSemestersMeta,
          targetSemesters.isAcceptableOrUnknown(
              data['target_semesters']!, _targetSemestersMeta));
    } else if (isInserting) {
      context.missing(_targetSemestersMeta);
    }
    if (data.containsKey('target_sections')) {
      context.handle(
          _targetSectionsMeta,
          targetSections.isAcceptableOrUnknown(
              data['target_sections']!, _targetSectionsMeta));
    } else if (isInserting) {
      context.missing(_targetSectionsMeta);
    }
    if (data.containsKey('is_global')) {
      context.handle(_isGlobalMeta,
          isGlobal.isAcceptableOrUnknown(data['is_global']!, _isGlobalMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Announcement map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Announcement(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}body'])!,
      authorName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_name'])!,
      authorUid: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author_uid'])!,
      isDeleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_deleted'])!,
      targetSemesters: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}target_semesters'])!,
      targetSections: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}target_sections'])!,
      isGlobal: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_global'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AnnouncementsTable createAlias(String alias) {
    return $AnnouncementsTable(attachedDatabase, alias);
  }
}

class Announcement extends DataClass implements Insertable<Announcement> {
  final String id;
  final String title;
  final String body;
  final String authorName;
  final String authorUid;
  final bool isDeleted;
  final String targetSemesters;
  final String targetSections;
  final bool isGlobal;
  final DateTime createdAt;
  const Announcement(
      {required this.id,
      required this.title,
      required this.body,
      required this.authorName,
      required this.authorUid,
      required this.isDeleted,
      required this.targetSemesters,
      required this.targetSections,
      required this.isGlobal,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['body'] = Variable<String>(body);
    map['author_name'] = Variable<String>(authorName);
    map['author_uid'] = Variable<String>(authorUid);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['target_semesters'] = Variable<String>(targetSemesters);
    map['target_sections'] = Variable<String>(targetSections);
    map['is_global'] = Variable<bool>(isGlobal);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AnnouncementsCompanion toCompanion(bool nullToAbsent) {
    return AnnouncementsCompanion(
      id: Value(id),
      title: Value(title),
      body: Value(body),
      authorName: Value(authorName),
      authorUid: Value(authorUid),
      isDeleted: Value(isDeleted),
      targetSemesters: Value(targetSemesters),
      targetSections: Value(targetSections),
      isGlobal: Value(isGlobal),
      createdAt: Value(createdAt),
    );
  }

  factory Announcement.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Announcement(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      body: serializer.fromJson<String>(json['body']),
      authorName: serializer.fromJson<String>(json['authorName']),
      authorUid: serializer.fromJson<String>(json['authorUid']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      targetSemesters: serializer.fromJson<String>(json['targetSemesters']),
      targetSections: serializer.fromJson<String>(json['targetSections']),
      isGlobal: serializer.fromJson<bool>(json['isGlobal']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'body': serializer.toJson<String>(body),
      'authorName': serializer.toJson<String>(authorName),
      'authorUid': serializer.toJson<String>(authorUid),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'targetSemesters': serializer.toJson<String>(targetSemesters),
      'targetSections': serializer.toJson<String>(targetSections),
      'isGlobal': serializer.toJson<bool>(isGlobal),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Announcement copyWith(
          {String? id,
          String? title,
          String? body,
          String? authorName,
          String? authorUid,
          bool? isDeleted,
          String? targetSemesters,
          String? targetSections,
          bool? isGlobal,
          DateTime? createdAt}) =>
      Announcement(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        authorName: authorName ?? this.authorName,
        authorUid: authorUid ?? this.authorUid,
        isDeleted: isDeleted ?? this.isDeleted,
        targetSemesters: targetSemesters ?? this.targetSemesters,
        targetSections: targetSections ?? this.targetSections,
        isGlobal: isGlobal ?? this.isGlobal,
        createdAt: createdAt ?? this.createdAt,
      );
  Announcement copyWithCompanion(AnnouncementsCompanion data) {
    return Announcement(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      body: data.body.present ? data.body.value : this.body,
      authorName:
          data.authorName.present ? data.authorName.value : this.authorName,
      authorUid: data.authorUid.present ? data.authorUid.value : this.authorUid,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      targetSemesters: data.targetSemesters.present
          ? data.targetSemesters.value
          : this.targetSemesters,
      targetSections: data.targetSections.present
          ? data.targetSections.value
          : this.targetSections,
      isGlobal: data.isGlobal.present ? data.isGlobal.value : this.isGlobal,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Announcement(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('authorName: $authorName, ')
          ..write('authorUid: $authorUid, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('targetSemesters: $targetSemesters, ')
          ..write('targetSections: $targetSections, ')
          ..write('isGlobal: $isGlobal, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, body, authorName, authorUid,
      isDeleted, targetSemesters, targetSections, isGlobal, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Announcement &&
          other.id == this.id &&
          other.title == this.title &&
          other.body == this.body &&
          other.authorName == this.authorName &&
          other.authorUid == this.authorUid &&
          other.isDeleted == this.isDeleted &&
          other.targetSemesters == this.targetSemesters &&
          other.targetSections == this.targetSections &&
          other.isGlobal == this.isGlobal &&
          other.createdAt == this.createdAt);
}

class AnnouncementsCompanion extends UpdateCompanion<Announcement> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> body;
  final Value<String> authorName;
  final Value<String> authorUid;
  final Value<bool> isDeleted;
  final Value<String> targetSemesters;
  final Value<String> targetSections;
  final Value<bool> isGlobal;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const AnnouncementsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.body = const Value.absent(),
    this.authorName = const Value.absent(),
    this.authorUid = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.targetSemesters = const Value.absent(),
    this.targetSections = const Value.absent(),
    this.isGlobal = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AnnouncementsCompanion.insert({
    required String id,
    required String title,
    required String body,
    required String authorName,
    this.authorUid = const Value.absent(),
    this.isDeleted = const Value.absent(),
    required String targetSemesters,
    required String targetSections,
    this.isGlobal = const Value.absent(),
    required DateTime createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        body = Value(body),
        authorName = Value(authorName),
        targetSemesters = Value(targetSemesters),
        targetSections = Value(targetSections),
        createdAt = Value(createdAt);
  static Insertable<Announcement> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? body,
    Expression<String>? authorName,
    Expression<String>? authorUid,
    Expression<bool>? isDeleted,
    Expression<String>? targetSemesters,
    Expression<String>? targetSections,
    Expression<bool>? isGlobal,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (body != null) 'body': body,
      if (authorName != null) 'author_name': authorName,
      if (authorUid != null) 'author_uid': authorUid,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (targetSemesters != null) 'target_semesters': targetSemesters,
      if (targetSections != null) 'target_sections': targetSections,
      if (isGlobal != null) 'is_global': isGlobal,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AnnouncementsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? body,
      Value<String>? authorName,
      Value<String>? authorUid,
      Value<bool>? isDeleted,
      Value<String>? targetSemesters,
      Value<String>? targetSections,
      Value<bool>? isGlobal,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return AnnouncementsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      authorName: authorName ?? this.authorName,
      authorUid: authorUid ?? this.authorUid,
      isDeleted: isDeleted ?? this.isDeleted,
      targetSemesters: targetSemesters ?? this.targetSemesters,
      targetSections: targetSections ?? this.targetSections,
      isGlobal: isGlobal ?? this.isGlobal,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (body.present) {
      map['body'] = Variable<String>(body.value);
    }
    if (authorName.present) {
      map['author_name'] = Variable<String>(authorName.value);
    }
    if (authorUid.present) {
      map['author_uid'] = Variable<String>(authorUid.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (targetSemesters.present) {
      map['target_semesters'] = Variable<String>(targetSemesters.value);
    }
    if (targetSections.present) {
      map['target_sections'] = Variable<String>(targetSections.value);
    }
    if (isGlobal.present) {
      map['is_global'] = Variable<bool>(isGlobal.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnouncementsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('body: $body, ')
          ..write('authorName: $authorName, ')
          ..write('authorUid: $authorUid, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('targetSemesters: $targetSemesters, ')
          ..write('targetSections: $targetSections, ')
          ..write('isGlobal: $isGlobal, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RoutinesTable extends Routines with TableInfo<$RoutinesTable, Routine> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutinesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _subjectNameMeta =
      const VerificationMeta('subjectName');
  @override
  late final GeneratedColumn<String> subjectName = GeneratedColumn<String>(
      'subject_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _teacherNameMeta =
      const VerificationMeta('teacherName');
  @override
  late final GeneratedColumn<String> teacherName = GeneratedColumn<String>(
      'teacher_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roomNumberMeta =
      const VerificationMeta('roomNumber');
  @override
  late final GeneratedColumn<String> roomNumber = GeneratedColumn<String>(
      'room_number', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dayOfWeekMeta =
      const VerificationMeta('dayOfWeek');
  @override
  late final GeneratedColumn<int> dayOfWeek = GeneratedColumn<int>(
      'day_of_week', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<String> startTime = GeneratedColumn<String>(
      'start_time', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _endTimeMeta =
      const VerificationMeta('endTime');
  @override
  late final GeneratedColumn<String> endTime = GeneratedColumn<String>(
      'end_time', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _semesterMeta =
      const VerificationMeta('semester');
  @override
  late final GeneratedColumn<int> semester = GeneratedColumn<int>(
      'semester', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sectionMeta =
      const VerificationMeta('section');
  @override
  late final GeneratedColumn<String> section = GeneratedColumn<String>(
      'section', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        subjectName,
        teacherName,
        roomNumber,
        dayOfWeek,
        startTime,
        endTime,
        semester,
        section
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routines';
  @override
  VerificationContext validateIntegrity(Insertable<Routine> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('subject_name')) {
      context.handle(
          _subjectNameMeta,
          subjectName.isAcceptableOrUnknown(
              data['subject_name']!, _subjectNameMeta));
    } else if (isInserting) {
      context.missing(_subjectNameMeta);
    }
    if (data.containsKey('teacher_name')) {
      context.handle(
          _teacherNameMeta,
          teacherName.isAcceptableOrUnknown(
              data['teacher_name']!, _teacherNameMeta));
    } else if (isInserting) {
      context.missing(_teacherNameMeta);
    }
    if (data.containsKey('room_number')) {
      context.handle(
          _roomNumberMeta,
          roomNumber.isAcceptableOrUnknown(
              data['room_number']!, _roomNumberMeta));
    } else if (isInserting) {
      context.missing(_roomNumberMeta);
    }
    if (data.containsKey('day_of_week')) {
      context.handle(
          _dayOfWeekMeta,
          dayOfWeek.isAcceptableOrUnknown(
              data['day_of_week']!, _dayOfWeekMeta));
    } else if (isInserting) {
      context.missing(_dayOfWeekMeta);
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(_endTimeMeta,
          endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta));
    } else if (isInserting) {
      context.missing(_endTimeMeta);
    }
    if (data.containsKey('semester')) {
      context.handle(_semesterMeta,
          semester.isAcceptableOrUnknown(data['semester']!, _semesterMeta));
    } else if (isInserting) {
      context.missing(_semesterMeta);
    }
    if (data.containsKey('section')) {
      context.handle(_sectionMeta,
          section.isAcceptableOrUnknown(data['section']!, _sectionMeta));
    } else if (isInserting) {
      context.missing(_sectionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Routine map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Routine(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      subjectName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}subject_name'])!,
      teacherName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}teacher_name'])!,
      roomNumber: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}room_number'])!,
      dayOfWeek: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}day_of_week'])!,
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}start_time'])!,
      endTime: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}end_time'])!,
      semester: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}semester'])!,
      section: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}section'])!,
    );
  }

  @override
  $RoutinesTable createAlias(String alias) {
    return $RoutinesTable(attachedDatabase, alias);
  }
}

class Routine extends DataClass implements Insertable<Routine> {
  final String id;
  final String subjectName;
  final String teacherName;
  final String roomNumber;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int semester;
  final String section;
  const Routine(
      {required this.id,
      required this.subjectName,
      required this.teacherName,
      required this.roomNumber,
      required this.dayOfWeek,
      required this.startTime,
      required this.endTime,
      required this.semester,
      required this.section});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['subject_name'] = Variable<String>(subjectName);
    map['teacher_name'] = Variable<String>(teacherName);
    map['room_number'] = Variable<String>(roomNumber);
    map['day_of_week'] = Variable<int>(dayOfWeek);
    map['start_time'] = Variable<String>(startTime);
    map['end_time'] = Variable<String>(endTime);
    map['semester'] = Variable<int>(semester);
    map['section'] = Variable<String>(section);
    return map;
  }

  RoutinesCompanion toCompanion(bool nullToAbsent) {
    return RoutinesCompanion(
      id: Value(id),
      subjectName: Value(subjectName),
      teacherName: Value(teacherName),
      roomNumber: Value(roomNumber),
      dayOfWeek: Value(dayOfWeek),
      startTime: Value(startTime),
      endTime: Value(endTime),
      semester: Value(semester),
      section: Value(section),
    );
  }

  factory Routine.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Routine(
      id: serializer.fromJson<String>(json['id']),
      subjectName: serializer.fromJson<String>(json['subjectName']),
      teacherName: serializer.fromJson<String>(json['teacherName']),
      roomNumber: serializer.fromJson<String>(json['roomNumber']),
      dayOfWeek: serializer.fromJson<int>(json['dayOfWeek']),
      startTime: serializer.fromJson<String>(json['startTime']),
      endTime: serializer.fromJson<String>(json['endTime']),
      semester: serializer.fromJson<int>(json['semester']),
      section: serializer.fromJson<String>(json['section']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'subjectName': serializer.toJson<String>(subjectName),
      'teacherName': serializer.toJson<String>(teacherName),
      'roomNumber': serializer.toJson<String>(roomNumber),
      'dayOfWeek': serializer.toJson<int>(dayOfWeek),
      'startTime': serializer.toJson<String>(startTime),
      'endTime': serializer.toJson<String>(endTime),
      'semester': serializer.toJson<int>(semester),
      'section': serializer.toJson<String>(section),
    };
  }

  Routine copyWith(
          {String? id,
          String? subjectName,
          String? teacherName,
          String? roomNumber,
          int? dayOfWeek,
          String? startTime,
          String? endTime,
          int? semester,
          String? section}) =>
      Routine(
        id: id ?? this.id,
        subjectName: subjectName ?? this.subjectName,
        teacherName: teacherName ?? this.teacherName,
        roomNumber: roomNumber ?? this.roomNumber,
        dayOfWeek: dayOfWeek ?? this.dayOfWeek,
        startTime: startTime ?? this.startTime,
        endTime: endTime ?? this.endTime,
        semester: semester ?? this.semester,
        section: section ?? this.section,
      );
  Routine copyWithCompanion(RoutinesCompanion data) {
    return Routine(
      id: data.id.present ? data.id.value : this.id,
      subjectName:
          data.subjectName.present ? data.subjectName.value : this.subjectName,
      teacherName:
          data.teacherName.present ? data.teacherName.value : this.teacherName,
      roomNumber:
          data.roomNumber.present ? data.roomNumber.value : this.roomNumber,
      dayOfWeek: data.dayOfWeek.present ? data.dayOfWeek.value : this.dayOfWeek,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      semester: data.semester.present ? data.semester.value : this.semester,
      section: data.section.present ? data.section.value : this.section,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Routine(')
          ..write('id: $id, ')
          ..write('subjectName: $subjectName, ')
          ..write('teacherName: $teacherName, ')
          ..write('roomNumber: $roomNumber, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('semester: $semester, ')
          ..write('section: $section')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, subjectName, teacherName, roomNumber,
      dayOfWeek, startTime, endTime, semester, section);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Routine &&
          other.id == this.id &&
          other.subjectName == this.subjectName &&
          other.teacherName == this.teacherName &&
          other.roomNumber == this.roomNumber &&
          other.dayOfWeek == this.dayOfWeek &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.semester == this.semester &&
          other.section == this.section);
}

class RoutinesCompanion extends UpdateCompanion<Routine> {
  final Value<String> id;
  final Value<String> subjectName;
  final Value<String> teacherName;
  final Value<String> roomNumber;
  final Value<int> dayOfWeek;
  final Value<String> startTime;
  final Value<String> endTime;
  final Value<int> semester;
  final Value<String> section;
  final Value<int> rowid;
  const RoutinesCompanion({
    this.id = const Value.absent(),
    this.subjectName = const Value.absent(),
    this.teacherName = const Value.absent(),
    this.roomNumber = const Value.absent(),
    this.dayOfWeek = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.semester = const Value.absent(),
    this.section = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutinesCompanion.insert({
    required String id,
    required String subjectName,
    required String teacherName,
    required String roomNumber,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required int semester,
    required String section,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        subjectName = Value(subjectName),
        teacherName = Value(teacherName),
        roomNumber = Value(roomNumber),
        dayOfWeek = Value(dayOfWeek),
        startTime = Value(startTime),
        endTime = Value(endTime),
        semester = Value(semester),
        section = Value(section);
  static Insertable<Routine> custom({
    Expression<String>? id,
    Expression<String>? subjectName,
    Expression<String>? teacherName,
    Expression<String>? roomNumber,
    Expression<int>? dayOfWeek,
    Expression<String>? startTime,
    Expression<String>? endTime,
    Expression<int>? semester,
    Expression<String>? section,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (subjectName != null) 'subject_name': subjectName,
      if (teacherName != null) 'teacher_name': teacherName,
      if (roomNumber != null) 'room_number': roomNumber,
      if (dayOfWeek != null) 'day_of_week': dayOfWeek,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (semester != null) 'semester': semester,
      if (section != null) 'section': section,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutinesCompanion copyWith(
      {Value<String>? id,
      Value<String>? subjectName,
      Value<String>? teacherName,
      Value<String>? roomNumber,
      Value<int>? dayOfWeek,
      Value<String>? startTime,
      Value<String>? endTime,
      Value<int>? semester,
      Value<String>? section,
      Value<int>? rowid}) {
    return RoutinesCompanion(
      id: id ?? this.id,
      subjectName: subjectName ?? this.subjectName,
      teacherName: teacherName ?? this.teacherName,
      roomNumber: roomNumber ?? this.roomNumber,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      semester: semester ?? this.semester,
      section: section ?? this.section,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (subjectName.present) {
      map['subject_name'] = Variable<String>(subjectName.value);
    }
    if (teacherName.present) {
      map['teacher_name'] = Variable<String>(teacherName.value);
    }
    if (roomNumber.present) {
      map['room_number'] = Variable<String>(roomNumber.value);
    }
    if (dayOfWeek.present) {
      map['day_of_week'] = Variable<int>(dayOfWeek.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<String>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<String>(endTime.value);
    }
    if (semester.present) {
      map['semester'] = Variable<int>(semester.value);
    }
    if (section.present) {
      map['section'] = Variable<String>(section.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutinesCompanion(')
          ..write('id: $id, ')
          ..write('subjectName: $subjectName, ')
          ..write('teacherName: $teacherName, ')
          ..write('roomNumber: $roomNumber, ')
          ..write('dayOfWeek: $dayOfWeek, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('semester: $semester, ')
          ..write('section: $section, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UsersTable users = $UsersTable(this);
  late final $AnnouncementsTable announcements = $AnnouncementsTable(this);
  late final $RoutinesTable routines = $RoutinesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [users, announcements, routines];
}

typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  required String id,
  required String name,
  required String internalId,
  required int semester,
  required String section,
  Value<String> role,
  Value<bool> isDev,
  Value<bool> isCR,
  Value<int> avatarId,
  Value<DateTime?> lastProfileUpdate,
  Value<int> rowid,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> internalId,
  Value<int> semester,
  Value<String> section,
  Value<String> role,
  Value<bool> isDev,
  Value<bool> isCR,
  Value<int> avatarId,
  Value<DateTime?> lastProfileUpdate,
  Value<int> rowid,
});

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$UsersTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$UsersTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> internalId = const Value.absent(),
            Value<int> semester = const Value.absent(),
            Value<String> section = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<bool> isDev = const Value.absent(),
            Value<bool> isCR = const Value.absent(),
            Value<int> avatarId = const Value.absent(),
            Value<DateTime?> lastProfileUpdate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion(
            id: id,
            name: name,
            internalId: internalId,
            semester: semester,
            section: section,
            role: role,
            isDev: isDev,
            isCR: isCR,
            avatarId: avatarId,
            lastProfileUpdate: lastProfileUpdate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String internalId,
            required int semester,
            required String section,
            Value<String> role = const Value.absent(),
            Value<bool> isDev = const Value.absent(),
            Value<bool> isCR = const Value.absent(),
            Value<int> avatarId = const Value.absent(),
            Value<DateTime?> lastProfileUpdate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            id: id,
            name: name,
            internalId: internalId,
            semester: semester,
            section: section,
            role: role,
            isDev: isDev,
            isCR: isCR,
            avatarId: avatarId,
            lastProfileUpdate: lastProfileUpdate,
            rowid: rowid,
          ),
        ));
}

class $$UsersTableFilterComposer
    extends FilterComposer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get internalId => $state.composableBuilder(
      column: $state.table.internalId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get semester => $state.composableBuilder(
      column: $state.table.semester,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get section => $state.composableBuilder(
      column: $state.table.section,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get role => $state.composableBuilder(
      column: $state.table.role,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isDev => $state.composableBuilder(
      column: $state.table.isDev,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isCR => $state.composableBuilder(
      column: $state.table.isCR,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get avatarId => $state.composableBuilder(
      column: $state.table.avatarId,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get lastProfileUpdate => $state.composableBuilder(
      column: $state.table.lastProfileUpdate,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$UsersTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get name => $state.composableBuilder(
      column: $state.table.name,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get internalId => $state.composableBuilder(
      column: $state.table.internalId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get semester => $state.composableBuilder(
      column: $state.table.semester,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get section => $state.composableBuilder(
      column: $state.table.section,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get role => $state.composableBuilder(
      column: $state.table.role,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isDev => $state.composableBuilder(
      column: $state.table.isDev,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isCR => $state.composableBuilder(
      column: $state.table.isCR,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get avatarId => $state.composableBuilder(
      column: $state.table.avatarId,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get lastProfileUpdate => $state.composableBuilder(
      column: $state.table.lastProfileUpdate,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$AnnouncementsTableCreateCompanionBuilder = AnnouncementsCompanion
    Function({
  required String id,
  required String title,
  required String body,
  required String authorName,
  Value<String> authorUid,
  Value<bool> isDeleted,
  required String targetSemesters,
  required String targetSections,
  Value<bool> isGlobal,
  required DateTime createdAt,
  Value<int> rowid,
});
typedef $$AnnouncementsTableUpdateCompanionBuilder = AnnouncementsCompanion
    Function({
  Value<String> id,
  Value<String> title,
  Value<String> body,
  Value<String> authorName,
  Value<String> authorUid,
  Value<bool> isDeleted,
  Value<String> targetSemesters,
  Value<String> targetSections,
  Value<bool> isGlobal,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$AnnouncementsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AnnouncementsTable,
    Announcement,
    $$AnnouncementsTableFilterComposer,
    $$AnnouncementsTableOrderingComposer,
    $$AnnouncementsTableCreateCompanionBuilder,
    $$AnnouncementsTableUpdateCompanionBuilder> {
  $$AnnouncementsTableTableManager(_$AppDatabase db, $AnnouncementsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$AnnouncementsTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$AnnouncementsTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String> authorName = const Value.absent(),
            Value<String> authorUid = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            Value<String> targetSemesters = const Value.absent(),
            Value<String> targetSections = const Value.absent(),
            Value<bool> isGlobal = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnouncementsCompanion(
            id: id,
            title: title,
            body: body,
            authorName: authorName,
            authorUid: authorUid,
            isDeleted: isDeleted,
            targetSemesters: targetSemesters,
            targetSections: targetSections,
            isGlobal: isGlobal,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String body,
            required String authorName,
            Value<String> authorUid = const Value.absent(),
            Value<bool> isDeleted = const Value.absent(),
            required String targetSemesters,
            required String targetSections,
            Value<bool> isGlobal = const Value.absent(),
            required DateTime createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AnnouncementsCompanion.insert(
            id: id,
            title: title,
            body: body,
            authorName: authorName,
            authorUid: authorUid,
            isDeleted: isDeleted,
            targetSemesters: targetSemesters,
            targetSections: targetSections,
            isGlobal: isGlobal,
            createdAt: createdAt,
            rowid: rowid,
          ),
        ));
}

class $$AnnouncementsTableFilterComposer
    extends FilterComposer<_$AppDatabase, $AnnouncementsTable> {
  $$AnnouncementsTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get body => $state.composableBuilder(
      column: $state.table.body,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get authorName => $state.composableBuilder(
      column: $state.table.authorName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get authorUid => $state.composableBuilder(
      column: $state.table.authorUid,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isDeleted => $state.composableBuilder(
      column: $state.table.isDeleted,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get targetSemesters => $state.composableBuilder(
      column: $state.table.targetSemesters,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get targetSections => $state.composableBuilder(
      column: $state.table.targetSections,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<bool> get isGlobal => $state.composableBuilder(
      column: $state.table.isGlobal,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$AnnouncementsTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $AnnouncementsTable> {
  $$AnnouncementsTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get title => $state.composableBuilder(
      column: $state.table.title,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get body => $state.composableBuilder(
      column: $state.table.body,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get authorName => $state.composableBuilder(
      column: $state.table.authorName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get authorUid => $state.composableBuilder(
      column: $state.table.authorUid,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isDeleted => $state.composableBuilder(
      column: $state.table.isDeleted,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get targetSemesters => $state.composableBuilder(
      column: $state.table.targetSemesters,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get targetSections => $state.composableBuilder(
      column: $state.table.targetSections,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<bool> get isGlobal => $state.composableBuilder(
      column: $state.table.isGlobal,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<DateTime> get createdAt => $state.composableBuilder(
      column: $state.table.createdAt,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

typedef $$RoutinesTableCreateCompanionBuilder = RoutinesCompanion Function({
  required String id,
  required String subjectName,
  required String teacherName,
  required String roomNumber,
  required int dayOfWeek,
  required String startTime,
  required String endTime,
  required int semester,
  required String section,
  Value<int> rowid,
});
typedef $$RoutinesTableUpdateCompanionBuilder = RoutinesCompanion Function({
  Value<String> id,
  Value<String> subjectName,
  Value<String> teacherName,
  Value<String> roomNumber,
  Value<int> dayOfWeek,
  Value<String> startTime,
  Value<String> endTime,
  Value<int> semester,
  Value<String> section,
  Value<int> rowid,
});

class $$RoutinesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RoutinesTable,
    Routine,
    $$RoutinesTableFilterComposer,
    $$RoutinesTableOrderingComposer,
    $$RoutinesTableCreateCompanionBuilder,
    $$RoutinesTableUpdateCompanionBuilder> {
  $$RoutinesTableTableManager(_$AppDatabase db, $RoutinesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          filteringComposer:
              $$RoutinesTableFilterComposer(ComposerState(db, table)),
          orderingComposer:
              $$RoutinesTableOrderingComposer(ComposerState(db, table)),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> subjectName = const Value.absent(),
            Value<String> teacherName = const Value.absent(),
            Value<String> roomNumber = const Value.absent(),
            Value<int> dayOfWeek = const Value.absent(),
            Value<String> startTime = const Value.absent(),
            Value<String> endTime = const Value.absent(),
            Value<int> semester = const Value.absent(),
            Value<String> section = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RoutinesCompanion(
            id: id,
            subjectName: subjectName,
            teacherName: teacherName,
            roomNumber: roomNumber,
            dayOfWeek: dayOfWeek,
            startTime: startTime,
            endTime: endTime,
            semester: semester,
            section: section,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String subjectName,
            required String teacherName,
            required String roomNumber,
            required int dayOfWeek,
            required String startTime,
            required String endTime,
            required int semester,
            required String section,
            Value<int> rowid = const Value.absent(),
          }) =>
              RoutinesCompanion.insert(
            id: id,
            subjectName: subjectName,
            teacherName: teacherName,
            roomNumber: roomNumber,
            dayOfWeek: dayOfWeek,
            startTime: startTime,
            endTime: endTime,
            semester: semester,
            section: section,
            rowid: rowid,
          ),
        ));
}

class $$RoutinesTableFilterComposer
    extends FilterComposer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableFilterComposer(super.$state);
  ColumnFilters<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get subjectName => $state.composableBuilder(
      column: $state.table.subjectName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get teacherName => $state.composableBuilder(
      column: $state.table.teacherName,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get roomNumber => $state.composableBuilder(
      column: $state.table.roomNumber,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get dayOfWeek => $state.composableBuilder(
      column: $state.table.dayOfWeek,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get startTime => $state.composableBuilder(
      column: $state.table.startTime,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get endTime => $state.composableBuilder(
      column: $state.table.endTime,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<int> get semester => $state.composableBuilder(
      column: $state.table.semester,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));

  ColumnFilters<String> get section => $state.composableBuilder(
      column: $state.table.section,
      builder: (column, joinBuilders) =>
          ColumnFilters(column, joinBuilders: joinBuilders));
}

class $$RoutinesTableOrderingComposer
    extends OrderingComposer<_$AppDatabase, $RoutinesTable> {
  $$RoutinesTableOrderingComposer(super.$state);
  ColumnOrderings<String> get id => $state.composableBuilder(
      column: $state.table.id,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get subjectName => $state.composableBuilder(
      column: $state.table.subjectName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get teacherName => $state.composableBuilder(
      column: $state.table.teacherName,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get roomNumber => $state.composableBuilder(
      column: $state.table.roomNumber,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get dayOfWeek => $state.composableBuilder(
      column: $state.table.dayOfWeek,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get startTime => $state.composableBuilder(
      column: $state.table.startTime,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get endTime => $state.composableBuilder(
      column: $state.table.endTime,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<int> get semester => $state.composableBuilder(
      column: $state.table.semester,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));

  ColumnOrderings<String> get section => $state.composableBuilder(
      column: $state.table.section,
      builder: (column, joinBuilders) =>
          ColumnOrderings(column, joinBuilders: joinBuilders));
}

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$AnnouncementsTableTableManager get announcements =>
      $$AnnouncementsTableTableManager(_db, _db.announcements);
  $$RoutinesTableTableManager get routines =>
      $$RoutinesTableTableManager(_db, _db.routines);
}
