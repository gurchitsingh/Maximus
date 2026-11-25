// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $SettingsTable extends Settings
    with TableInfo<$SettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(0),
      ).withConverter<DateTime>($SettingsTable.$converterupdatedAt);
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt, deleted, dirty];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: $SettingsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
    );
  }

  @override
  $SettingsTable createAlias(String alias) {
    return $SettingsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMs();
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;

  /// Seeded defaults are 0 (the epoch) and clean, so any value the account
  /// already has wins over them on the first pull.
  final DateTime updatedAt;
  final bool deleted;
  final bool dirty;
  const SettingRow({
    required this.key,
    required this.value,
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    {
      map['updated_at'] = Variable<int>(
        $SettingsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    return map;
  }

  SettingsCompanion toCompanion(bool nullToAbsent) {
    return SettingsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
    );
  }

  factory SettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
    };
  }

  SettingRow copyWith({
    String? key,
    String? value,
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
  }) => SettingRow(
    key: key ?? this.key,
    value: value ?? this.value,
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
  );
  SettingRow copyWithCompanion(SettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt, deleted, dirty);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty);
}

class SettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int> rowid;
  const SettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SettingsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<int>? rowid,
  }) {
    return SettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $SettingsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $InterestsTable extends Interests
    with TableInfo<$InterestsTable, InterestRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InterestsTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        clientDefault: () => DateTime.now().millisecondsSinceEpoch,
      ).withConverter<DateTime>($InterestsTable.$converterupdatedAt);
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta(
    'position',
  );
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
    'position',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pickedAtMeta = const VerificationMeta(
    'pickedAt',
  );
  @override
  late final GeneratedColumn<DateTime> pickedAt = GeneratedColumn<DateTime>(
    'picked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    dirty,
    titleId,
    kind,
    position,
    pickedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interests';
  @override
  VerificationContext validateIntegrity(
    Insertable<InterestRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('position')) {
      context.handle(
        _positionMeta,
        position.isAcceptableOrUnknown(data['position']!, _positionMeta),
      );
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('picked_at')) {
      context.handle(
        _pickedAtMeta,
        pickedAt.isAcceptableOrUnknown(data['picked_at']!, _pickedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_pickedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {titleId, kind};
  @override
  InterestRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InterestRow(
      updatedAt: $InterestsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      position: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}position'],
      )!,
      pickedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}picked_at'],
      )!,
    );
  }

  @override
  $InterestsTable createAlias(String alias) {
    return $InterestsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMs();
}

class InterestRow extends DataClass implements Insertable<InterestRow> {
  /// When the user made the change (device clock, UTC). Decides conflicts.
  /// The DAOs always set it; the client default is only a fallback.
  final DateTime updatedAt;

  /// Tombstone: hidden from every read, removed once the server has it.
  final bool deleted;

  /// Changed here and not yet acknowledged by the server.
  final bool dirty;
  final String titleId;

  /// `topic_pick` | `leader_pick`.
  final String kind;
  final int position;
  final DateTime pickedAt;
  const InterestRow({
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
    required this.titleId,
    required this.kind,
    required this.position,
    required this.pickedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['updated_at'] = Variable<int>(
        $InterestsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['title_id'] = Variable<String>(titleId);
    map['kind'] = Variable<String>(kind);
    map['position'] = Variable<int>(position);
    map['picked_at'] = Variable<DateTime>(pickedAt);
    return map;
  }

  InterestsCompanion toCompanion(bool nullToAbsent) {
    return InterestsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      titleId: Value(titleId),
      kind: Value(kind),
      position: Value(position),
      pickedAt: Value(pickedAt),
    );
  }

  factory InterestRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InterestRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      titleId: serializer.fromJson<String>(json['titleId']),
      kind: serializer.fromJson<String>(json['kind']),
      position: serializer.fromJson<int>(json['position']),
      pickedAt: serializer.fromJson<DateTime>(json['pickedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'titleId': serializer.toJson<String>(titleId),
      'kind': serializer.toJson<String>(kind),
      'position': serializer.toJson<int>(position),
      'pickedAt': serializer.toJson<DateTime>(pickedAt),
    };
  }

  InterestRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
    String? titleId,
    String? kind,
    int? position,
    DateTime? pickedAt,
  }) => InterestRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    titleId: titleId ?? this.titleId,
    kind: kind ?? this.kind,
    position: position ?? this.position,
    pickedAt: pickedAt ?? this.pickedAt,
  );
  InterestRow copyWithCompanion(InterestsCompanion data) {
    return InterestRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      kind: data.kind.present ? data.kind.value : this.kind,
      position: data.position.present ? data.position.value : this.position,
      pickedAt: data.pickedAt.present ? data.pickedAt.value : this.pickedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InterestRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('titleId: $titleId, ')
          ..write('kind: $kind, ')
          ..write('position: $position, ')
          ..write('pickedAt: $pickedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(updatedAt, deleted, dirty, titleId, kind, position, pickedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InterestRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.titleId == this.titleId &&
          other.kind == this.kind &&
          other.position == this.position &&
          other.pickedAt == this.pickedAt);
}

class InterestsCompanion extends UpdateCompanion<InterestRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> titleId;
  final Value<String> kind;
  final Value<int> position;
  final Value<DateTime> pickedAt;
  final Value<int> rowid;
  const InterestsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.titleId = const Value.absent(),
    this.kind = const Value.absent(),
    this.position = const Value.absent(),
    this.pickedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InterestsCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String titleId,
    required String kind,
    required int position,
    required DateTime pickedAt,
    this.rowid = const Value.absent(),
  }) : titleId = Value(titleId),
       kind = Value(kind),
       position = Value(position),
       pickedAt = Value(pickedAt);
  static Insertable<InterestRow> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? titleId,
    Expression<String>? kind,
    Expression<int>? position,
    Expression<DateTime>? pickedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (titleId != null) 'title_id': titleId,
      if (kind != null) 'kind': kind,
      if (position != null) 'position': position,
      if (pickedAt != null) 'picked_at': pickedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InterestsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? titleId,
    Value<String>? kind,
    Value<int>? position,
    Value<DateTime>? pickedAt,
    Value<int>? rowid,
  }) {
    return InterestsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      titleId: titleId ?? this.titleId,
      kind: kind ?? this.kind,
      position: position ?? this.position,
      pickedAt: pickedAt ?? this.pickedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $InterestsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (pickedAt.present) {
      map['picked_at'] = Variable<DateTime>(pickedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InterestsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('titleId: $titleId, ')
          ..write('kind: $kind, ')
          ..write('position: $position, ')
          ..write('pickedAt: $pickedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StudyListTable extends StudyList
    with TableInfo<$StudyListTable, StudyItemRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyListTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        clientDefault: () => DateTime.now().millisecondsSinceEpoch,
      ).withConverter<DateTime>($StudyListTable.$converterupdatedAt);
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    dirty,
    titleId,
    addedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_list';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyItemRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {titleId};
  @override
  StudyItemRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyItemRow(
      updatedAt: $StudyListTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $StudyListTable createAlias(String alias) {
    return $StudyListTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMs();
}

class StudyItemRow extends DataClass implements Insertable<StudyItemRow> {
  /// When the user made the change (device clock, UTC). Decides conflicts.
  /// The DAOs always set it; the client default is only a fallback.
  final DateTime updatedAt;

  /// Tombstone: hidden from every read, removed once the server has it.
  final bool deleted;

  /// Changed here and not yet acknowledged by the server.
  final bool dirty;
  final String titleId;
  final DateTime addedAt;
  const StudyItemRow({
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
    required this.titleId,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['updated_at'] = Variable<int>(
        $StudyListTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['title_id'] = Variable<String>(titleId);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  StudyListCompanion toCompanion(bool nullToAbsent) {
    return StudyListCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      titleId: Value(titleId),
      addedAt: Value(addedAt),
    );
  }

  factory StudyItemRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyItemRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      titleId: serializer.fromJson<String>(json['titleId']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'titleId': serializer.toJson<String>(titleId),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  StudyItemRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
    String? titleId,
    DateTime? addedAt,
  }) => StudyItemRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    titleId: titleId ?? this.titleId,
    addedAt: addedAt ?? this.addedAt,
  );
  StudyItemRow copyWithCompanion(StudyListCompanion data) {
    return StudyItemRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyItemRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('titleId: $titleId, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(updatedAt, deleted, dirty, titleId, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyItemRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.titleId == this.titleId &&
          other.addedAt == this.addedAt);
}

class StudyListCompanion extends UpdateCompanion<StudyItemRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> titleId;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const StudyListCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.titleId = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StudyListCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String titleId,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : titleId = Value(titleId),
       addedAt = Value(addedAt);
  static Insertable<StudyItemRow> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? titleId,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (titleId != null) 'title_id': titleId,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StudyListCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? titleId,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return StudyListCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      titleId: titleId ?? this.titleId,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $StudyListTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyListCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('titleId: $titleId, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RatingsTable extends Ratings with TableInfo<$RatingsTable, RatingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RatingsTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        clientDefault: () => DateTime.now().millisecondsSinceEpoch,
      ).withConverter<DateTime>($RatingsTable.$converterupdatedAt);
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ratedAtMeta = const VerificationMeta(
    'ratedAt',
  );
  @override
  late final GeneratedColumn<DateTime> ratedAt = GeneratedColumn<DateTime>(
    'rated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    dirty,
    titleId,
    value,
    ratedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ratings';
  @override
  VerificationContext validateIntegrity(
    Insertable<RatingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('rated_at')) {
      context.handle(
        _ratedAtMeta,
        ratedAt.isAcceptableOrUnknown(data['rated_at']!, _ratedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_ratedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {titleId};
  @override
  RatingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RatingRow(
      updatedAt: $RatingsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}value'],
      )!,
      ratedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}rated_at'],
      )!,
    );
  }

  @override
  $RatingsTable createAlias(String alias) {
    return $RatingsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMs();
}

class RatingRow extends DataClass implements Insertable<RatingRow> {
  /// When the user made the change (device clock, UTC). Decides conflicts.
  /// The DAOs always set it; the client default is only a fallback.
  final DateTime updatedAt;

  /// Tombstone: hidden from every read, removed once the server has it.
  final bool deleted;

  /// Changed here and not yet acknowledged by the server.
  final bool dirty;
  final String titleId;

  /// -1, 0, 1.
  final int value;
  final DateTime ratedAt;
  const RatingRow({
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
    required this.titleId,
    required this.value,
    required this.ratedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['updated_at'] = Variable<int>(
        $RatingsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['title_id'] = Variable<String>(titleId);
    map['value'] = Variable<int>(value);
    map['rated_at'] = Variable<DateTime>(ratedAt);
    return map;
  }

  RatingsCompanion toCompanion(bool nullToAbsent) {
    return RatingsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      titleId: Value(titleId),
      value: Value(value),
      ratedAt: Value(ratedAt),
    );
  }

  factory RatingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RatingRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      titleId: serializer.fromJson<String>(json['titleId']),
      value: serializer.fromJson<int>(json['value']),
      ratedAt: serializer.fromJson<DateTime>(json['ratedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'titleId': serializer.toJson<String>(titleId),
      'value': serializer.toJson<int>(value),
      'ratedAt': serializer.toJson<DateTime>(ratedAt),
    };
  }

  RatingRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
    String? titleId,
    int? value,
    DateTime? ratedAt,
  }) => RatingRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    titleId: titleId ?? this.titleId,
    value: value ?? this.value,
    ratedAt: ratedAt ?? this.ratedAt,
  );
  RatingRow copyWithCompanion(RatingsCompanion data) {
    return RatingRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      value: data.value.present ? data.value.value : this.value,
      ratedAt: data.ratedAt.present ? data.ratedAt.value : this.ratedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RatingRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('titleId: $titleId, ')
          ..write('value: $value, ')
          ..write('ratedAt: $ratedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(updatedAt, deleted, dirty, titleId, value, ratedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RatingRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.titleId == this.titleId &&
          other.value == this.value &&
          other.ratedAt == this.ratedAt);
}

class RatingsCompanion extends UpdateCompanion<RatingRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> titleId;
  final Value<int> value;
  final Value<DateTime> ratedAt;
  final Value<int> rowid;
  const RatingsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.titleId = const Value.absent(),
    this.value = const Value.absent(),
    this.ratedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RatingsCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String titleId,
    required int value,
    required DateTime ratedAt,
    this.rowid = const Value.absent(),
  }) : titleId = Value(titleId),
       value = Value(value),
       ratedAt = Value(ratedAt);
  static Insertable<RatingRow> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? titleId,
    Expression<int>? value,
    Expression<DateTime>? ratedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (titleId != null) 'title_id': titleId,
      if (value != null) 'value': value,
      if (ratedAt != null) 'rated_at': ratedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RatingsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? titleId,
    Value<int>? value,
    Value<DateTime>? ratedAt,
    Value<int>? rowid,
  }) {
    return RatingsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      titleId: titleId ?? this.titleId,
      value: value ?? this.value,
      ratedAt: ratedAt ?? this.ratedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $RatingsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (ratedAt.present) {
      map['rated_at'] = Variable<DateTime>(ratedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RatingsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('titleId: $titleId, ')
          ..write('value: $value, ')
          ..write('ratedAt: $ratedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LessonProgressTable extends LessonProgress
    with TableInfo<$LessonProgressTable, LessonProgressRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LessonProgressTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        clientDefault: () => DateTime.now().millisecondsSinceEpoch,
      ).withConverter<DateTime>($LessonProgressTable.$converterupdatedAt);
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<String> lessonId = GeneratedColumn<String>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lessonIndexMeta = const VerificationMeta(
    'lessonIndex',
  );
  @override
  late final GeneratedColumn<int> lessonIndex = GeneratedColumn<int>(
    'lesson_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    dirty,
    lessonId,
    titleId,
    lessonIndex,
    lastOpenedAt,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lesson_progress';
  @override
  VerificationContext validateIntegrity(
    Insertable<LessonProgressRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('lesson_index')) {
      context.handle(
        _lessonIndexMeta,
        lessonIndex.isAcceptableOrUnknown(
          data['lesson_index']!,
          _lessonIndexMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lessonIndexMeta);
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastOpenedAtMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {lessonId};
  @override
  LessonProgressRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LessonProgressRow(
      updatedAt: $LessonProgressTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      lessonIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_index'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      ),
    );
  }

  @override
  $LessonProgressTable createAlias(String alias) {
    return $LessonProgressTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMs();
}

class LessonProgressRow extends DataClass
    implements Insertable<LessonProgressRow> {
  /// When the user made the change (device clock, UTC). Decides conflicts.
  /// The DAOs always set it; the client default is only a fallback.
  final DateTime updatedAt;

  /// Tombstone: hidden from every read, removed once the server has it.
  final bool deleted;

  /// Changed here and not yet acknowledged by the server.
  final bool dirty;
  final String lessonId;
  final String titleId;
  final int lessonIndex;
  final DateTime lastOpenedAt;
  final DateTime? completedAt;
  const LessonProgressRow({
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
    required this.lessonId,
    required this.titleId,
    required this.lessonIndex,
    required this.lastOpenedAt,
    this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['updated_at'] = Variable<int>(
        $LessonProgressTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['lesson_id'] = Variable<String>(lessonId);
    map['title_id'] = Variable<String>(titleId);
    map['lesson_index'] = Variable<int>(lessonIndex);
    map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  LessonProgressCompanion toCompanion(bool nullToAbsent) {
    return LessonProgressCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      lessonId: Value(lessonId),
      titleId: Value(titleId),
      lessonIndex: Value(lessonIndex),
      lastOpenedAt: Value(lastOpenedAt),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory LessonProgressRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LessonProgressRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      lessonId: serializer.fromJson<String>(json['lessonId']),
      titleId: serializer.fromJson<String>(json['titleId']),
      lessonIndex: serializer.fromJson<int>(json['lessonIndex']),
      lastOpenedAt: serializer.fromJson<DateTime>(json['lastOpenedAt']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'lessonId': serializer.toJson<String>(lessonId),
      'titleId': serializer.toJson<String>(titleId),
      'lessonIndex': serializer.toJson<int>(lessonIndex),
      'lastOpenedAt': serializer.toJson<DateTime>(lastOpenedAt),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  LessonProgressRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
    String? lessonId,
    String? titleId,
    int? lessonIndex,
    DateTime? lastOpenedAt,
    Value<DateTime?> completedAt = const Value.absent(),
  }) => LessonProgressRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    lessonId: lessonId ?? this.lessonId,
    titleId: titleId ?? this.titleId,
    lessonIndex: lessonIndex ?? this.lessonIndex,
    lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    completedAt: completedAt.present ? completedAt.value : this.completedAt,
  );
  LessonProgressRow copyWithCompanion(LessonProgressCompanion data) {
    return LessonProgressRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      lessonIndex: data.lessonIndex.present
          ? data.lessonIndex.value
          : this.lessonIndex,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('lessonId: $lessonId, ')
          ..write('titleId: $titleId, ')
          ..write('lessonIndex: $lessonIndex, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deleted,
    dirty,
    lessonId,
    titleId,
    lessonIndex,
    lastOpenedAt,
    completedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LessonProgressRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.lessonId == this.lessonId &&
          other.titleId == this.titleId &&
          other.lessonIndex == this.lessonIndex &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.completedAt == this.completedAt);
}

class LessonProgressCompanion extends UpdateCompanion<LessonProgressRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> lessonId;
  final Value<String> titleId;
  final Value<int> lessonIndex;
  final Value<DateTime> lastOpenedAt;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const LessonProgressCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.lessonIndex = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LessonProgressCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String lessonId,
    required String titleId,
    required int lessonIndex,
    required DateTime lastOpenedAt,
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : lessonId = Value(lessonId),
       titleId = Value(titleId),
       lessonIndex = Value(lessonIndex),
       lastOpenedAt = Value(lastOpenedAt);
  static Insertable<LessonProgressRow> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? lessonId,
    Expression<String>? titleId,
    Expression<int>? lessonIndex,
    Expression<DateTime>? lastOpenedAt,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (lessonId != null) 'lesson_id': lessonId,
      if (titleId != null) 'title_id': titleId,
      if (lessonIndex != null) 'lesson_index': lessonIndex,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LessonProgressCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? lessonId,
    Value<String>? titleId,
    Value<int>? lessonIndex,
    Value<DateTime>? lastOpenedAt,
    Value<DateTime?>? completedAt,
    Value<int>? rowid,
  }) {
    return LessonProgressCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      lessonId: lessonId ?? this.lessonId,
      titleId: titleId ?? this.titleId,
      lessonIndex: lessonIndex ?? this.lessonIndex,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $LessonProgressTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<String>(lessonId.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (lessonIndex.present) {
      map['lesson_index'] = Variable<int>(lessonIndex.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LessonProgressCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('lessonId: $lessonId, ')
          ..write('titleId: $titleId, ')
          ..write('lessonIndex: $lessonIndex, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $QuizResultsTable extends QuizResults
    with TableInfo<$QuizResultsTable, QuizResultRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizResultsTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        clientDefault: () => DateTime.now().millisecondsSinceEpoch,
      ).withConverter<DateTime>($QuizResultsTable.$converterupdatedAt);
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _syncIdMeta = const VerificationMeta('syncId');
  @override
  late final GeneratedColumn<String> syncId = GeneratedColumn<String>(
    'sync_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newInstallId,
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<int> score = GeneratedColumn<int>(
    'score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _questionIdsMeta = const VerificationMeta(
    'questionIds',
  );
  @override
  late final GeneratedColumn<String> questionIds = GeneratedColumn<String>(
    'question_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wrongIdsMeta = const VerificationMeta(
    'wrongIds',
  );
  @override
  late final GeneratedColumn<String> wrongIds = GeneratedColumn<String>(
    'wrong_ids',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentVersionMeta = const VerificationMeta(
    'contentVersion',
  );
  @override
  late final GeneratedColumn<int> contentVersion = GeneratedColumn<int>(
    'content_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _takenAtMeta = const VerificationMeta(
    'takenAt',
  );
  @override
  late final GeneratedColumn<DateTime> takenAt = GeneratedColumn<DateTime>(
    'taken_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    dirty,
    id,
    syncId,
    titleId,
    score,
    total,
    questionIds,
    wrongIds,
    contentVersion,
    takenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiz_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuizResultRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('sync_id')) {
      context.handle(
        _syncIdMeta,
        syncId.isAcceptableOrUnknown(data['sync_id']!, _syncIdMeta),
      );
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
        _scoreMeta,
        score.isAcceptableOrUnknown(data['score']!, _scoreMeta),
      );
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    if (data.containsKey('question_ids')) {
      context.handle(
        _questionIdsMeta,
        questionIds.isAcceptableOrUnknown(
          data['question_ids']!,
          _questionIdsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionIdsMeta);
    }
    if (data.containsKey('wrong_ids')) {
      context.handle(
        _wrongIdsMeta,
        wrongIds.isAcceptableOrUnknown(data['wrong_ids']!, _wrongIdsMeta),
      );
    } else if (isInserting) {
      context.missing(_wrongIdsMeta);
    }
    if (data.containsKey('content_version')) {
      context.handle(
        _contentVersionMeta,
        contentVersion.isAcceptableOrUnknown(
          data['content_version']!,
          _contentVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentVersionMeta);
    }
    if (data.containsKey('taken_at')) {
      context.handle(
        _takenAtMeta,
        takenAt.isAcceptableOrUnknown(data['taken_at']!, _takenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_takenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  QuizResultRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuizResultRow(
      updatedAt: $QuizResultsTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      syncId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      score: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}score'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
      questionIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_ids'],
      )!,
      wrongIds: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}wrong_ids'],
      )!,
      contentVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_version'],
      )!,
      takenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}taken_at'],
      )!,
    );
  }

  @override
  $QuizResultsTable createAlias(String alias) {
    return $QuizResultsTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMs();
}

class QuizResultRow extends DataClass implements Insertable<QuizResultRow> {
  /// When the user made the change (device clock, UTC). Decides conflicts.
  /// The DAOs always set it; the client default is only a fallback.
  final DateTime updatedAt;

  /// Tombstone: hidden from every read, removed once the server has it.
  final bool deleted;

  /// Changed here and not yet acknowledged by the server.
  final bool dirty;

  /// Local id, used by the result route (`?attempt=`). Not synced.
  final int id;

  /// The record id on the server: a UUID v4 made on the device.
  final String syncId;
  final String titleId;
  final int score;
  final int total;

  /// JSON list of question ids in shown order.
  final String questionIds;

  /// JSON list of the missed question ids.
  final String wrongIds;
  final int contentVersion;
  final DateTime takenAt;
  const QuizResultRow({
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
    required this.id,
    required this.syncId,
    required this.titleId,
    required this.score,
    required this.total,
    required this.questionIds,
    required this.wrongIds,
    required this.contentVersion,
    required this.takenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['updated_at'] = Variable<int>(
        $QuizResultsTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['id'] = Variable<int>(id);
    map['sync_id'] = Variable<String>(syncId);
    map['title_id'] = Variable<String>(titleId);
    map['score'] = Variable<int>(score);
    map['total'] = Variable<int>(total);
    map['question_ids'] = Variable<String>(questionIds);
    map['wrong_ids'] = Variable<String>(wrongIds);
    map['content_version'] = Variable<int>(contentVersion);
    map['taken_at'] = Variable<DateTime>(takenAt);
    return map;
  }

  QuizResultsCompanion toCompanion(bool nullToAbsent) {
    return QuizResultsCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      id: Value(id),
      syncId: Value(syncId),
      titleId: Value(titleId),
      score: Value(score),
      total: Value(total),
      questionIds: Value(questionIds),
      wrongIds: Value(wrongIds),
      contentVersion: Value(contentVersion),
      takenAt: Value(takenAt),
    );
  }

  factory QuizResultRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuizResultRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      id: serializer.fromJson<int>(json['id']),
      syncId: serializer.fromJson<String>(json['syncId']),
      titleId: serializer.fromJson<String>(json['titleId']),
      score: serializer.fromJson<int>(json['score']),
      total: serializer.fromJson<int>(json['total']),
      questionIds: serializer.fromJson<String>(json['questionIds']),
      wrongIds: serializer.fromJson<String>(json['wrongIds']),
      contentVersion: serializer.fromJson<int>(json['contentVersion']),
      takenAt: serializer.fromJson<DateTime>(json['takenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'id': serializer.toJson<int>(id),
      'syncId': serializer.toJson<String>(syncId),
      'titleId': serializer.toJson<String>(titleId),
      'score': serializer.toJson<int>(score),
      'total': serializer.toJson<int>(total),
      'questionIds': serializer.toJson<String>(questionIds),
      'wrongIds': serializer.toJson<String>(wrongIds),
      'contentVersion': serializer.toJson<int>(contentVersion),
      'takenAt': serializer.toJson<DateTime>(takenAt),
    };
  }

  QuizResultRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
    int? id,
    String? syncId,
    String? titleId,
    int? score,
    int? total,
    String? questionIds,
    String? wrongIds,
    int? contentVersion,
    DateTime? takenAt,
  }) => QuizResultRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    id: id ?? this.id,
    syncId: syncId ?? this.syncId,
    titleId: titleId ?? this.titleId,
    score: score ?? this.score,
    total: total ?? this.total,
    questionIds: questionIds ?? this.questionIds,
    wrongIds: wrongIds ?? this.wrongIds,
    contentVersion: contentVersion ?? this.contentVersion,
    takenAt: takenAt ?? this.takenAt,
  );
  QuizResultRow copyWithCompanion(QuizResultsCompanion data) {
    return QuizResultRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      id: data.id.present ? data.id.value : this.id,
      syncId: data.syncId.present ? data.syncId.value : this.syncId,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      score: data.score.present ? data.score.value : this.score,
      total: data.total.present ? data.total.value : this.total,
      questionIds: data.questionIds.present
          ? data.questionIds.value
          : this.questionIds,
      wrongIds: data.wrongIds.present ? data.wrongIds.value : this.wrongIds,
      contentVersion: data.contentVersion.present
          ? data.contentVersion.value
          : this.contentVersion,
      takenAt: data.takenAt.present ? data.takenAt.value : this.takenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuizResultRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('syncId: $syncId, ')
          ..write('titleId: $titleId, ')
          ..write('score: $score, ')
          ..write('total: $total, ')
          ..write('questionIds: $questionIds, ')
          ..write('wrongIds: $wrongIds, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('takenAt: $takenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deleted,
    dirty,
    id,
    syncId,
    titleId,
    score,
    total,
    questionIds,
    wrongIds,
    contentVersion,
    takenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizResultRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.id == this.id &&
          other.syncId == this.syncId &&
          other.titleId == this.titleId &&
          other.score == this.score &&
          other.total == this.total &&
          other.questionIds == this.questionIds &&
          other.wrongIds == this.wrongIds &&
          other.contentVersion == this.contentVersion &&
          other.takenAt == this.takenAt);
}

class QuizResultsCompanion extends UpdateCompanion<QuizResultRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<int> id;
  final Value<String> syncId;
  final Value<String> titleId;
  final Value<int> score;
  final Value<int> total;
  final Value<String> questionIds;
  final Value<String> wrongIds;
  final Value<int> contentVersion;
  final Value<DateTime> takenAt;
  const QuizResultsCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.syncId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.score = const Value.absent(),
    this.total = const Value.absent(),
    this.questionIds = const Value.absent(),
    this.wrongIds = const Value.absent(),
    this.contentVersion = const Value.absent(),
    this.takenAt = const Value.absent(),
  });
  QuizResultsCompanion.insert({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.id = const Value.absent(),
    this.syncId = const Value.absent(),
    required String titleId,
    required int score,
    required int total,
    required String questionIds,
    required String wrongIds,
    required int contentVersion,
    required DateTime takenAt,
  }) : titleId = Value(titleId),
       score = Value(score),
       total = Value(total),
       questionIds = Value(questionIds),
       wrongIds = Value(wrongIds),
       contentVersion = Value(contentVersion),
       takenAt = Value(takenAt);
  static Insertable<QuizResultRow> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<int>? id,
    Expression<String>? syncId,
    Expression<String>? titleId,
    Expression<int>? score,
    Expression<int>? total,
    Expression<String>? questionIds,
    Expression<String>? wrongIds,
    Expression<int>? contentVersion,
    Expression<DateTime>? takenAt,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (id != null) 'id': id,
      if (syncId != null) 'sync_id': syncId,
      if (titleId != null) 'title_id': titleId,
      if (score != null) 'score': score,
      if (total != null) 'total': total,
      if (questionIds != null) 'question_ids': questionIds,
      if (wrongIds != null) 'wrong_ids': wrongIds,
      if (contentVersion != null) 'content_version': contentVersion,
      if (takenAt != null) 'taken_at': takenAt,
    });
  }

  QuizResultsCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<int>? id,
    Value<String>? syncId,
    Value<String>? titleId,
    Value<int>? score,
    Value<int>? total,
    Value<String>? questionIds,
    Value<String>? wrongIds,
    Value<int>? contentVersion,
    Value<DateTime>? takenAt,
  }) {
    return QuizResultsCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      id: id ?? this.id,
      syncId: syncId ?? this.syncId,
      titleId: titleId ?? this.titleId,
      score: score ?? this.score,
      total: total ?? this.total,
      questionIds: questionIds ?? this.questionIds,
      wrongIds: wrongIds ?? this.wrongIds,
      contentVersion: contentVersion ?? this.contentVersion,
      takenAt: takenAt ?? this.takenAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $QuizResultsTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (syncId.present) {
      map['sync_id'] = Variable<String>(syncId.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (score.present) {
      map['score'] = Variable<int>(score.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (questionIds.present) {
      map['question_ids'] = Variable<String>(questionIds.value);
    }
    if (wrongIds.present) {
      map['wrong_ids'] = Variable<String>(wrongIds.value);
    }
    if (contentVersion.present) {
      map['content_version'] = Variable<int>(contentVersion.value);
    }
    if (takenAt.present) {
      map['taken_at'] = Variable<DateTime>(takenAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizResultsCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('id: $id, ')
          ..write('syncId: $syncId, ')
          ..write('titleId: $titleId, ')
          ..write('score: $score, ')
          ..write('total: $total, ')
          ..write('questionIds: $questionIds, ')
          ..write('wrongIds: $wrongIds, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('takenAt: $takenAt')
          ..write(')'))
        .toString();
  }
}

class $QuizSeenTable extends QuizSeen
    with TableInfo<$QuizSeenTable, QuizSeenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $QuizSeenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _questionIdMeta = const VerificationMeta(
    'questionId',
  );
  @override
  late final GeneratedColumn<String> questionId = GeneratedColumn<String>(
    'question_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seenAtMeta = const VerificationMeta('seenAt');
  @override
  late final GeneratedColumn<DateTime> seenAt = GeneratedColumn<DateTime>(
    'seen_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [questionId, titleId, seenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'quiz_seen';
  @override
  VerificationContext validateIntegrity(
    Insertable<QuizSeenRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('question_id')) {
      context.handle(
        _questionIdMeta,
        questionId.isAcceptableOrUnknown(data['question_id']!, _questionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_questionIdMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('seen_at')) {
      context.handle(
        _seenAtMeta,
        seenAt.isAcceptableOrUnknown(data['seen_at']!, _seenAtMeta),
      );
    } else if (isInserting) {
      context.missing(_seenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {questionId};
  @override
  QuizSeenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return QuizSeenRow(
      questionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      seenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}seen_at'],
      )!,
    );
  }

  @override
  $QuizSeenTable createAlias(String alias) {
    return $QuizSeenTable(attachedDatabase, alias);
  }
}

class QuizSeenRow extends DataClass implements Insertable<QuizSeenRow> {
  final String questionId;
  final String titleId;
  final DateTime seenAt;
  const QuizSeenRow({
    required this.questionId,
    required this.titleId,
    required this.seenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['question_id'] = Variable<String>(questionId);
    map['title_id'] = Variable<String>(titleId);
    map['seen_at'] = Variable<DateTime>(seenAt);
    return map;
  }

  QuizSeenCompanion toCompanion(bool nullToAbsent) {
    return QuizSeenCompanion(
      questionId: Value(questionId),
      titleId: Value(titleId),
      seenAt: Value(seenAt),
    );
  }

  factory QuizSeenRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return QuizSeenRow(
      questionId: serializer.fromJson<String>(json['questionId']),
      titleId: serializer.fromJson<String>(json['titleId']),
      seenAt: serializer.fromJson<DateTime>(json['seenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'questionId': serializer.toJson<String>(questionId),
      'titleId': serializer.toJson<String>(titleId),
      'seenAt': serializer.toJson<DateTime>(seenAt),
    };
  }

  QuizSeenRow copyWith({
    String? questionId,
    String? titleId,
    DateTime? seenAt,
  }) => QuizSeenRow(
    questionId: questionId ?? this.questionId,
    titleId: titleId ?? this.titleId,
    seenAt: seenAt ?? this.seenAt,
  );
  QuizSeenRow copyWithCompanion(QuizSeenCompanion data) {
    return QuizSeenRow(
      questionId: data.questionId.present
          ? data.questionId.value
          : this.questionId,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      seenAt: data.seenAt.present ? data.seenAt.value : this.seenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('QuizSeenRow(')
          ..write('questionId: $questionId, ')
          ..write('titleId: $titleId, ')
          ..write('seenAt: $seenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(questionId, titleId, seenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is QuizSeenRow &&
          other.questionId == this.questionId &&
          other.titleId == this.titleId &&
          other.seenAt == this.seenAt);
}

class QuizSeenCompanion extends UpdateCompanion<QuizSeenRow> {
  final Value<String> questionId;
  final Value<String> titleId;
  final Value<DateTime> seenAt;
  final Value<int> rowid;
  const QuizSeenCompanion({
    this.questionId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.seenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  QuizSeenCompanion.insert({
    required String questionId,
    required String titleId,
    required DateTime seenAt,
    this.rowid = const Value.absent(),
  }) : questionId = Value(questionId),
       titleId = Value(titleId),
       seenAt = Value(seenAt);
  static Insertable<QuizSeenRow> custom({
    Expression<String>? questionId,
    Expression<String>? titleId,
    Expression<DateTime>? seenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (questionId != null) 'question_id': questionId,
      if (titleId != null) 'title_id': titleId,
      if (seenAt != null) 'seen_at': seenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  QuizSeenCompanion copyWith({
    Value<String>? questionId,
    Value<String>? titleId,
    Value<DateTime>? seenAt,
    Value<int>? rowid,
  }) {
    return QuizSeenCompanion(
      questionId: questionId ?? this.questionId,
      titleId: titleId ?? this.titleId,
      seenAt: seenAt ?? this.seenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (questionId.present) {
      map['question_id'] = Variable<String>(questionId.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (seenAt.present) {
      map['seen_at'] = Variable<DateTime>(seenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('QuizSeenCompanion(')
          ..write('questionId: $questionId, ')
          ..write('titleId: $titleId, ')
          ..write('seenAt: $seenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FeedStateTable extends FeedState
    with TableInfo<$FeedStateTable, FeedStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FeedStateTable(this.attachedDatabase, [this._alias]);
  @override
  late final GeneratedColumnWithTypeConverter<DateTime, int> updatedAt =
      GeneratedColumn<int>(
        'updated_at',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      ).withConverter<DateTime>($FeedStateTable.$converterupdatedAt);
  static const VerificationMeta _deletedMeta = const VerificationMeta(
    'deleted',
  );
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
    'deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _dirtyMeta = const VerificationMeta('dirty');
  @override
  late final GeneratedColumn<bool> dirty = GeneratedColumn<bool>(
    'dirty',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dirty" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _factIdMeta = const VerificationMeta('factId');
  @override
  late final GeneratedColumn<String> factId = GeneratedColumn<String>(
    'fact_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _savedMeta = const VerificationMeta('saved');
  @override
  late final GeneratedColumn<bool> saved = GeneratedColumn<bool>(
    'saved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("saved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _reactionMeta = const VerificationMeta(
    'reaction',
  );
  @override
  late final GeneratedColumn<int> reaction = GeneratedColumn<int>(
    'reaction',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _seenAtMeta = const VerificationMeta('seenAt');
  @override
  late final GeneratedColumn<DateTime> seenAt = GeneratedColumn<DateTime>(
    'seen_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    updatedAt,
    deleted,
    dirty,
    factId,
    titleId,
    saved,
    reaction,
    seenAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'feed_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<FeedStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('deleted')) {
      context.handle(
        _deletedMeta,
        deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta),
      );
    }
    if (data.containsKey('dirty')) {
      context.handle(
        _dirtyMeta,
        dirty.isAcceptableOrUnknown(data['dirty']!, _dirtyMeta),
      );
    }
    if (data.containsKey('fact_id')) {
      context.handle(
        _factIdMeta,
        factId.isAcceptableOrUnknown(data['fact_id']!, _factIdMeta),
      );
    } else if (isInserting) {
      context.missing(_factIdMeta);
    }
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('saved')) {
      context.handle(
        _savedMeta,
        saved.isAcceptableOrUnknown(data['saved']!, _savedMeta),
      );
    }
    if (data.containsKey('reaction')) {
      context.handle(
        _reactionMeta,
        reaction.isAcceptableOrUnknown(data['reaction']!, _reactionMeta),
      );
    }
    if (data.containsKey('seen_at')) {
      context.handle(
        _seenAtMeta,
        seenAt.isAcceptableOrUnknown(data['seen_at']!, _seenAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {factId};
  @override
  FeedStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FeedStateRow(
      updatedAt: $FeedStateTable.$converterupdatedAt.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.int,
          data['${effectivePrefix}updated_at'],
        )!,
      ),
      deleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}deleted'],
      )!,
      dirty: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dirty'],
      )!,
      factId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fact_id'],
      )!,
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      saved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}saved'],
      )!,
      reaction: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reaction'],
      )!,
      seenAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}seen_at'],
      ),
    );
  }

  @override
  $FeedStateTable createAlias(String alias) {
    return $FeedStateTable(attachedDatabase, alias);
  }

  static TypeConverter<DateTime, int> $converterupdatedAt = const EpochMs();
}

class FeedStateRow extends DataClass implements Insertable<FeedStateRow> {
  /// Required here (it was in v1), unlike the other tables' fallback.
  final DateTime updatedAt;

  /// Tombstone: hidden from every read, removed once the server has it.
  final bool deleted;

  /// Changed here and not yet acknowledged by the server.
  final bool dirty;
  final String factId;
  final String titleId;
  final bool saved;

  /// -1, 0, 1.
  final int reaction;
  final DateTime? seenAt;
  const FeedStateRow({
    required this.updatedAt,
    required this.deleted,
    required this.dirty,
    required this.factId,
    required this.titleId,
    required this.saved,
    required this.reaction,
    this.seenAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    {
      map['updated_at'] = Variable<int>(
        $FeedStateTable.$converterupdatedAt.toSql(updatedAt),
      );
    }
    map['deleted'] = Variable<bool>(deleted);
    map['dirty'] = Variable<bool>(dirty);
    map['fact_id'] = Variable<String>(factId);
    map['title_id'] = Variable<String>(titleId);
    map['saved'] = Variable<bool>(saved);
    map['reaction'] = Variable<int>(reaction);
    if (!nullToAbsent || seenAt != null) {
      map['seen_at'] = Variable<DateTime>(seenAt);
    }
    return map;
  }

  FeedStateCompanion toCompanion(bool nullToAbsent) {
    return FeedStateCompanion(
      updatedAt: Value(updatedAt),
      deleted: Value(deleted),
      dirty: Value(dirty),
      factId: Value(factId),
      titleId: Value(titleId),
      saved: Value(saved),
      reaction: Value(reaction),
      seenAt: seenAt == null && nullToAbsent
          ? const Value.absent()
          : Value(seenAt),
    );
  }

  factory FeedStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FeedStateRow(
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dirty: serializer.fromJson<bool>(json['dirty']),
      factId: serializer.fromJson<String>(json['factId']),
      titleId: serializer.fromJson<String>(json['titleId']),
      saved: serializer.fromJson<bool>(json['saved']),
      reaction: serializer.fromJson<int>(json['reaction']),
      seenAt: serializer.fromJson<DateTime?>(json['seenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dirty': serializer.toJson<bool>(dirty),
      'factId': serializer.toJson<String>(factId),
      'titleId': serializer.toJson<String>(titleId),
      'saved': serializer.toJson<bool>(saved),
      'reaction': serializer.toJson<int>(reaction),
      'seenAt': serializer.toJson<DateTime?>(seenAt),
    };
  }

  FeedStateRow copyWith({
    DateTime? updatedAt,
    bool? deleted,
    bool? dirty,
    String? factId,
    String? titleId,
    bool? saved,
    int? reaction,
    Value<DateTime?> seenAt = const Value.absent(),
  }) => FeedStateRow(
    updatedAt: updatedAt ?? this.updatedAt,
    deleted: deleted ?? this.deleted,
    dirty: dirty ?? this.dirty,
    factId: factId ?? this.factId,
    titleId: titleId ?? this.titleId,
    saved: saved ?? this.saved,
    reaction: reaction ?? this.reaction,
    seenAt: seenAt.present ? seenAt.value : this.seenAt,
  );
  FeedStateRow copyWithCompanion(FeedStateCompanion data) {
    return FeedStateRow(
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dirty: data.dirty.present ? data.dirty.value : this.dirty,
      factId: data.factId.present ? data.factId.value : this.factId,
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      saved: data.saved.present ? data.saved.value : this.saved,
      reaction: data.reaction.present ? data.reaction.value : this.reaction,
      seenAt: data.seenAt.present ? data.seenAt.value : this.seenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FeedStateRow(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('factId: $factId, ')
          ..write('titleId: $titleId, ')
          ..write('saved: $saved, ')
          ..write('reaction: $reaction, ')
          ..write('seenAt: $seenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    updatedAt,
    deleted,
    dirty,
    factId,
    titleId,
    saved,
    reaction,
    seenAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FeedStateRow &&
          other.updatedAt == this.updatedAt &&
          other.deleted == this.deleted &&
          other.dirty == this.dirty &&
          other.factId == this.factId &&
          other.titleId == this.titleId &&
          other.saved == this.saved &&
          other.reaction == this.reaction &&
          other.seenAt == this.seenAt);
}

class FeedStateCompanion extends UpdateCompanion<FeedStateRow> {
  final Value<DateTime> updatedAt;
  final Value<bool> deleted;
  final Value<bool> dirty;
  final Value<String> factId;
  final Value<String> titleId;
  final Value<bool> saved;
  final Value<int> reaction;
  final Value<DateTime?> seenAt;
  final Value<int> rowid;
  const FeedStateCompanion({
    this.updatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    this.factId = const Value.absent(),
    this.titleId = const Value.absent(),
    this.saved = const Value.absent(),
    this.reaction = const Value.absent(),
    this.seenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FeedStateCompanion.insert({
    required DateTime updatedAt,
    this.deleted = const Value.absent(),
    this.dirty = const Value.absent(),
    required String factId,
    required String titleId,
    this.saved = const Value.absent(),
    this.reaction = const Value.absent(),
    this.seenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : updatedAt = Value(updatedAt),
       factId = Value(factId),
       titleId = Value(titleId);
  static Insertable<FeedStateRow> custom({
    Expression<int>? updatedAt,
    Expression<bool>? deleted,
    Expression<bool>? dirty,
    Expression<String>? factId,
    Expression<String>? titleId,
    Expression<bool>? saved,
    Expression<int>? reaction,
    Expression<DateTime>? seenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dirty != null) 'dirty': dirty,
      if (factId != null) 'fact_id': factId,
      if (titleId != null) 'title_id': titleId,
      if (saved != null) 'saved': saved,
      if (reaction != null) 'reaction': reaction,
      if (seenAt != null) 'seen_at': seenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FeedStateCompanion copyWith({
    Value<DateTime>? updatedAt,
    Value<bool>? deleted,
    Value<bool>? dirty,
    Value<String>? factId,
    Value<String>? titleId,
    Value<bool>? saved,
    Value<int>? reaction,
    Value<DateTime?>? seenAt,
    Value<int>? rowid,
  }) {
    return FeedStateCompanion(
      updatedAt: updatedAt ?? this.updatedAt,
      deleted: deleted ?? this.deleted,
      dirty: dirty ?? this.dirty,
      factId: factId ?? this.factId,
      titleId: titleId ?? this.titleId,
      saved: saved ?? this.saved,
      reaction: reaction ?? this.reaction,
      seenAt: seenAt ?? this.seenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(
        $FeedStateTable.$converterupdatedAt.toSql(updatedAt.value),
      );
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dirty.present) {
      map['dirty'] = Variable<bool>(dirty.value);
    }
    if (factId.present) {
      map['fact_id'] = Variable<String>(factId.value);
    }
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (saved.present) {
      map['saved'] = Variable<bool>(saved.value);
    }
    if (reaction.present) {
      map['reaction'] = Variable<int>(reaction.value);
    }
    if (seenAt.present) {
      map['seen_at'] = Variable<DateTime>(seenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FeedStateCompanion(')
          ..write('updatedAt: $updatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dirty: $dirty, ')
          ..write('factId: $factId, ')
          ..write('titleId: $titleId, ')
          ..write('saved: $saved, ')
          ..write('reaction: $reaction, ')
          ..write('seenAt: $seenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedDocsTable extends CachedDocs
    with TableInfo<$CachedDocsTable, CachedDocRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedDocsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, payload, etag, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_docs';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedDocRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  CachedDocRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedDocRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedDocsTable createAlias(String alias) {
    return $CachedDocsTable(attachedDatabase, alias);
  }
}

class CachedDocRow extends DataClass implements Insertable<CachedDocRow> {
  final String key;
  final String payload;
  final String? etag;
  final DateTime fetchedAt;
  const CachedDocRow({
    required this.key,
    required this.payload,
    this.etag,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['payload'] = Variable<String>(payload);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedDocsCompanion toCompanion(bool nullToAbsent) {
    return CachedDocsCompanion(
      key: Value(key),
      payload: Value(payload),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedDocRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedDocRow(
      key: serializer.fromJson<String>(json['key']),
      payload: serializer.fromJson<String>(json['payload']),
      etag: serializer.fromJson<String?>(json['etag']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'payload': serializer.toJson<String>(payload),
      'etag': serializer.toJson<String?>(etag),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedDocRow copyWith({
    String? key,
    String? payload,
    Value<String?> etag = const Value.absent(),
    DateTime? fetchedAt,
  }) => CachedDocRow(
    key: key ?? this.key,
    payload: payload ?? this.payload,
    etag: etag.present ? etag.value : this.etag,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedDocRow copyWithCompanion(CachedDocsCompanion data) {
    return CachedDocRow(
      key: data.key.present ? data.key.value : this.key,
      payload: data.payload.present ? data.payload.value : this.payload,
      etag: data.etag.present ? data.etag.value : this.etag,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocRow(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('etag: $etag, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, payload, etag, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedDocRow &&
          other.key == this.key &&
          other.payload == this.payload &&
          other.etag == this.etag &&
          other.fetchedAt == this.fetchedAt);
}

class CachedDocsCompanion extends UpdateCompanion<CachedDocRow> {
  final Value<String> key;
  final Value<String> payload;
  final Value<String?> etag;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedDocsCompanion({
    this.key = const Value.absent(),
    this.payload = const Value.absent(),
    this.etag = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedDocsCompanion.insert({
    required String key,
    required String payload,
    this.etag = const Value.absent(),
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       payload = Value(payload),
       fetchedAt = Value(fetchedAt);
  static Insertable<CachedDocRow> custom({
    Expression<String>? key,
    Expression<String>? payload,
    Expression<String>? etag,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (payload != null) 'payload': payload,
      if (etag != null) 'etag': etag,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedDocsCompanion copyWith({
    Value<String>? key,
    Value<String>? payload,
    Value<String?>? etag,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return CachedDocsCompanion(
      key: key ?? this.key,
      payload: payload ?? this.payload,
      etag: etag ?? this.etag,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedDocsCompanion(')
          ..write('key: $key, ')
          ..write('payload: $payload, ')
          ..write('etag: $etag, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedTitlesTable extends CachedTitles
    with TableInfo<$CachedTitlesTable, CachedTitleRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedTitlesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _titleIdMeta = const VerificationMeta(
    'titleId',
  );
  @override
  late final GeneratedColumn<String> titleId = GeneratedColumn<String>(
    'title_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _contentVersionMeta = const VerificationMeta(
    'contentVersion',
  );
  @override
  late final GeneratedColumn<int> contentVersion = GeneratedColumn<int>(
    'content_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _etagMeta = const VerificationMeta('etag');
  @override
  late final GeneratedColumn<String> etag = GeneratedColumn<String>(
    'etag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    titleId,
    payload,
    contentVersion,
    etag,
    fetchedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_titles';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedTitleRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('title_id')) {
      context.handle(
        _titleIdMeta,
        titleId.isAcceptableOrUnknown(data['title_id']!, _titleIdMeta),
      );
    } else if (isInserting) {
      context.missing(_titleIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('content_version')) {
      context.handle(
        _contentVersionMeta,
        contentVersion.isAcceptableOrUnknown(
          data['content_version']!,
          _contentVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentVersionMeta);
    }
    if (data.containsKey('etag')) {
      context.handle(
        _etagMeta,
        etag.isAcceptableOrUnknown(data['etag']!, _etagMeta),
      );
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {titleId};
  @override
  CachedTitleRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedTitleRow(
      titleId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      contentVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}content_version'],
      )!,
      etag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}etag'],
      ),
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedTitlesTable createAlias(String alias) {
    return $CachedTitlesTable(attachedDatabase, alias);
  }
}

class CachedTitleRow extends DataClass implements Insertable<CachedTitleRow> {
  final String titleId;
  final String payload;
  final int contentVersion;
  final String? etag;
  final DateTime fetchedAt;
  const CachedTitleRow({
    required this.titleId,
    required this.payload,
    required this.contentVersion,
    this.etag,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['title_id'] = Variable<String>(titleId);
    map['payload'] = Variable<String>(payload);
    map['content_version'] = Variable<int>(contentVersion);
    if (!nullToAbsent || etag != null) {
      map['etag'] = Variable<String>(etag);
    }
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedTitlesCompanion toCompanion(bool nullToAbsent) {
    return CachedTitlesCompanion(
      titleId: Value(titleId),
      payload: Value(payload),
      contentVersion: Value(contentVersion),
      etag: etag == null && nullToAbsent ? const Value.absent() : Value(etag),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedTitleRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedTitleRow(
      titleId: serializer.fromJson<String>(json['titleId']),
      payload: serializer.fromJson<String>(json['payload']),
      contentVersion: serializer.fromJson<int>(json['contentVersion']),
      etag: serializer.fromJson<String?>(json['etag']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'titleId': serializer.toJson<String>(titleId),
      'payload': serializer.toJson<String>(payload),
      'contentVersion': serializer.toJson<int>(contentVersion),
      'etag': serializer.toJson<String?>(etag),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedTitleRow copyWith({
    String? titleId,
    String? payload,
    int? contentVersion,
    Value<String?> etag = const Value.absent(),
    DateTime? fetchedAt,
  }) => CachedTitleRow(
    titleId: titleId ?? this.titleId,
    payload: payload ?? this.payload,
    contentVersion: contentVersion ?? this.contentVersion,
    etag: etag.present ? etag.value : this.etag,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedTitleRow copyWithCompanion(CachedTitlesCompanion data) {
    return CachedTitleRow(
      titleId: data.titleId.present ? data.titleId.value : this.titleId,
      payload: data.payload.present ? data.payload.value : this.payload,
      contentVersion: data.contentVersion.present
          ? data.contentVersion.value
          : this.contentVersion,
      etag: data.etag.present ? data.etag.value : this.etag,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedTitleRow(')
          ..write('titleId: $titleId, ')
          ..write('payload: $payload, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('etag: $etag, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(titleId, payload, contentVersion, etag, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedTitleRow &&
          other.titleId == this.titleId &&
          other.payload == this.payload &&
          other.contentVersion == this.contentVersion &&
          other.etag == this.etag &&
          other.fetchedAt == this.fetchedAt);
}

class CachedTitlesCompanion extends UpdateCompanion<CachedTitleRow> {
  final Value<String> titleId;
  final Value<String> payload;
  final Value<int> contentVersion;
  final Value<String?> etag;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedTitlesCompanion({
    this.titleId = const Value.absent(),
    this.payload = const Value.absent(),
    this.contentVersion = const Value.absent(),
    this.etag = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedTitlesCompanion.insert({
    required String titleId,
    required String payload,
    required int contentVersion,
    this.etag = const Value.absent(),
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : titleId = Value(titleId),
       payload = Value(payload),
       contentVersion = Value(contentVersion),
       fetchedAt = Value(fetchedAt);
  static Insertable<CachedTitleRow> custom({
    Expression<String>? titleId,
    Expression<String>? payload,
    Expression<int>? contentVersion,
    Expression<String>? etag,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (titleId != null) 'title_id': titleId,
      if (payload != null) 'payload': payload,
      if (contentVersion != null) 'content_version': contentVersion,
      if (etag != null) 'etag': etag,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedTitlesCompanion copyWith({
    Value<String>? titleId,
    Value<String>? payload,
    Value<int>? contentVersion,
    Value<String?>? etag,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return CachedTitlesCompanion(
      titleId: titleId ?? this.titleId,
      payload: payload ?? this.payload,
      contentVersion: contentVersion ?? this.contentVersion,
      etag: etag ?? this.etag,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (titleId.present) {
      map['title_id'] = Variable<String>(titleId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (contentVersion.present) {
      map['content_version'] = Variable<int>(contentVersion.value);
    }
    if (etag.present) {
      map['etag'] = Variable<String>(etag.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedTitlesCompanion(')
          ..write('titleId: $titleId, ')
          ..write('payload: $payload, ')
          ..write('contentVersion: $contentVersion, ')
          ..write('etag: $etag, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateTable extends SyncState
    with TableInfo<$SyncStateTable, SyncStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SyncStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateRow(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SyncStateTable createAlias(String alias) {
    return $SyncStateTable(attachedDatabase, alias);
  }
}

class SyncStateRow extends DataClass implements Insertable<SyncStateRow> {
  final String key;
  final String value;
  const SyncStateRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SyncStateCompanion toCompanion(bool nullToAbsent) {
    return SyncStateCompanion(key: Value(key), value: Value(value));
  }

  factory SyncStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SyncStateRow copyWith({String? key, String? value}) =>
      SyncStateRow(key: key ?? this.key, value: value ?? this.value);
  SyncStateRow copyWithCompanion(SyncStateCompanion data) {
    return SyncStateRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateRow &&
          other.key == this.key &&
          other.value == this.value);
}

class SyncStateCompanion extends UpdateCompanion<SyncStateRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SyncStateCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SyncStateRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SyncStateCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SettingsTable settings = $SettingsTable(this);
  late final $InterestsTable interests = $InterestsTable(this);
  late final $StudyListTable studyList = $StudyListTable(this);
  late final $RatingsTable ratings = $RatingsTable(this);
  late final $LessonProgressTable lessonProgress = $LessonProgressTable(this);
  late final $QuizResultsTable quizResults = $QuizResultsTable(this);
  late final $QuizSeenTable quizSeen = $QuizSeenTable(this);
  late final $FeedStateTable feedState = $FeedStateTable(this);
  late final $CachedDocsTable cachedDocs = $CachedDocsTable(this);
  late final $CachedTitlesTable cachedTitles = $CachedTitlesTable(this);
  late final $SyncStateTable syncState = $SyncStateTable(this);
  late final Index lessonProgressTitle = Index(
    'lesson_progress_title',
    'CREATE INDEX lesson_progress_title ON lesson_progress (title_id)',
  );
  late final Index quizSeenTitle = Index(
    'quiz_seen_title',
    'CREATE INDEX quiz_seen_title ON quiz_seen (title_id)',
  );
  late final Index feedStateTitle = Index(
    'feed_state_title',
    'CREATE INDEX feed_state_title ON feed_state (title_id)',
  );
  late final SettingsDao settingsDao = SettingsDao(this as AppDatabase);
  late final UserStateDao userStateDao = UserStateDao(this as AppDatabase);
  late final ContentCacheDao contentCacheDao = ContentCacheDao(
    this as AppDatabase,
  );
  late final SyncDao syncDao = SyncDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settings,
    interests,
    studyList,
    ratings,
    lessonProgress,
    quizResults,
    quizSeen,
    feedState,
    cachedDocs,
    cachedTitles,
    syncState,
    lessonProgressTitle,
    quizSeenTitle,
    feedStateTitle,
  ];
}

typedef $$SettingsTableCreateCompanionBuilder = SettingsCompanion Function({
  required String key,
  required String value,
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int> rowid,
});
typedef $$SettingsTableUpdateCompanionBuilder = SettingsCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<int> rowid,
});

class $$SettingsTableFilterComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SettingsTable> {
  $$SettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);
}

class $$SettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SettingsTable,
          SettingRow,
          $$SettingsTableFilterComposer,
          $$SettingsTableOrderingComposer,
          $$SettingsTableAnnotationComposer,
          $$SettingsTableCreateCompanionBuilder,
          $$SettingsTableUpdateCompanionBuilder,
          (
            SettingRow,
            BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>,
          ),
          SettingRow,
          PrefetchHooks Function()
        > {
  $$SettingsTableTableManager(_$AppDatabase db, $SettingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SettingsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SettingsTable, SettingRow>(table),
                  BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SettingsTable,
      SettingRow,
      $$SettingsTableFilterComposer,
      $$SettingsTableOrderingComposer,
      $$SettingsTableAnnotationComposer,
      $$SettingsTableCreateCompanionBuilder,
      $$SettingsTableUpdateCompanionBuilder,
      (SettingRow, BaseReferences<_$AppDatabase, $SettingsTable, SettingRow>),
      SettingRow,
      PrefetchHooks Function()
    >;
typedef $$InterestsTableCreateCompanionBuilder = InterestsCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  required String titleId,
  required String kind,
  required int position,
  required DateTime pickedAt,
  Value<int> rowid,
});
typedef $$InterestsTableUpdateCompanionBuilder = InterestsCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<String> titleId,
  Value<String> kind,
  Value<int> position,
  Value<DateTime> pickedAt,
  Value<int> rowid,
});

class $$InterestsTableFilterComposer
    extends Composer<_$AppDatabase, $InterestsTable> {
  $$InterestsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get pickedAt => $composableBuilder(
    column: $table.pickedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InterestsTableOrderingComposer
    extends Composer<_$AppDatabase, $InterestsTable> {
  $$InterestsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get position => $composableBuilder(
    column: $table.position,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get pickedAt => $composableBuilder(
    column: $table.pickedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InterestsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InterestsTable> {
  $$InterestsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<DateTime> get pickedAt =>
      $composableBuilder(column: $table.pickedAt, builder: (column) => column);
}

class $$InterestsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InterestsTable,
          InterestRow,
          $$InterestsTableFilterComposer,
          $$InterestsTableOrderingComposer,
          $$InterestsTableAnnotationComposer,
          $$InterestsTableCreateCompanionBuilder,
          $$InterestsTableUpdateCompanionBuilder,
          (
            InterestRow,
            BaseReferences<_$AppDatabase, $InterestsTable, InterestRow>,
          ),
          InterestRow,
          PrefetchHooks Function()
        > {
  $$InterestsTableTableManager(_$AppDatabase db, $InterestsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InterestsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InterestsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InterestsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int> position = const Value.absent(),
                Value<DateTime> pickedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InterestsCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                titleId: titleId,
                kind: kind,
                position: position,
                pickedAt: pickedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String titleId,
                required String kind,
                required int position,
                required DateTime pickedAt,
                Value<int> rowid = const Value.absent(),
              }) => InterestsCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                titleId: titleId,
                kind: kind,
                position: position,
                pickedAt: pickedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InterestsTable, InterestRow>(table),
                  BaseReferences<_$AppDatabase, $InterestsTable, InterestRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InterestsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InterestsTable,
      InterestRow,
      $$InterestsTableFilterComposer,
      $$InterestsTableOrderingComposer,
      $$InterestsTableAnnotationComposer,
      $$InterestsTableCreateCompanionBuilder,
      $$InterestsTableUpdateCompanionBuilder,
      (
        InterestRow,
        BaseReferences<_$AppDatabase, $InterestsTable, InterestRow>,
      ),
      InterestRow,
      PrefetchHooks Function()
    >;
typedef $$StudyListTableCreateCompanionBuilder = StudyListCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  required String titleId,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$StudyListTableUpdateCompanionBuilder = StudyListCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<String> titleId,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

class $$StudyListTableFilterComposer
    extends Composer<_$AppDatabase, $StudyListTable> {
  $$StudyListTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StudyListTableOrderingComposer
    extends Composer<_$AppDatabase, $StudyListTable> {
  $$StudyListTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudyListTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudyListTable> {
  $$StudyListTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$StudyListTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudyListTable,
          StudyItemRow,
          $$StudyListTableFilterComposer,
          $$StudyListTableOrderingComposer,
          $$StudyListTableAnnotationComposer,
          $$StudyListTableCreateCompanionBuilder,
          $$StudyListTableUpdateCompanionBuilder,
          (
            StudyItemRow,
            BaseReferences<_$AppDatabase, $StudyListTable, StudyItemRow>,
          ),
          StudyItemRow,
          PrefetchHooks Function()
        > {
  $$StudyListTableTableManager(_$AppDatabase db, $StudyListTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudyListTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudyListTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudyListTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StudyListCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                titleId: titleId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String titleId,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => StudyListCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                titleId: titleId,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StudyListTable, StudyItemRow>(table),
                  BaseReferences<_$AppDatabase, $StudyListTable, StudyItemRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StudyListTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudyListTable,
      StudyItemRow,
      $$StudyListTableFilterComposer,
      $$StudyListTableOrderingComposer,
      $$StudyListTableAnnotationComposer,
      $$StudyListTableCreateCompanionBuilder,
      $$StudyListTableUpdateCompanionBuilder,
      (
        StudyItemRow,
        BaseReferences<_$AppDatabase, $StudyListTable, StudyItemRow>,
      ),
      StudyItemRow,
      PrefetchHooks Function()
    >;
typedef $$RatingsTableCreateCompanionBuilder = RatingsCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  required String titleId,
  required int value,
  required DateTime ratedAt,
  Value<int> rowid,
});
typedef $$RatingsTableUpdateCompanionBuilder = RatingsCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<String> titleId,
  Value<int> value,
  Value<DateTime> ratedAt,
  Value<int> rowid,
});

class $$RatingsTableFilterComposer
    extends Composer<_$AppDatabase, $RatingsTable> {
  $$RatingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ratedAt => $composableBuilder(
    column: $table.ratedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RatingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RatingsTable> {
  $$RatingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ratedAt => $composableBuilder(
    column: $table.ratedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RatingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RatingsTable> {
  $$RatingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get ratedAt =>
      $composableBuilder(column: $table.ratedAt, builder: (column) => column);
}

class $$RatingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RatingsTable,
          RatingRow,
          $$RatingsTableFilterComposer,
          $$RatingsTableOrderingComposer,
          $$RatingsTableAnnotationComposer,
          $$RatingsTableCreateCompanionBuilder,
          $$RatingsTableUpdateCompanionBuilder,
          (RatingRow, BaseReferences<_$AppDatabase, $RatingsTable, RatingRow>),
          RatingRow,
          PrefetchHooks Function()
        > {
  $$RatingsTableTableManager(_$AppDatabase db, $RatingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RatingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RatingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RatingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<int> value = const Value.absent(),
                Value<DateTime> ratedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RatingsCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                titleId: titleId,
                value: value,
                ratedAt: ratedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String titleId,
                required int value,
                required DateTime ratedAt,
                Value<int> rowid = const Value.absent(),
              }) => RatingsCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                titleId: titleId,
                value: value,
                ratedAt: ratedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RatingsTable, RatingRow>(table),
                  BaseReferences<_$AppDatabase, $RatingsTable, RatingRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RatingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RatingsTable,
      RatingRow,
      $$RatingsTableFilterComposer,
      $$RatingsTableOrderingComposer,
      $$RatingsTableAnnotationComposer,
      $$RatingsTableCreateCompanionBuilder,
      $$RatingsTableUpdateCompanionBuilder,
      (RatingRow, BaseReferences<_$AppDatabase, $RatingsTable, RatingRow>),
      RatingRow,
      PrefetchHooks Function()
    >;
typedef $$LessonProgressTableCreateCompanionBuilder =
    LessonProgressCompanion Function({
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<bool> dirty,
      required String lessonId,
      required String titleId,
      required int lessonIndex,
      required DateTime lastOpenedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });
typedef $$LessonProgressTableUpdateCompanionBuilder =
    LessonProgressCompanion Function({
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<String> lessonId,
      Value<String> titleId,
      Value<int> lessonIndex,
      Value<DateTime> lastOpenedAt,
      Value<DateTime?> completedAt,
      Value<int> rowid,
    });

class $$LessonProgressTableFilterComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonIndex => $composableBuilder(
    column: $table.lessonIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LessonProgressTableOrderingComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonIndex => $composableBuilder(
    column: $table.lessonIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LessonProgressTableAnnotationComposer
    extends Composer<_$AppDatabase, $LessonProgressTable> {
  $$LessonProgressTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<int> get lessonIndex => $composableBuilder(
    column: $table.lessonIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$LessonProgressTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LessonProgressTable,
          LessonProgressRow,
          $$LessonProgressTableFilterComposer,
          $$LessonProgressTableOrderingComposer,
          $$LessonProgressTableAnnotationComposer,
          $$LessonProgressTableCreateCompanionBuilder,
          $$LessonProgressTableUpdateCompanionBuilder,
          (
            LessonProgressRow,
            BaseReferences<
              _$AppDatabase,
              $LessonProgressTable,
              LessonProgressRow
            >,
          ),
          LessonProgressRow,
          PrefetchHooks Function()
        > {
  $$LessonProgressTableTableManager(
    _$AppDatabase db,
    $LessonProgressTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LessonProgressTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LessonProgressTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LessonProgressTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> lessonId = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<int> lessonIndex = const Value.absent(),
                Value<DateTime> lastOpenedAt = const Value.absent(),
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonProgressCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                lessonId: lessonId,
                titleId: titleId,
                lessonIndex: lessonIndex,
                lastOpenedAt: lastOpenedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String lessonId,
                required String titleId,
                required int lessonIndex,
                required DateTime lastOpenedAt,
                Value<DateTime?> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LessonProgressCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                lessonId: lessonId,
                titleId: titleId,
                lessonIndex: lessonIndex,
                lastOpenedAt: lastOpenedAt,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LessonProgressTable, LessonProgressRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LessonProgressTable,
                    LessonProgressRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LessonProgressTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LessonProgressTable,
      LessonProgressRow,
      $$LessonProgressTableFilterComposer,
      $$LessonProgressTableOrderingComposer,
      $$LessonProgressTableAnnotationComposer,
      $$LessonProgressTableCreateCompanionBuilder,
      $$LessonProgressTableUpdateCompanionBuilder,
      (
        LessonProgressRow,
        BaseReferences<_$AppDatabase, $LessonProgressTable, LessonProgressRow>,
      ),
      LessonProgressRow,
      PrefetchHooks Function()
    >;
typedef $$QuizResultsTableCreateCompanionBuilder =
    QuizResultsCompanion Function({
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<int> id,
      Value<String> syncId,
      required String titleId,
      required int score,
      required int total,
      required String questionIds,
      required String wrongIds,
      required int contentVersion,
      required DateTime takenAt,
    });
typedef $$QuizResultsTableUpdateCompanionBuilder =
    QuizResultsCompanion Function({
      Value<DateTime> updatedAt,
      Value<bool> deleted,
      Value<bool> dirty,
      Value<int> id,
      Value<String> syncId,
      Value<String> titleId,
      Value<int> score,
      Value<int> total,
      Value<String> questionIds,
      Value<String> wrongIds,
      Value<int> contentVersion,
      Value<DateTime> takenAt,
    });

class $$QuizResultsTableFilterComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionIds => $composableBuilder(
    column: $table.questionIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get wrongIds => $composableBuilder(
    column: $table.wrongIds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuizResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncId => $composableBuilder(
    column: $table.syncId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get score => $composableBuilder(
    column: $table.score,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionIds => $composableBuilder(
    column: $table.questionIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get wrongIds => $composableBuilder(
    column: $table.wrongIds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get takenAt => $composableBuilder(
    column: $table.takenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuizResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuizResultsTable> {
  $$QuizResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get syncId =>
      $composableBuilder(column: $table.syncId, builder: (column) => column);

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<int> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  GeneratedColumn<String> get questionIds => $composableBuilder(
    column: $table.questionIds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get wrongIds =>
      $composableBuilder(column: $table.wrongIds, builder: (column) => column);

  GeneratedColumn<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get takenAt =>
      $composableBuilder(column: $table.takenAt, builder: (column) => column);
}

class $$QuizResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuizResultsTable,
          QuizResultRow,
          $$QuizResultsTableFilterComposer,
          $$QuizResultsTableOrderingComposer,
          $$QuizResultsTableAnnotationComposer,
          $$QuizResultsTableCreateCompanionBuilder,
          $$QuizResultsTableUpdateCompanionBuilder,
          (
            QuizResultRow,
            BaseReferences<_$AppDatabase, $QuizResultsTable, QuizResultRow>,
          ),
          QuizResultRow,
          PrefetchHooks Function()
        > {
  $$QuizResultsTableTableManager(_$AppDatabase db, $QuizResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuizResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuizResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuizResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> syncId = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<int> score = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<String> questionIds = const Value.absent(),
                Value<String> wrongIds = const Value.absent(),
                Value<int> contentVersion = const Value.absent(),
                Value<DateTime> takenAt = const Value.absent(),
              }) => QuizResultsCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                id: id,
                syncId: syncId,
                titleId: titleId,
                score: score,
                total: total,
                questionIds: questionIds,
                wrongIds: wrongIds,
                contentVersion: contentVersion,
                takenAt: takenAt,
              ),
          createCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<int> id = const Value.absent(),
                Value<String> syncId = const Value.absent(),
                required String titleId,
                required int score,
                required int total,
                required String questionIds,
                required String wrongIds,
                required int contentVersion,
                required DateTime takenAt,
              }) => QuizResultsCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                id: id,
                syncId: syncId,
                titleId: titleId,
                score: score,
                total: total,
                questionIds: questionIds,
                wrongIds: wrongIds,
                contentVersion: contentVersion,
                takenAt: takenAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuizResultsTable, QuizResultRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $QuizResultsTable,
                    QuizResultRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuizResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuizResultsTable,
      QuizResultRow,
      $$QuizResultsTableFilterComposer,
      $$QuizResultsTableOrderingComposer,
      $$QuizResultsTableAnnotationComposer,
      $$QuizResultsTableCreateCompanionBuilder,
      $$QuizResultsTableUpdateCompanionBuilder,
      (
        QuizResultRow,
        BaseReferences<_$AppDatabase, $QuizResultsTable, QuizResultRow>,
      ),
      QuizResultRow,
      PrefetchHooks Function()
    >;
typedef $$QuizSeenTableCreateCompanionBuilder = QuizSeenCompanion Function({
  required String questionId,
  required String titleId,
  required DateTime seenAt,
  Value<int> rowid,
});
typedef $$QuizSeenTableUpdateCompanionBuilder = QuizSeenCompanion Function({
  Value<String> questionId,
  Value<String> titleId,
  Value<DateTime> seenAt,
  Value<int> rowid,
});

class $$QuizSeenTableFilterComposer
    extends Composer<_$AppDatabase, $QuizSeenTable> {
  $$QuizSeenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$QuizSeenTableOrderingComposer
    extends Composer<_$AppDatabase, $QuizSeenTable> {
  $$QuizSeenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$QuizSeenTableAnnotationComposer
    extends Composer<_$AppDatabase, $QuizSeenTable> {
  $$QuizSeenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get questionId => $composableBuilder(
    column: $table.questionId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<DateTime> get seenAt =>
      $composableBuilder(column: $table.seenAt, builder: (column) => column);
}

class $$QuizSeenTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $QuizSeenTable,
          QuizSeenRow,
          $$QuizSeenTableFilterComposer,
          $$QuizSeenTableOrderingComposer,
          $$QuizSeenTableAnnotationComposer,
          $$QuizSeenTableCreateCompanionBuilder,
          $$QuizSeenTableUpdateCompanionBuilder,
          (
            QuizSeenRow,
            BaseReferences<_$AppDatabase, $QuizSeenTable, QuizSeenRow>,
          ),
          QuizSeenRow,
          PrefetchHooks Function()
        > {
  $$QuizSeenTableTableManager(_$AppDatabase db, $QuizSeenTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$QuizSeenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$QuizSeenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$QuizSeenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> questionId = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<DateTime> seenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => QuizSeenCompanion(
                questionId: questionId,
                titleId: titleId,
                seenAt: seenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String questionId,
                required String titleId,
                required DateTime seenAt,
                Value<int> rowid = const Value.absent(),
              }) => QuizSeenCompanion.insert(
                questionId: questionId,
                titleId: titleId,
                seenAt: seenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$QuizSeenTable, QuizSeenRow>(table),
                  BaseReferences<_$AppDatabase, $QuizSeenTable, QuizSeenRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$QuizSeenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $QuizSeenTable,
      QuizSeenRow,
      $$QuizSeenTableFilterComposer,
      $$QuizSeenTableOrderingComposer,
      $$QuizSeenTableAnnotationComposer,
      $$QuizSeenTableCreateCompanionBuilder,
      $$QuizSeenTableUpdateCompanionBuilder,
      (QuizSeenRow, BaseReferences<_$AppDatabase, $QuizSeenTable, QuizSeenRow>),
      QuizSeenRow,
      PrefetchHooks Function()
    >;
typedef $$FeedStateTableCreateCompanionBuilder = FeedStateCompanion Function({
  required DateTime updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  required String factId,
  required String titleId,
  Value<bool> saved,
  Value<int> reaction,
  Value<DateTime?> seenAt,
  Value<int> rowid,
});
typedef $$FeedStateTableUpdateCompanionBuilder = FeedStateCompanion Function({
  Value<DateTime> updatedAt,
  Value<bool> deleted,
  Value<bool> dirty,
  Value<String> factId,
  Value<String> titleId,
  Value<bool> saved,
  Value<int> reaction,
  Value<DateTime?> seenAt,
  Value<int> rowid,
});

class $$FeedStateTableFilterComposer
    extends Composer<_$AppDatabase, $FeedStateTable> {
  $$FeedStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnWithTypeConverterFilters<DateTime, DateTime, int> get updatedAt =>
      $composableBuilder(
        column: $table.updatedAt,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get factId => $composableBuilder(
    column: $table.factId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get saved => $composableBuilder(
    column: $table.saved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reaction => $composableBuilder(
    column: $table.reaction,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FeedStateTableOrderingComposer
    extends Composer<_$AppDatabase, $FeedStateTable> {
  $$FeedStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get deleted => $composableBuilder(
    column: $table.deleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dirty => $composableBuilder(
    column: $table.dirty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get factId => $composableBuilder(
    column: $table.factId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get saved => $composableBuilder(
    column: $table.saved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reaction => $composableBuilder(
    column: $table.reaction,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get seenAt => $composableBuilder(
    column: $table.seenAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FeedStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $FeedStateTable> {
  $$FeedStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumnWithTypeConverter<DateTime, int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<bool> get dirty =>
      $composableBuilder(column: $table.dirty, builder: (column) => column);

  GeneratedColumn<String> get factId =>
      $composableBuilder(column: $table.factId, builder: (column) => column);

  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<bool> get saved =>
      $composableBuilder(column: $table.saved, builder: (column) => column);

  GeneratedColumn<int> get reaction =>
      $composableBuilder(column: $table.reaction, builder: (column) => column);

  GeneratedColumn<DateTime> get seenAt =>
      $composableBuilder(column: $table.seenAt, builder: (column) => column);
}

class $$FeedStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FeedStateTable,
          FeedStateRow,
          $$FeedStateTableFilterComposer,
          $$FeedStateTableOrderingComposer,
          $$FeedStateTableAnnotationComposer,
          $$FeedStateTableCreateCompanionBuilder,
          $$FeedStateTableUpdateCompanionBuilder,
          (
            FeedStateRow,
            BaseReferences<_$AppDatabase, $FeedStateTable, FeedStateRow>,
          ),
          FeedStateRow,
          PrefetchHooks Function()
        > {
  $$FeedStateTableTableManager(_$AppDatabase db, $FeedStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FeedStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FeedStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FeedStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<DateTime> updatedAt = const Value.absent(),
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                Value<String> factId = const Value.absent(),
                Value<String> titleId = const Value.absent(),
                Value<bool> saved = const Value.absent(),
                Value<int> reaction = const Value.absent(),
                Value<DateTime?> seenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FeedStateCompanion(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                factId: factId,
                titleId: titleId,
                saved: saved,
                reaction: reaction,
                seenAt: seenAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required DateTime updatedAt,
                Value<bool> deleted = const Value.absent(),
                Value<bool> dirty = const Value.absent(),
                required String factId,
                required String titleId,
                Value<bool> saved = const Value.absent(),
                Value<int> reaction = const Value.absent(),
                Value<DateTime?> seenAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FeedStateCompanion.insert(
                updatedAt: updatedAt,
                deleted: deleted,
                dirty: dirty,
                factId: factId,
                titleId: titleId,
                saved: saved,
                reaction: reaction,
                seenAt: seenAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$FeedStateTable, FeedStateRow>(table),
                  BaseReferences<_$AppDatabase, $FeedStateTable, FeedStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FeedStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FeedStateTable,
      FeedStateRow,
      $$FeedStateTableFilterComposer,
      $$FeedStateTableOrderingComposer,
      $$FeedStateTableAnnotationComposer,
      $$FeedStateTableCreateCompanionBuilder,
      $$FeedStateTableUpdateCompanionBuilder,
      (
        FeedStateRow,
        BaseReferences<_$AppDatabase, $FeedStateTable, FeedStateRow>,
      ),
      FeedStateRow,
      PrefetchHooks Function()
    >;
typedef $$CachedDocsTableCreateCompanionBuilder = CachedDocsCompanion Function({
  required String key,
  required String payload,
  Value<String?> etag,
  required DateTime fetchedAt,
  Value<int> rowid,
});
typedef $$CachedDocsTableUpdateCompanionBuilder = CachedDocsCompanion Function({
  Value<String> key,
  Value<String> payload,
  Value<String?> etag,
  Value<DateTime> fetchedAt,
  Value<int> rowid,
});

class $$CachedDocsTableFilterComposer
    extends Composer<_$AppDatabase, $CachedDocsTable> {
  $$CachedDocsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedDocsTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedDocsTable> {
  $$CachedDocsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedDocsTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedDocsTable> {
  $$CachedDocsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedDocsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedDocsTable,
          CachedDocRow,
          $$CachedDocsTableFilterComposer,
          $$CachedDocsTableOrderingComposer,
          $$CachedDocsTableAnnotationComposer,
          $$CachedDocsTableCreateCompanionBuilder,
          $$CachedDocsTableUpdateCompanionBuilder,
          (
            CachedDocRow,
            BaseReferences<_$AppDatabase, $CachedDocsTable, CachedDocRow>,
          ),
          CachedDocRow,
          PrefetchHooks Function()
        > {
  $$CachedDocsTableTableManager(_$AppDatabase db, $CachedDocsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedDocsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedDocsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedDocsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedDocsCompanion(
                key: key,
                payload: payload,
                etag: etag,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String payload,
                Value<String?> etag = const Value.absent(),
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedDocsCompanion.insert(
                key: key,
                payload: payload,
                etag: etag,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedDocsTable, CachedDocRow>(table),
                  BaseReferences<_$AppDatabase, $CachedDocsTable, CachedDocRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedDocsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedDocsTable,
      CachedDocRow,
      $$CachedDocsTableFilterComposer,
      $$CachedDocsTableOrderingComposer,
      $$CachedDocsTableAnnotationComposer,
      $$CachedDocsTableCreateCompanionBuilder,
      $$CachedDocsTableUpdateCompanionBuilder,
      (
        CachedDocRow,
        BaseReferences<_$AppDatabase, $CachedDocsTable, CachedDocRow>,
      ),
      CachedDocRow,
      PrefetchHooks Function()
    >;
typedef $$CachedTitlesTableCreateCompanionBuilder =
    CachedTitlesCompanion Function({
      required String titleId,
      required String payload,
      required int contentVersion,
      Value<String?> etag,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$CachedTitlesTableUpdateCompanionBuilder =
    CachedTitlesCompanion Function({
      Value<String> titleId,
      Value<String> payload,
      Value<int> contentVersion,
      Value<String?> etag,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$CachedTitlesTableFilterComposer
    extends Composer<_$AppDatabase, $CachedTitlesTable> {
  $$CachedTitlesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedTitlesTableOrderingComposer
    extends Composer<_$AppDatabase, $CachedTitlesTable> {
  $$CachedTitlesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get titleId => $composableBuilder(
    column: $table.titleId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get etag => $composableBuilder(
    column: $table.etag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedTitlesTableAnnotationComposer
    extends Composer<_$AppDatabase, $CachedTitlesTable> {
  $$CachedTitlesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get titleId =>
      $composableBuilder(column: $table.titleId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get contentVersion => $composableBuilder(
    column: $table.contentVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get etag =>
      $composableBuilder(column: $table.etag, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedTitlesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CachedTitlesTable,
          CachedTitleRow,
          $$CachedTitlesTableFilterComposer,
          $$CachedTitlesTableOrderingComposer,
          $$CachedTitlesTableAnnotationComposer,
          $$CachedTitlesTableCreateCompanionBuilder,
          $$CachedTitlesTableUpdateCompanionBuilder,
          (
            CachedTitleRow,
            BaseReferences<_$AppDatabase, $CachedTitlesTable, CachedTitleRow>,
          ),
          CachedTitleRow,
          PrefetchHooks Function()
        > {
  $$CachedTitlesTableTableManager(_$AppDatabase db, $CachedTitlesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedTitlesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedTitlesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedTitlesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> titleId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> contentVersion = const Value.absent(),
                Value<String?> etag = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedTitlesCompanion(
                titleId: titleId,
                payload: payload,
                contentVersion: contentVersion,
                etag: etag,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String titleId,
                required String payload,
                required int contentVersion,
                Value<String?> etag = const Value.absent(),
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedTitlesCompanion.insert(
                titleId: titleId,
                payload: payload,
                contentVersion: contentVersion,
                etag: etag,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$CachedTitlesTable, CachedTitleRow>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $CachedTitlesTable,
                    CachedTitleRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedTitlesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CachedTitlesTable,
      CachedTitleRow,
      $$CachedTitlesTableFilterComposer,
      $$CachedTitlesTableOrderingComposer,
      $$CachedTitlesTableAnnotationComposer,
      $$CachedTitlesTableCreateCompanionBuilder,
      $$CachedTitlesTableUpdateCompanionBuilder,
      (
        CachedTitleRow,
        BaseReferences<_$AppDatabase, $CachedTitlesTable, CachedTitleRow>,
      ),
      CachedTitleRow,
      PrefetchHooks Function()
    >;
typedef $$SyncStateTableCreateCompanionBuilder = SyncStateCompanion Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$SyncStateTableUpdateCompanionBuilder = SyncStateCompanion Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$SyncStateTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateTable> {
  $$SyncStateTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$SyncStateTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateTable,
          SyncStateRow,
          $$SyncStateTableFilterComposer,
          $$SyncStateTableOrderingComposer,
          $$SyncStateTableAnnotationComposer,
          $$SyncStateTableCreateCompanionBuilder,
          $$SyncStateTableUpdateCompanionBuilder,
          (
            SyncStateRow,
            BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
          ),
          SyncStateRow,
          PrefetchHooks Function()
        > {
  $$SyncStateTableTableManager(_$AppDatabase db, $SyncStateTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) => SyncStateCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SyncStateTable, SyncStateRow>(table),
                  BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateTable,
      SyncStateRow,
      $$SyncStateTableFilterComposer,
      $$SyncStateTableOrderingComposer,
      $$SyncStateTableAnnotationComposer,
      $$SyncStateTableCreateCompanionBuilder,
      $$SyncStateTableUpdateCompanionBuilder,
      (
        SyncStateRow,
        BaseReferences<_$AppDatabase, $SyncStateTable, SyncStateRow>,
      ),
      SyncStateRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SettingsTableTableManager get settings =>
      $$SettingsTableTableManager(_db, _db.settings);
  $$InterestsTableTableManager get interests =>
      $$InterestsTableTableManager(_db, _db.interests);
  $$StudyListTableTableManager get studyList =>
      $$StudyListTableTableManager(_db, _db.studyList);
  $$RatingsTableTableManager get ratings =>
      $$RatingsTableTableManager(_db, _db.ratings);
  $$LessonProgressTableTableManager get lessonProgress =>
      $$LessonProgressTableTableManager(_db, _db.lessonProgress);
  $$QuizResultsTableTableManager get quizResults =>
      $$QuizResultsTableTableManager(_db, _db.quizResults);
  $$QuizSeenTableTableManager get quizSeen =>
      $$QuizSeenTableTableManager(_db, _db.quizSeen);
  $$FeedStateTableTableManager get feedState =>
      $$FeedStateTableTableManager(_db, _db.feedState);
  $$CachedDocsTableTableManager get cachedDocs =>
      $$CachedDocsTableTableManager(_db, _db.cachedDocs);
  $$CachedTitlesTableTableManager get cachedTitles =>
      $$CachedTitlesTableTableManager(_db, _db.cachedTitles);
  $$SyncStateTableTableManager get syncState =>
      $$SyncStateTableTableManager(_db, _db.syncState);
}
