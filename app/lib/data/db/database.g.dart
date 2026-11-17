// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ContentVersionsTable extends ContentVersions
    with TableInfo<$ContentVersionsTable, ContentVersion> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentVersionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _loadedAtMeta =
      const VerificationMeta('loadedAt');
  @override
  late final GeneratedColumn<String> loadedAt = GeneratedColumn<String>(
      'loaded_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [version, loadedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_versions';
  @override
  VerificationContext validateIntegrity(Insertable<ContentVersion> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('loaded_at')) {
      context.handle(_loadedAtMeta,
          loadedAt.isAcceptableOrUnknown(data['loaded_at']!, _loadedAtMeta));
    } else if (isInserting) {
      context.missing(_loadedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {version};
  @override
  ContentVersion map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentVersion(
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version'])!,
      loadedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}loaded_at'])!,
    );
  }

  @override
  $ContentVersionsTable createAlias(String alias) {
    return $ContentVersionsTable(attachedDatabase, alias);
  }
}

class ContentVersion extends DataClass implements Insertable<ContentVersion> {
  final String version;
  final String loadedAt;
  const ContentVersion({required this.version, required this.loadedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['version'] = Variable<String>(version);
    map['loaded_at'] = Variable<String>(loadedAt);
    return map;
  }

  ContentVersionsCompanion toCompanion(bool nullToAbsent) {
    return ContentVersionsCompanion(
      version: Value(version),
      loadedAt: Value(loadedAt),
    );
  }

  factory ContentVersion.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentVersion(
      version: serializer.fromJson<String>(json['version']),
      loadedAt: serializer.fromJson<String>(json['loadedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'version': serializer.toJson<String>(version),
      'loadedAt': serializer.toJson<String>(loadedAt),
    };
  }

  ContentVersion copyWith({String? version, String? loadedAt}) =>
      ContentVersion(
        version: version ?? this.version,
        loadedAt: loadedAt ?? this.loadedAt,
      );
  ContentVersion copyWithCompanion(ContentVersionsCompanion data) {
    return ContentVersion(
      version: data.version.present ? data.version.value : this.version,
      loadedAt: data.loadedAt.present ? data.loadedAt.value : this.loadedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentVersion(')
          ..write('version: $version, ')
          ..write('loadedAt: $loadedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(version, loadedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentVersion &&
          other.version == this.version &&
          other.loadedAt == this.loadedAt);
}

class ContentVersionsCompanion extends UpdateCompanion<ContentVersion> {
  final Value<String> version;
  final Value<String> loadedAt;
  final Value<int> rowid;
  const ContentVersionsCompanion({
    this.version = const Value.absent(),
    this.loadedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentVersionsCompanion.insert({
    required String version,
    required String loadedAt,
    this.rowid = const Value.absent(),
  })  : version = Value(version),
        loadedAt = Value(loadedAt);
  static Insertable<ContentVersion> custom({
    Expression<String>? version,
    Expression<String>? loadedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (version != null) 'version': version,
      if (loadedAt != null) 'loaded_at': loadedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentVersionsCompanion copyWith(
      {Value<String>? version, Value<String>? loadedAt, Value<int>? rowid}) {
    return ContentVersionsCompanion(
      version: version ?? this.version,
      loadedAt: loadedAt ?? this.loadedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (loadedAt.present) {
      map['loaded_at'] = Variable<String>(loadedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentVersionsCompanion(')
          ..write('version: $version, ')
          ..write('loadedAt: $loadedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentSkillsTable extends ContentSkills
    with TableInfo<$ContentSkillsTable, ContentSkill> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentSkillsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, version, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_skills';
  @override
  VerificationContext validateIntegrity(Insertable<ContentSkill> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContentSkill map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentSkill(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
    );
  }

  @override
  $ContentSkillsTable createAlias(String alias) {
    return $ContentSkillsTable(attachedDatabase, alias);
  }
}

class ContentSkill extends DataClass implements Insertable<ContentSkill> {
  final String id;
  final String version;
  final String json;
  const ContentSkill(
      {required this.id, required this.version, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<String>(version);
    map['json'] = Variable<String>(json);
    return map;
  }

  ContentSkillsCompanion toCompanion(bool nullToAbsent) {
    return ContentSkillsCompanion(
      id: Value(id),
      version: Value(version),
      json: Value(json),
    );
  }

  factory ContentSkill.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentSkill(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<String>(json['version']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<String>(version),
      'json': serializer.toJson<String>(json),
    };
  }

  ContentSkill copyWith({String? id, String? version, String? json}) =>
      ContentSkill(
        id: id ?? this.id,
        version: version ?? this.version,
        json: json ?? this.json,
      );
  ContentSkill copyWithCompanion(ContentSkillsCompanion data) {
    return ContentSkill(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentSkill(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, version, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentSkill &&
          other.id == this.id &&
          other.version == this.version &&
          other.json == this.json);
}

class ContentSkillsCompanion extends UpdateCompanion<ContentSkill> {
  final Value<String> id;
  final Value<String> version;
  final Value<String> json;
  final Value<int> rowid;
  const ContentSkillsCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentSkillsCompanion.insert({
    required String id,
    required String version,
    required String json,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        version = Value(version),
        json = Value(json);
  static Insertable<ContentSkill> custom({
    Expression<String>? id,
    Expression<String>? version,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentSkillsCompanion copyWith(
      {Value<String>? id,
      Value<String>? version,
      Value<String>? json,
      Value<int>? rowid}) {
    return ContentSkillsCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentSkillsCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentIssuesTable extends ContentIssues
    with TableInfo<$ContentIssuesTable, ContentIssue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentIssuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, version, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_issues';
  @override
  VerificationContext validateIntegrity(Insertable<ContentIssue> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContentIssue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentIssue(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
    );
  }

  @override
  $ContentIssuesTable createAlias(String alias) {
    return $ContentIssuesTable(attachedDatabase, alias);
  }
}

class ContentIssue extends DataClass implements Insertable<ContentIssue> {
  final String id;
  final String version;
  final String json;
  const ContentIssue(
      {required this.id, required this.version, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<String>(version);
    map['json'] = Variable<String>(json);
    return map;
  }

  ContentIssuesCompanion toCompanion(bool nullToAbsent) {
    return ContentIssuesCompanion(
      id: Value(id),
      version: Value(version),
      json: Value(json),
    );
  }

  factory ContentIssue.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentIssue(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<String>(json['version']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<String>(version),
      'json': serializer.toJson<String>(json),
    };
  }

  ContentIssue copyWith({String? id, String? version, String? json}) =>
      ContentIssue(
        id: id ?? this.id,
        version: version ?? this.version,
        json: json ?? this.json,
      );
  ContentIssue copyWithCompanion(ContentIssuesCompanion data) {
    return ContentIssue(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentIssue(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, version, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentIssue &&
          other.id == this.id &&
          other.version == this.version &&
          other.json == this.json);
}

class ContentIssuesCompanion extends UpdateCompanion<ContentIssue> {
  final Value<String> id;
  final Value<String> version;
  final Value<String> json;
  final Value<int> rowid;
  const ContentIssuesCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentIssuesCompanion.insert({
    required String id,
    required String version,
    required String json,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        version = Value(version),
        json = Value(json);
  static Insertable<ContentIssue> custom({
    Expression<String>? id,
    Expression<String>? version,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentIssuesCompanion copyWith(
      {Value<String>? id,
      Value<String>? version,
      Value<String>? json,
      Value<int>? rowid}) {
    return ContentIssuesCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentIssuesCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentBadgesTable extends ContentBadges
    with TableInfo<$ContentBadgesTable, ContentBadge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentBadgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, version, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_badges';
  @override
  VerificationContext validateIntegrity(Insertable<ContentBadge> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContentBadge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentBadge(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
    );
  }

  @override
  $ContentBadgesTable createAlias(String alias) {
    return $ContentBadgesTable(attachedDatabase, alias);
  }
}

class ContentBadge extends DataClass implements Insertable<ContentBadge> {
  final String id;
  final String version;
  final String json;
  const ContentBadge(
      {required this.id, required this.version, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<String>(version);
    map['json'] = Variable<String>(json);
    return map;
  }

  ContentBadgesCompanion toCompanion(bool nullToAbsent) {
    return ContentBadgesCompanion(
      id: Value(id),
      version: Value(version),
      json: Value(json),
    );
  }

  factory ContentBadge.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentBadge(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<String>(json['version']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<String>(version),
      'json': serializer.toJson<String>(json),
    };
  }

  ContentBadge copyWith({String? id, String? version, String? json}) =>
      ContentBadge(
        id: id ?? this.id,
        version: version ?? this.version,
        json: json ?? this.json,
      );
  ContentBadge copyWithCompanion(ContentBadgesCompanion data) {
    return ContentBadge(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentBadge(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, version, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentBadge &&
          other.id == this.id &&
          other.version == this.version &&
          other.json == this.json);
}

class ContentBadgesCompanion extends UpdateCompanion<ContentBadge> {
  final Value<String> id;
  final Value<String> version;
  final Value<String> json;
  final Value<int> rowid;
  const ContentBadgesCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentBadgesCompanion.insert({
    required String id,
    required String version,
    required String json,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        version = Value(version),
        json = Value(json);
  static Insertable<ContentBadge> custom({
    Expression<String>? id,
    Expression<String>? version,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentBadgesCompanion copyWith(
      {Value<String>? id,
      Value<String>? version,
      Value<String>? json,
      Value<int>? rowid}) {
    return ContentBadgesCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentBadgesCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentCareItemsTable extends ContentCareItems
    with TableInfo<$ContentCareItemsTable, ContentCareItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentCareItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, version, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_care_items';
  @override
  VerificationContext validateIntegrity(Insertable<ContentCareItem> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContentCareItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentCareItem(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
    );
  }

  @override
  $ContentCareItemsTable createAlias(String alias) {
    return $ContentCareItemsTable(attachedDatabase, alias);
  }
}

class ContentCareItem extends DataClass implements Insertable<ContentCareItem> {
  final String id;
  final String version;
  final String json;
  const ContentCareItem(
      {required this.id, required this.version, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<String>(version);
    map['json'] = Variable<String>(json);
    return map;
  }

  ContentCareItemsCompanion toCompanion(bool nullToAbsent) {
    return ContentCareItemsCompanion(
      id: Value(id),
      version: Value(version),
      json: Value(json),
    );
  }

  factory ContentCareItem.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentCareItem(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<String>(json['version']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<String>(version),
      'json': serializer.toJson<String>(json),
    };
  }

  ContentCareItem copyWith({String? id, String? version, String? json}) =>
      ContentCareItem(
        id: id ?? this.id,
        version: version ?? this.version,
        json: json ?? this.json,
      );
  ContentCareItem copyWithCompanion(ContentCareItemsCompanion data) {
    return ContentCareItem(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentCareItem(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, version, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentCareItem &&
          other.id == this.id &&
          other.version == this.version &&
          other.json == this.json);
}

class ContentCareItemsCompanion extends UpdateCompanion<ContentCareItem> {
  final Value<String> id;
  final Value<String> version;
  final Value<String> json;
  final Value<int> rowid;
  const ContentCareItemsCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentCareItemsCompanion.insert({
    required String id,
    required String version,
    required String json,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        version = Value(version),
        json = Value(json);
  static Insertable<ContentCareItem> custom({
    Expression<String>? id,
    Expression<String>? version,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentCareItemsCompanion copyWith(
      {Value<String>? id,
      Value<String>? version,
      Value<String>? json,
      Value<int>? rowid}) {
    return ContentCareItemsCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentCareItemsCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ContentAiLexiconsTable extends ContentAiLexicons
    with TableInfo<$ContentAiLexiconsTable, ContentAiLexicon> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ContentAiLexiconsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
      'version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, version, json];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'content_ai_lexicons';
  @override
  VerificationContext validateIntegrity(Insertable<ContentAiLexicon> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ContentAiLexicon map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ContentAiLexicon(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}version'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
    );
  }

  @override
  $ContentAiLexiconsTable createAlias(String alias) {
    return $ContentAiLexiconsTable(attachedDatabase, alias);
  }
}

class ContentAiLexicon extends DataClass
    implements Insertable<ContentAiLexicon> {
  final String id;
  final String version;
  final String json;
  const ContentAiLexicon(
      {required this.id, required this.version, required this.json});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['version'] = Variable<String>(version);
    map['json'] = Variable<String>(json);
    return map;
  }

  ContentAiLexiconsCompanion toCompanion(bool nullToAbsent) {
    return ContentAiLexiconsCompanion(
      id: Value(id),
      version: Value(version),
      json: Value(json),
    );
  }

  factory ContentAiLexicon.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ContentAiLexicon(
      id: serializer.fromJson<String>(json['id']),
      version: serializer.fromJson<String>(json['version']),
      json: serializer.fromJson<String>(json['json']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'version': serializer.toJson<String>(version),
      'json': serializer.toJson<String>(json),
    };
  }

  ContentAiLexicon copyWith({String? id, String? version, String? json}) =>
      ContentAiLexicon(
        id: id ?? this.id,
        version: version ?? this.version,
        json: json ?? this.json,
      );
  ContentAiLexicon copyWithCompanion(ContentAiLexiconsCompanion data) {
    return ContentAiLexicon(
      id: data.id.present ? data.id.value : this.id,
      version: data.version.present ? data.version.value : this.version,
      json: data.json.present ? data.json.value : this.json,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ContentAiLexicon(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('json: $json')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, version, json);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ContentAiLexicon &&
          other.id == this.id &&
          other.version == this.version &&
          other.json == this.json);
}

class ContentAiLexiconsCompanion extends UpdateCompanion<ContentAiLexicon> {
  final Value<String> id;
  final Value<String> version;
  final Value<String> json;
  final Value<int> rowid;
  const ContentAiLexiconsCompanion({
    this.id = const Value.absent(),
    this.version = const Value.absent(),
    this.json = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ContentAiLexiconsCompanion.insert({
    required String id,
    required String version,
    required String json,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        version = Value(version),
        json = Value(json);
  static Insertable<ContentAiLexicon> custom({
    Expression<String>? id,
    Expression<String>? version,
    Expression<String>? json,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (version != null) 'version': version,
      if (json != null) 'json': json,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ContentAiLexiconsCompanion copyWith(
      {Value<String>? id,
      Value<String>? version,
      Value<String>? json,
      Value<int>? rowid}) {
    return ContentAiLexiconsCompanion(
      id: id ?? this.id,
      version: version ?? this.version,
      json: json ?? this.json,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ContentAiLexiconsCompanion(')
          ..write('id: $id, ')
          ..write('version: $version, ')
          ..write('json: $json, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UsersTable extends Users with TableInfo<$UsersTable, User> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UsersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _phoneOrEmailMeta =
      const VerificationMeta('phoneOrEmail');
  @override
  late final GeneratedColumn<String> phoneOrEmail = GeneratedColumn<String>(
      'phone_or_email', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _nicknameMeta =
      const VerificationMeta('nickname');
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
      'nickname', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarUrlMeta =
      const VerificationMeta('avatarUrl');
  @override
  late final GeneratedColumn<String> avatarUrl = GeneratedColumn<String>(
      'avatar_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        id,
        phoneOrEmail,
        nickname,
        avatarUrl,
        createdAt
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
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('phone_or_email')) {
      context.handle(
          _phoneOrEmailMeta,
          phoneOrEmail.isAcceptableOrUnknown(
              data['phone_or_email']!, _phoneOrEmailMeta));
    }
    if (data.containsKey('nickname')) {
      context.handle(_nicknameMeta,
          nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta));
    } else if (isInserting) {
      context.missing(_nicknameMeta);
    }
    if (data.containsKey('avatar_url')) {
      context.handle(_avatarUrlMeta,
          avatarUrl.isAcceptableOrUnknown(data['avatar_url']!, _avatarUrlMeta));
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
  User map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return User(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      phoneOrEmail: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}phone_or_email']),
      nickname: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}nickname'])!,
      avatarUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_url']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $UsersTable createAlias(String alias) {
    return $UsersTable(attachedDatabase, alias);
  }
}

class User extends DataClass implements Insertable<User> {
  final String clientUpdatedAt;
  final bool deleted;
  final String id;
  final String? phoneOrEmail;
  final String nickname;
  final String? avatarUrl;
  final String createdAt;
  const User(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.id,
      this.phoneOrEmail,
      required this.nickname,
      this.avatarUrl,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || phoneOrEmail != null) {
      map['phone_or_email'] = Variable<String>(phoneOrEmail);
    }
    map['nickname'] = Variable<String>(nickname);
    if (!nullToAbsent || avatarUrl != null) {
      map['avatar_url'] = Variable<String>(avatarUrl);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  UsersCompanion toCompanion(bool nullToAbsent) {
    return UsersCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      id: Value(id),
      phoneOrEmail: phoneOrEmail == null && nullToAbsent
          ? const Value.absent()
          : Value(phoneOrEmail),
      nickname: Value(nickname),
      avatarUrl: avatarUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(avatarUrl),
      createdAt: Value(createdAt),
    );
  }

  factory User.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return User(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      id: serializer.fromJson<String>(json['id']),
      phoneOrEmail: serializer.fromJson<String?>(json['phoneOrEmail']),
      nickname: serializer.fromJson<String>(json['nickname']),
      avatarUrl: serializer.fromJson<String?>(json['avatarUrl']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'id': serializer.toJson<String>(id),
      'phoneOrEmail': serializer.toJson<String?>(phoneOrEmail),
      'nickname': serializer.toJson<String>(nickname),
      'avatarUrl': serializer.toJson<String?>(avatarUrl),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  User copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? id,
          Value<String?> phoneOrEmail = const Value.absent(),
          String? nickname,
          Value<String?> avatarUrl = const Value.absent(),
          String? createdAt}) =>
      User(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        id: id ?? this.id,
        phoneOrEmail:
            phoneOrEmail.present ? phoneOrEmail.value : this.phoneOrEmail,
        nickname: nickname ?? this.nickname,
        avatarUrl: avatarUrl.present ? avatarUrl.value : this.avatarUrl,
        createdAt: createdAt ?? this.createdAt,
      );
  User copyWithCompanion(UsersCompanion data) {
    return User(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      id: data.id.present ? data.id.value : this.id,
      phoneOrEmail: data.phoneOrEmail.present
          ? data.phoneOrEmail.value
          : this.phoneOrEmail,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      avatarUrl: data.avatarUrl.present ? data.avatarUrl.value : this.avatarUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('User(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('phoneOrEmail: $phoneOrEmail, ')
          ..write('nickname: $nickname, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientUpdatedAt, deleted, id, phoneOrEmail,
      nickname, avatarUrl, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.id == this.id &&
          other.phoneOrEmail == this.phoneOrEmail &&
          other.nickname == this.nickname &&
          other.avatarUrl == this.avatarUrl &&
          other.createdAt == this.createdAt);
}

class UsersCompanion extends UpdateCompanion<User> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> id;
  final Value<String?> phoneOrEmail;
  final Value<String> nickname;
  final Value<String?> avatarUrl;
  final Value<String> createdAt;
  final Value<int> rowid;
  const UsersCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.id = const Value.absent(),
    this.phoneOrEmail = const Value.absent(),
    this.nickname = const Value.absent(),
    this.avatarUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UsersCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String id,
    this.phoneOrEmail = const Value.absent(),
    required String nickname,
    this.avatarUrl = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        nickname = Value(nickname),
        createdAt = Value(createdAt);
  static Insertable<User> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? id,
    Expression<String>? phoneOrEmail,
    Expression<String>? nickname,
    Expression<String>? avatarUrl,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (id != null) 'id': id,
      if (phoneOrEmail != null) 'phone_or_email': phoneOrEmail,
      if (nickname != null) 'nickname': nickname,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UsersCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? id,
      Value<String?>? phoneOrEmail,
      Value<String>? nickname,
      Value<String?>? avatarUrl,
      Value<String>? createdAt,
      Value<int>? rowid}) {
    return UsersCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      id: id ?? this.id,
      phoneOrEmail: phoneOrEmail ?? this.phoneOrEmail,
      nickname: nickname ?? this.nickname,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (phoneOrEmail.present) {
      map['phone_or_email'] = Variable<String>(phoneOrEmail.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (avatarUrl.present) {
      map['avatar_url'] = Variable<String>(avatarUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UsersCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('phoneOrEmail: $phoneOrEmail, ')
          ..write('nickname: $nickname, ')
          ..write('avatarUrl: $avatarUrl, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HouseholdsTable extends Households
    with TableInfo<$HouseholdsTable, Household> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HouseholdsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
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
  static const VerificationMeta _creatorUserIdMeta =
      const VerificationMeta('creatorUserId');
  @override
  late final GeneratedColumn<String> creatorUserId = GeneratedColumn<String>(
      'creator_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _inviteCodeMeta =
      const VerificationMeta('inviteCode');
  @override
  late final GeneratedColumn<String> inviteCode = GeneratedColumn<String>(
      'invite_code', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        id,
        name,
        creatorUserId,
        inviteCode,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'households';
  @override
  VerificationContext validateIntegrity(Insertable<Household> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
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
    if (data.containsKey('creator_user_id')) {
      context.handle(
          _creatorUserIdMeta,
          creatorUserId.isAcceptableOrUnknown(
              data['creator_user_id']!, _creatorUserIdMeta));
    } else if (isInserting) {
      context.missing(_creatorUserIdMeta);
    }
    if (data.containsKey('invite_code')) {
      context.handle(
          _inviteCodeMeta,
          inviteCode.isAcceptableOrUnknown(
              data['invite_code']!, _inviteCodeMeta));
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
  Household map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Household(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      creatorUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}creator_user_id'])!,
      inviteCode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}invite_code']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $HouseholdsTable createAlias(String alias) {
    return $HouseholdsTable(attachedDatabase, alias);
  }
}

class Household extends DataClass implements Insertable<Household> {
  final String clientUpdatedAt;
  final bool deleted;
  final String id;
  final String name;
  final String creatorUserId;
  final String? inviteCode;
  final String createdAt;
  const Household(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.id,
      required this.name,
      required this.creatorUserId,
      this.inviteCode,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['creator_user_id'] = Variable<String>(creatorUserId);
    if (!nullToAbsent || inviteCode != null) {
      map['invite_code'] = Variable<String>(inviteCode);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  HouseholdsCompanion toCompanion(bool nullToAbsent) {
    return HouseholdsCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      id: Value(id),
      name: Value(name),
      creatorUserId: Value(creatorUserId),
      inviteCode: inviteCode == null && nullToAbsent
          ? const Value.absent()
          : Value(inviteCode),
      createdAt: Value(createdAt),
    );
  }

  factory Household.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Household(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      creatorUserId: serializer.fromJson<String>(json['creatorUserId']),
      inviteCode: serializer.fromJson<String?>(json['inviteCode']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'creatorUserId': serializer.toJson<String>(creatorUserId),
      'inviteCode': serializer.toJson<String?>(inviteCode),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  Household copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? id,
          String? name,
          String? creatorUserId,
          Value<String?> inviteCode = const Value.absent(),
          String? createdAt}) =>
      Household(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        id: id ?? this.id,
        name: name ?? this.name,
        creatorUserId: creatorUserId ?? this.creatorUserId,
        inviteCode: inviteCode.present ? inviteCode.value : this.inviteCode,
        createdAt: createdAt ?? this.createdAt,
      );
  Household copyWithCompanion(HouseholdsCompanion data) {
    return Household(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      creatorUserId: data.creatorUserId.present
          ? data.creatorUserId.value
          : this.creatorUserId,
      inviteCode:
          data.inviteCode.present ? data.inviteCode.value : this.inviteCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Household(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('creatorUserId: $creatorUserId, ')
          ..write('inviteCode: $inviteCode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientUpdatedAt, deleted, id, name, creatorUserId, inviteCode, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Household &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.id == this.id &&
          other.name == this.name &&
          other.creatorUserId == this.creatorUserId &&
          other.inviteCode == this.inviteCode &&
          other.createdAt == this.createdAt);
}

class HouseholdsCompanion extends UpdateCompanion<Household> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> id;
  final Value<String> name;
  final Value<String> creatorUserId;
  final Value<String?> inviteCode;
  final Value<String> createdAt;
  final Value<int> rowid;
  const HouseholdsCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.creatorUserId = const Value.absent(),
    this.inviteCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HouseholdsCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String id,
    required String name,
    required String creatorUserId,
    this.inviteCode = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        creatorUserId = Value(creatorUserId),
        createdAt = Value(createdAt);
  static Insertable<Household> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? creatorUserId,
    Expression<String>? inviteCode,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (creatorUserId != null) 'creator_user_id': creatorUserId,
      if (inviteCode != null) 'invite_code': inviteCode,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HouseholdsCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? id,
      Value<String>? name,
      Value<String>? creatorUserId,
      Value<String?>? inviteCode,
      Value<String>? createdAt,
      Value<int>? rowid}) {
    return HouseholdsCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      id: id ?? this.id,
      name: name ?? this.name,
      creatorUserId: creatorUserId ?? this.creatorUserId,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (creatorUserId.present) {
      map['creator_user_id'] = Variable<String>(creatorUserId.value);
    }
    if (inviteCode.present) {
      map['invite_code'] = Variable<String>(inviteCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdsCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('creatorUserId: $creatorUserId, ')
          ..write('inviteCode: $inviteCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HouseholdMembersTable extends HouseholdMembers
    with TableInfo<$HouseholdMembersTable, HouseholdMember> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HouseholdMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _householdIdMeta =
      const VerificationMeta('householdId');
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
      'household_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _joinedAtMeta =
      const VerificationMeta('joinedAt');
  @override
  late final GeneratedColumn<String> joinedAt = GeneratedColumn<String>(
      'joined_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [clientUpdatedAt, deleted, householdId, userId, role, joinedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'household_members';
  @override
  VerificationContext validateIntegrity(Insertable<HouseholdMember> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('household_id')) {
      context.handle(
          _householdIdMeta,
          householdId.isAcceptableOrUnknown(
              data['household_id']!, _householdIdMeta));
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at')) {
      context.handle(_joinedAtMeta,
          joinedAt.isAcceptableOrUnknown(data['joined_at']!, _joinedAtMeta));
    } else if (isInserting) {
      context.missing(_joinedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {householdId, userId};
  @override
  HouseholdMember map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HouseholdMember(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      householdId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}household_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      joinedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}joined_at'])!,
    );
  }

  @override
  $HouseholdMembersTable createAlias(String alias) {
    return $HouseholdMembersTable(attachedDatabase, alias);
  }
}

class HouseholdMember extends DataClass implements Insertable<HouseholdMember> {
  final String clientUpdatedAt;
  final bool deleted;
  final String householdId;
  final String userId;
  final String role;
  final String joinedAt;
  const HouseholdMember(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.householdId,
      required this.userId,
      required this.role,
      required this.joinedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['household_id'] = Variable<String>(householdId);
    map['user_id'] = Variable<String>(userId);
    map['role'] = Variable<String>(role);
    map['joined_at'] = Variable<String>(joinedAt);
    return map;
  }

  HouseholdMembersCompanion toCompanion(bool nullToAbsent) {
    return HouseholdMembersCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      householdId: Value(householdId),
      userId: Value(userId),
      role: Value(role),
      joinedAt: Value(joinedAt),
    );
  }

  factory HouseholdMember.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HouseholdMember(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      householdId: serializer.fromJson<String>(json['householdId']),
      userId: serializer.fromJson<String>(json['userId']),
      role: serializer.fromJson<String>(json['role']),
      joinedAt: serializer.fromJson<String>(json['joinedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'householdId': serializer.toJson<String>(householdId),
      'userId': serializer.toJson<String>(userId),
      'role': serializer.toJson<String>(role),
      'joinedAt': serializer.toJson<String>(joinedAt),
    };
  }

  HouseholdMember copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? householdId,
          String? userId,
          String? role,
          String? joinedAt}) =>
      HouseholdMember(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        householdId: householdId ?? this.householdId,
        userId: userId ?? this.userId,
        role: role ?? this.role,
        joinedAt: joinedAt ?? this.joinedAt,
      );
  HouseholdMember copyWithCompanion(HouseholdMembersCompanion data) {
    return HouseholdMember(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      householdId:
          data.householdId.present ? data.householdId.value : this.householdId,
      userId: data.userId.present ? data.userId.value : this.userId,
      role: data.role.present ? data.role.value : this.role,
      joinedAt: data.joinedAt.present ? data.joinedAt.value : this.joinedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdMember(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('householdId: $householdId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientUpdatedAt, deleted, householdId, userId, role, joinedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HouseholdMember &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.householdId == this.householdId &&
          other.userId == this.userId &&
          other.role == this.role &&
          other.joinedAt == this.joinedAt);
}

class HouseholdMembersCompanion extends UpdateCompanion<HouseholdMember> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> householdId;
  final Value<String> userId;
  final Value<String> role;
  final Value<String> joinedAt;
  final Value<int> rowid;
  const HouseholdMembersCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.householdId = const Value.absent(),
    this.userId = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HouseholdMembersCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String householdId,
    required String userId,
    required String role,
    required String joinedAt,
    this.rowid = const Value.absent(),
  })  : householdId = Value(householdId),
        userId = Value(userId),
        role = Value(role),
        joinedAt = Value(joinedAt);
  static Insertable<HouseholdMember> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? householdId,
    Expression<String>? userId,
    Expression<String>? role,
    Expression<String>? joinedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (householdId != null) 'household_id': householdId,
      if (userId != null) 'user_id': userId,
      if (role != null) 'role': role,
      if (joinedAt != null) 'joined_at': joinedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HouseholdMembersCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? householdId,
      Value<String>? userId,
      Value<String>? role,
      Value<String>? joinedAt,
      Value<int>? rowid}) {
    return HouseholdMembersCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      householdId: householdId ?? this.householdId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      joinedAt: joinedAt ?? this.joinedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAt.present) {
      map['joined_at'] = Variable<String>(joinedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HouseholdMembersCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('householdId: $householdId, ')
          ..write('userId: $userId, ')
          ..write('role: $role, ')
          ..write('joinedAt: $joinedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DogsTable extends Dogs with TableInfo<$DogsTable, Dog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _householdIdMeta =
      const VerificationMeta('householdId');
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
      'household_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _birthDateMeta =
      const VerificationMeta('birthDate');
  @override
  late final GeneratedColumn<String> birthDate = GeneratedColumn<String>(
      'birth_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _breedIdMeta =
      const VerificationMeta('breedId');
  @override
  late final GeneratedColumn<String> breedId = GeneratedColumn<String>(
      'breed_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _breedTextMeta =
      const VerificationMeta('breedText');
  @override
  late final GeneratedColumn<String> breedText = GeneratedColumn<String>(
      'breed_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<String> sex = GeneratedColumn<String>(
      'sex', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _homeDateMeta =
      const VerificationMeta('homeDate');
  @override
  late final GeneratedColumn<String> homeDate = GeneratedColumn<String>(
      'home_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _livingEnvMeta =
      const VerificationMeta('livingEnv');
  @override
  late final GeneratedColumn<String> livingEnv = GeneratedColumn<String>(
      'living_env', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dailyMinutesMeta =
      const VerificationMeta('dailyMinutes');
  @override
  late final GeneratedColumn<int> dailyMinutes = GeneratedColumn<int>(
      'daily_minutes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _trainerCountMeta =
      const VerificationMeta('trainerCount');
  @override
  late final GeneratedColumn<int> trainerCount = GeneratedColumn<int>(
      'trainer_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _initialMasteredMeta =
      const VerificationMeta('initialMastered');
  @override
  late final GeneratedColumn<String> initialMastered = GeneratedColumn<String>(
      'initial_mastered', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        id,
        householdId,
        name,
        birthDate,
        breedId,
        breedText,
        sex,
        homeDate,
        livingEnv,
        dailyMinutes,
        trainerCount,
        createdAt,
        updatedAt,
        initialMastered
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dogs';
  @override
  VerificationContext validateIntegrity(Insertable<Dog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('household_id')) {
      context.handle(
          _householdIdMeta,
          householdId.isAcceptableOrUnknown(
              data['household_id']!, _householdIdMeta));
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('birth_date')) {
      context.handle(_birthDateMeta,
          birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta));
    } else if (isInserting) {
      context.missing(_birthDateMeta);
    }
    if (data.containsKey('breed_id')) {
      context.handle(_breedIdMeta,
          breedId.isAcceptableOrUnknown(data['breed_id']!, _breedIdMeta));
    } else if (isInserting) {
      context.missing(_breedIdMeta);
    }
    if (data.containsKey('breed_text')) {
      context.handle(_breedTextMeta,
          breedText.isAcceptableOrUnknown(data['breed_text']!, _breedTextMeta));
    } else if (isInserting) {
      context.missing(_breedTextMeta);
    }
    if (data.containsKey('sex')) {
      context.handle(
          _sexMeta, sex.isAcceptableOrUnknown(data['sex']!, _sexMeta));
    } else if (isInserting) {
      context.missing(_sexMeta);
    }
    if (data.containsKey('home_date')) {
      context.handle(_homeDateMeta,
          homeDate.isAcceptableOrUnknown(data['home_date']!, _homeDateMeta));
    } else if (isInserting) {
      context.missing(_homeDateMeta);
    }
    if (data.containsKey('living_env')) {
      context.handle(_livingEnvMeta,
          livingEnv.isAcceptableOrUnknown(data['living_env']!, _livingEnvMeta));
    } else if (isInserting) {
      context.missing(_livingEnvMeta);
    }
    if (data.containsKey('daily_minutes')) {
      context.handle(
          _dailyMinutesMeta,
          dailyMinutes.isAcceptableOrUnknown(
              data['daily_minutes']!, _dailyMinutesMeta));
    } else if (isInserting) {
      context.missing(_dailyMinutesMeta);
    }
    if (data.containsKey('trainer_count')) {
      context.handle(
          _trainerCountMeta,
          trainerCount.isAcceptableOrUnknown(
              data['trainer_count']!, _trainerCountMeta));
    } else if (isInserting) {
      context.missing(_trainerCountMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('initial_mastered')) {
      context.handle(
          _initialMasteredMeta,
          initialMastered.isAcceptableOrUnknown(
              data['initial_mastered']!, _initialMasteredMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Dog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Dog(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      householdId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}household_id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      birthDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}birth_date'])!,
      breedId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}breed_id'])!,
      breedText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}breed_text'])!,
      sex: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sex'])!,
      homeDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}home_date'])!,
      livingEnv: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}living_env'])!,
      dailyMinutes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}daily_minutes'])!,
      trainerCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}trainer_count'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
      initialMastered: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}initial_mastered'])!,
    );
  }

  @override
  $DogsTable createAlias(String alias) {
    return $DogsTable(attachedDatabase, alias);
  }
}

class Dog extends DataClass implements Insertable<Dog> {
  final String clientUpdatedAt;
  final bool deleted;
  final String id;
  final String householdId;
  final String name;
  final String birthDate;
  final String breedId;
  final String breedText;
  final String sex;
  final String homeDate;
  final String livingEnv;
  final int dailyMinutes;
  final int trainerCount;
  final String createdAt;
  final String updatedAt;

  /// M4：建档时勾选"已经会"的技能（JSON 数组），随狗同步。
  /// DogSkillStatus 不同步，加入家庭的设备靠它 + 周报判定 + 训练记录本地重算掌握状态。
  final String initialMastered;
  const Dog(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.id,
      required this.householdId,
      required this.name,
      required this.birthDate,
      required this.breedId,
      required this.breedText,
      required this.sex,
      required this.homeDate,
      required this.livingEnv,
      required this.dailyMinutes,
      required this.trainerCount,
      required this.createdAt,
      required this.updatedAt,
      required this.initialMastered});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['id'] = Variable<String>(id);
    map['household_id'] = Variable<String>(householdId);
    map['name'] = Variable<String>(name);
    map['birth_date'] = Variable<String>(birthDate);
    map['breed_id'] = Variable<String>(breedId);
    map['breed_text'] = Variable<String>(breedText);
    map['sex'] = Variable<String>(sex);
    map['home_date'] = Variable<String>(homeDate);
    map['living_env'] = Variable<String>(livingEnv);
    map['daily_minutes'] = Variable<int>(dailyMinutes);
    map['trainer_count'] = Variable<int>(trainerCount);
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    map['initial_mastered'] = Variable<String>(initialMastered);
    return map;
  }

  DogsCompanion toCompanion(bool nullToAbsent) {
    return DogsCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      id: Value(id),
      householdId: Value(householdId),
      name: Value(name),
      birthDate: Value(birthDate),
      breedId: Value(breedId),
      breedText: Value(breedText),
      sex: Value(sex),
      homeDate: Value(homeDate),
      livingEnv: Value(livingEnv),
      dailyMinutes: Value(dailyMinutes),
      trainerCount: Value(trainerCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      initialMastered: Value(initialMastered),
    );
  }

  factory Dog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Dog(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      id: serializer.fromJson<String>(json['id']),
      householdId: serializer.fromJson<String>(json['householdId']),
      name: serializer.fromJson<String>(json['name']),
      birthDate: serializer.fromJson<String>(json['birthDate']),
      breedId: serializer.fromJson<String>(json['breedId']),
      breedText: serializer.fromJson<String>(json['breedText']),
      sex: serializer.fromJson<String>(json['sex']),
      homeDate: serializer.fromJson<String>(json['homeDate']),
      livingEnv: serializer.fromJson<String>(json['livingEnv']),
      dailyMinutes: serializer.fromJson<int>(json['dailyMinutes']),
      trainerCount: serializer.fromJson<int>(json['trainerCount']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      initialMastered: serializer.fromJson<String>(json['initialMastered']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'id': serializer.toJson<String>(id),
      'householdId': serializer.toJson<String>(householdId),
      'name': serializer.toJson<String>(name),
      'birthDate': serializer.toJson<String>(birthDate),
      'breedId': serializer.toJson<String>(breedId),
      'breedText': serializer.toJson<String>(breedText),
      'sex': serializer.toJson<String>(sex),
      'homeDate': serializer.toJson<String>(homeDate),
      'livingEnv': serializer.toJson<String>(livingEnv),
      'dailyMinutes': serializer.toJson<int>(dailyMinutes),
      'trainerCount': serializer.toJson<int>(trainerCount),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'initialMastered': serializer.toJson<String>(initialMastered),
    };
  }

  Dog copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? id,
          String? householdId,
          String? name,
          String? birthDate,
          String? breedId,
          String? breedText,
          String? sex,
          String? homeDate,
          String? livingEnv,
          int? dailyMinutes,
          int? trainerCount,
          String? createdAt,
          String? updatedAt,
          String? initialMastered}) =>
      Dog(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        id: id ?? this.id,
        householdId: householdId ?? this.householdId,
        name: name ?? this.name,
        birthDate: birthDate ?? this.birthDate,
        breedId: breedId ?? this.breedId,
        breedText: breedText ?? this.breedText,
        sex: sex ?? this.sex,
        homeDate: homeDate ?? this.homeDate,
        livingEnv: livingEnv ?? this.livingEnv,
        dailyMinutes: dailyMinutes ?? this.dailyMinutes,
        trainerCount: trainerCount ?? this.trainerCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        initialMastered: initialMastered ?? this.initialMastered,
      );
  Dog copyWithCompanion(DogsCompanion data) {
    return Dog(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      id: data.id.present ? data.id.value : this.id,
      householdId:
          data.householdId.present ? data.householdId.value : this.householdId,
      name: data.name.present ? data.name.value : this.name,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      breedId: data.breedId.present ? data.breedId.value : this.breedId,
      breedText: data.breedText.present ? data.breedText.value : this.breedText,
      sex: data.sex.present ? data.sex.value : this.sex,
      homeDate: data.homeDate.present ? data.homeDate.value : this.homeDate,
      livingEnv: data.livingEnv.present ? data.livingEnv.value : this.livingEnv,
      dailyMinutes: data.dailyMinutes.present
          ? data.dailyMinutes.value
          : this.dailyMinutes,
      trainerCount: data.trainerCount.present
          ? data.trainerCount.value
          : this.trainerCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      initialMastered: data.initialMastered.present
          ? data.initialMastered.value
          : this.initialMastered,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Dog(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('householdId: $householdId, ')
          ..write('name: $name, ')
          ..write('birthDate: $birthDate, ')
          ..write('breedId: $breedId, ')
          ..write('breedText: $breedText, ')
          ..write('sex: $sex, ')
          ..write('homeDate: $homeDate, ')
          ..write('livingEnv: $livingEnv, ')
          ..write('dailyMinutes: $dailyMinutes, ')
          ..write('trainerCount: $trainerCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('initialMastered: $initialMastered')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientUpdatedAt,
      deleted,
      id,
      householdId,
      name,
      birthDate,
      breedId,
      breedText,
      sex,
      homeDate,
      livingEnv,
      dailyMinutes,
      trainerCount,
      createdAt,
      updatedAt,
      initialMastered);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Dog &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.id == this.id &&
          other.householdId == this.householdId &&
          other.name == this.name &&
          other.birthDate == this.birthDate &&
          other.breedId == this.breedId &&
          other.breedText == this.breedText &&
          other.sex == this.sex &&
          other.homeDate == this.homeDate &&
          other.livingEnv == this.livingEnv &&
          other.dailyMinutes == this.dailyMinutes &&
          other.trainerCount == this.trainerCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.initialMastered == this.initialMastered);
}

class DogsCompanion extends UpdateCompanion<Dog> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> id;
  final Value<String> householdId;
  final Value<String> name;
  final Value<String> birthDate;
  final Value<String> breedId;
  final Value<String> breedText;
  final Value<String> sex;
  final Value<String> homeDate;
  final Value<String> livingEnv;
  final Value<int> dailyMinutes;
  final Value<int> trainerCount;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<String> initialMastered;
  final Value<int> rowid;
  const DogsCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.id = const Value.absent(),
    this.householdId = const Value.absent(),
    this.name = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.breedId = const Value.absent(),
    this.breedText = const Value.absent(),
    this.sex = const Value.absent(),
    this.homeDate = const Value.absent(),
    this.livingEnv = const Value.absent(),
    this.dailyMinutes = const Value.absent(),
    this.trainerCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.initialMastered = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DogsCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String id,
    required String householdId,
    required String name,
    required String birthDate,
    required String breedId,
    required String breedText,
    required String sex,
    required String homeDate,
    required String livingEnv,
    required int dailyMinutes,
    required int trainerCount,
    required String createdAt,
    required String updatedAt,
    this.initialMastered = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        householdId = Value(householdId),
        name = Value(name),
        birthDate = Value(birthDate),
        breedId = Value(breedId),
        breedText = Value(breedText),
        sex = Value(sex),
        homeDate = Value(homeDate),
        livingEnv = Value(livingEnv),
        dailyMinutes = Value(dailyMinutes),
        trainerCount = Value(trainerCount),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<Dog> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? id,
    Expression<String>? householdId,
    Expression<String>? name,
    Expression<String>? birthDate,
    Expression<String>? breedId,
    Expression<String>? breedText,
    Expression<String>? sex,
    Expression<String>? homeDate,
    Expression<String>? livingEnv,
    Expression<int>? dailyMinutes,
    Expression<int>? trainerCount,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<String>? initialMastered,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (id != null) 'id': id,
      if (householdId != null) 'household_id': householdId,
      if (name != null) 'name': name,
      if (birthDate != null) 'birth_date': birthDate,
      if (breedId != null) 'breed_id': breedId,
      if (breedText != null) 'breed_text': breedText,
      if (sex != null) 'sex': sex,
      if (homeDate != null) 'home_date': homeDate,
      if (livingEnv != null) 'living_env': livingEnv,
      if (dailyMinutes != null) 'daily_minutes': dailyMinutes,
      if (trainerCount != null) 'trainer_count': trainerCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (initialMastered != null) 'initial_mastered': initialMastered,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DogsCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? id,
      Value<String>? householdId,
      Value<String>? name,
      Value<String>? birthDate,
      Value<String>? breedId,
      Value<String>? breedText,
      Value<String>? sex,
      Value<String>? homeDate,
      Value<String>? livingEnv,
      Value<int>? dailyMinutes,
      Value<int>? trainerCount,
      Value<String>? createdAt,
      Value<String>? updatedAt,
      Value<String>? initialMastered,
      Value<int>? rowid}) {
    return DogsCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      id: id ?? this.id,
      householdId: householdId ?? this.householdId,
      name: name ?? this.name,
      birthDate: birthDate ?? this.birthDate,
      breedId: breedId ?? this.breedId,
      breedText: breedText ?? this.breedText,
      sex: sex ?? this.sex,
      homeDate: homeDate ?? this.homeDate,
      livingEnv: livingEnv ?? this.livingEnv,
      dailyMinutes: dailyMinutes ?? this.dailyMinutes,
      trainerCount: trainerCount ?? this.trainerCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      initialMastered: initialMastered ?? this.initialMastered,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<String>(birthDate.value);
    }
    if (breedId.present) {
      map['breed_id'] = Variable<String>(breedId.value);
    }
    if (breedText.present) {
      map['breed_text'] = Variable<String>(breedText.value);
    }
    if (sex.present) {
      map['sex'] = Variable<String>(sex.value);
    }
    if (homeDate.present) {
      map['home_date'] = Variable<String>(homeDate.value);
    }
    if (livingEnv.present) {
      map['living_env'] = Variable<String>(livingEnv.value);
    }
    if (dailyMinutes.present) {
      map['daily_minutes'] = Variable<int>(dailyMinutes.value);
    }
    if (trainerCount.present) {
      map['trainer_count'] = Variable<int>(trainerCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (initialMastered.present) {
      map['initial_mastered'] = Variable<String>(initialMastered.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DogsCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('householdId: $householdId, ')
          ..write('name: $name, ')
          ..write('birthDate: $birthDate, ')
          ..write('breedId: $breedId, ')
          ..write('breedText: $breedText, ')
          ..write('sex: $sex, ')
          ..write('homeDate: $homeDate, ')
          ..write('livingEnv: $livingEnv, ')
          ..write('dailyMinutes: $dailyMinutes, ')
          ..write('trainerCount: $trainerCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('initialMastered: $initialMastered, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DogConcernsTable extends DogConcerns
    with TableInfo<$DogConcernsTable, DogConcern> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DogConcernsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _issueIdMeta =
      const VerificationMeta('issueId');
  @override
  late final GeneratedColumn<String> issueId = GeneratedColumn<String>(
      'issue_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [clientUpdatedAt, deleted, dogId, issueId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dog_concerns';
  @override
  VerificationContext validateIntegrity(Insertable<DogConcern> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('issue_id')) {
      context.handle(_issueIdMeta,
          issueId.isAcceptableOrUnknown(data['issue_id']!, _issueIdMeta));
    } else if (isInserting) {
      context.missing(_issueIdMeta);
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
  Set<GeneratedColumn> get $primaryKey => {dogId, issueId};
  @override
  DogConcern map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DogConcern(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      issueId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}issue_id'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DogConcernsTable createAlias(String alias) {
    return $DogConcernsTable(attachedDatabase, alias);
  }
}

class DogConcern extends DataClass implements Insertable<DogConcern> {
  final String clientUpdatedAt;
  final bool deleted;
  final String dogId;
  final String issueId;
  final String createdAt;
  const DogConcern(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.dogId,
      required this.issueId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dog_id'] = Variable<String>(dogId);
    map['issue_id'] = Variable<String>(issueId);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  DogConcernsCompanion toCompanion(bool nullToAbsent) {
    return DogConcernsCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      dogId: Value(dogId),
      issueId: Value(issueId),
      createdAt: Value(createdAt),
    );
  }

  factory DogConcern.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DogConcern(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dogId: serializer.fromJson<String>(json['dogId']),
      issueId: serializer.fromJson<String>(json['issueId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dogId': serializer.toJson<String>(dogId),
      'issueId': serializer.toJson<String>(issueId),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  DogConcern copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? dogId,
          String? issueId,
          String? createdAt}) =>
      DogConcern(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        dogId: dogId ?? this.dogId,
        issueId: issueId ?? this.issueId,
        createdAt: createdAt ?? this.createdAt,
      );
  DogConcern copyWithCompanion(DogConcernsCompanion data) {
    return DogConcern(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      issueId: data.issueId.present ? data.issueId.value : this.issueId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DogConcern(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dogId: $dogId, ')
          ..write('issueId: $issueId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(clientUpdatedAt, deleted, dogId, issueId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DogConcern &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.dogId == this.dogId &&
          other.issueId == this.issueId &&
          other.createdAt == this.createdAt);
}

class DogConcernsCompanion extends UpdateCompanion<DogConcern> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> dogId;
  final Value<String> issueId;
  final Value<String> createdAt;
  final Value<int> rowid;
  const DogConcernsCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dogId = const Value.absent(),
    this.issueId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DogConcernsCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String dogId,
    required String issueId,
    required String createdAt,
    this.rowid = const Value.absent(),
  })  : dogId = Value(dogId),
        issueId = Value(issueId),
        createdAt = Value(createdAt);
  static Insertable<DogConcern> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? dogId,
    Expression<String>? issueId,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dogId != null) 'dog_id': dogId,
      if (issueId != null) 'issue_id': issueId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DogConcernsCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? dogId,
      Value<String>? issueId,
      Value<String>? createdAt,
      Value<int>? rowid}) {
    return DogConcernsCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      dogId: dogId ?? this.dogId,
      issueId: issueId ?? this.issueId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (issueId.present) {
      map['issue_id'] = Variable<String>(issueId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DogConcernsCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dogId: $dogId, ')
          ..write('issueId: $issueId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DogCuesTable extends DogCues with TableInfo<$DogCuesTable, DogCue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DogCuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skillIdMeta =
      const VerificationMeta('skillId');
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
      'skill_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cueWordMeta =
      const VerificationMeta('cueWord');
  @override
  late final GeneratedColumn<String> cueWord = GeneratedColumn<String>(
      'cue_word', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _gestureTextMeta =
      const VerificationMeta('gestureText');
  @override
  late final GeneratedColumn<String> gestureText = GeneratedColumn<String>(
      'gesture_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        dogId,
        skillId,
        cueWord,
        gestureText,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dog_cues';
  @override
  VerificationContext validateIntegrity(Insertable<DogCue> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(_skillIdMeta,
          skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta));
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('cue_word')) {
      context.handle(_cueWordMeta,
          cueWord.isAcceptableOrUnknown(data['cue_word']!, _cueWordMeta));
    } else if (isInserting) {
      context.missing(_cueWordMeta);
    }
    if (data.containsKey('gesture_text')) {
      context.handle(
          _gestureTextMeta,
          gestureText.isAcceptableOrUnknown(
              data['gesture_text']!, _gestureTextMeta));
    } else if (isInserting) {
      context.missing(_gestureTextMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dogId, skillId};
  @override
  DogCue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DogCue(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      skillId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}skill_id'])!,
      cueWord: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cue_word'])!,
      gestureText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}gesture_text'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $DogCuesTable createAlias(String alias) {
    return $DogCuesTable(attachedDatabase, alias);
  }
}

class DogCue extends DataClass implements Insertable<DogCue> {
  final String clientUpdatedAt;
  final bool deleted;
  final String dogId;
  final String skillId;
  final String cueWord;
  final String gestureText;
  final String updatedAt;
  const DogCue(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.dogId,
      required this.skillId,
      required this.cueWord,
      required this.gestureText,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dog_id'] = Variable<String>(dogId);
    map['skill_id'] = Variable<String>(skillId);
    map['cue_word'] = Variable<String>(cueWord);
    map['gesture_text'] = Variable<String>(gestureText);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  DogCuesCompanion toCompanion(bool nullToAbsent) {
    return DogCuesCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      dogId: Value(dogId),
      skillId: Value(skillId),
      cueWord: Value(cueWord),
      gestureText: Value(gestureText),
      updatedAt: Value(updatedAt),
    );
  }

  factory DogCue.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DogCue(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dogId: serializer.fromJson<String>(json['dogId']),
      skillId: serializer.fromJson<String>(json['skillId']),
      cueWord: serializer.fromJson<String>(json['cueWord']),
      gestureText: serializer.fromJson<String>(json['gestureText']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dogId': serializer.toJson<String>(dogId),
      'skillId': serializer.toJson<String>(skillId),
      'cueWord': serializer.toJson<String>(cueWord),
      'gestureText': serializer.toJson<String>(gestureText),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  DogCue copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? dogId,
          String? skillId,
          String? cueWord,
          String? gestureText,
          String? updatedAt}) =>
      DogCue(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        dogId: dogId ?? this.dogId,
        skillId: skillId ?? this.skillId,
        cueWord: cueWord ?? this.cueWord,
        gestureText: gestureText ?? this.gestureText,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  DogCue copyWithCompanion(DogCuesCompanion data) {
    return DogCue(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      cueWord: data.cueWord.present ? data.cueWord.value : this.cueWord,
      gestureText:
          data.gestureText.present ? data.gestureText.value : this.gestureText,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DogCue(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dogId: $dogId, ')
          ..write('skillId: $skillId, ')
          ..write('cueWord: $cueWord, ')
          ..write('gestureText: $gestureText, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientUpdatedAt, deleted, dogId, skillId,
      cueWord, gestureText, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DogCue &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.dogId == this.dogId &&
          other.skillId == this.skillId &&
          other.cueWord == this.cueWord &&
          other.gestureText == this.gestureText &&
          other.updatedAt == this.updatedAt);
}

class DogCuesCompanion extends UpdateCompanion<DogCue> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> dogId;
  final Value<String> skillId;
  final Value<String> cueWord;
  final Value<String> gestureText;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const DogCuesCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dogId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.cueWord = const Value.absent(),
    this.gestureText = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DogCuesCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String dogId,
    required String skillId,
    required String cueWord,
    required String gestureText,
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : dogId = Value(dogId),
        skillId = Value(skillId),
        cueWord = Value(cueWord),
        gestureText = Value(gestureText),
        updatedAt = Value(updatedAt);
  static Insertable<DogCue> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? dogId,
    Expression<String>? skillId,
    Expression<String>? cueWord,
    Expression<String>? gestureText,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dogId != null) 'dog_id': dogId,
      if (skillId != null) 'skill_id': skillId,
      if (cueWord != null) 'cue_word': cueWord,
      if (gestureText != null) 'gesture_text': gestureText,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DogCuesCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? dogId,
      Value<String>? skillId,
      Value<String>? cueWord,
      Value<String>? gestureText,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return DogCuesCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      dogId: dogId ?? this.dogId,
      skillId: skillId ?? this.skillId,
      cueWord: cueWord ?? this.cueWord,
      gestureText: gestureText ?? this.gestureText,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (cueWord.present) {
      map['cue_word'] = Variable<String>(cueWord.value);
    }
    if (gestureText.present) {
      map['gesture_text'] = Variable<String>(gestureText.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DogCuesCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dogId: $dogId, ')
          ..write('skillId: $skillId, ')
          ..write('cueWord: $cueWord, ')
          ..write('gestureText: $gestureText, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DogSkillStatusesTable extends DogSkillStatuses
    with TableInfo<$DogSkillStatusesTable, DogSkillStatuse> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DogSkillStatusesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skillIdMeta =
      const VerificationMeta('skillId');
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
      'skill_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _masteredAtMeta =
      const VerificationMeta('masteredAt');
  @override
  late final GeneratedColumn<String> masteredAt = GeneratedColumn<String>(
      'mastered_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _fullSuccessCountMeta =
      const VerificationMeta('fullSuccessCount');
  @override
  late final GeneratedColumn<int> fullSuccessCount = GeneratedColumn<int>(
      'full_success_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _failCountMeta =
      const VerificationMeta('failCount');
  @override
  late final GeneratedColumn<int> failCount = GeneratedColumn<int>(
      'fail_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [dogId, skillId, status, masteredAt, fullSuccessCount, failCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dog_skill_statuses';
  @override
  VerificationContext validateIntegrity(Insertable<DogSkillStatuse> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(_skillIdMeta,
          skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta));
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('mastered_at')) {
      context.handle(
          _masteredAtMeta,
          masteredAt.isAcceptableOrUnknown(
              data['mastered_at']!, _masteredAtMeta));
    }
    if (data.containsKey('full_success_count')) {
      context.handle(
          _fullSuccessCountMeta,
          fullSuccessCount.isAcceptableOrUnknown(
              data['full_success_count']!, _fullSuccessCountMeta));
    }
    if (data.containsKey('fail_count')) {
      context.handle(_failCountMeta,
          failCount.isAcceptableOrUnknown(data['fail_count']!, _failCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dogId, skillId};
  @override
  DogSkillStatuse map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DogSkillStatuse(
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      skillId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}skill_id'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      masteredAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mastered_at']),
      fullSuccessCount: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}full_success_count'])!,
      failCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}fail_count'])!,
    );
  }

  @override
  $DogSkillStatusesTable createAlias(String alias) {
    return $DogSkillStatusesTable(attachedDatabase, alias);
  }
}

class DogSkillStatuse extends DataClass implements Insertable<DogSkillStatuse> {
  final String dogId;
  final String skillId;
  final String status;
  final String? masteredAt;
  final int fullSuccessCount;
  final int failCount;
  const DogSkillStatuse(
      {required this.dogId,
      required this.skillId,
      required this.status,
      this.masteredAt,
      required this.fullSuccessCount,
      required this.failCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dog_id'] = Variable<String>(dogId);
    map['skill_id'] = Variable<String>(skillId);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || masteredAt != null) {
      map['mastered_at'] = Variable<String>(masteredAt);
    }
    map['full_success_count'] = Variable<int>(fullSuccessCount);
    map['fail_count'] = Variable<int>(failCount);
    return map;
  }

  DogSkillStatusesCompanion toCompanion(bool nullToAbsent) {
    return DogSkillStatusesCompanion(
      dogId: Value(dogId),
      skillId: Value(skillId),
      status: Value(status),
      masteredAt: masteredAt == null && nullToAbsent
          ? const Value.absent()
          : Value(masteredAt),
      fullSuccessCount: Value(fullSuccessCount),
      failCount: Value(failCount),
    );
  }

  factory DogSkillStatuse.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DogSkillStatuse(
      dogId: serializer.fromJson<String>(json['dogId']),
      skillId: serializer.fromJson<String>(json['skillId']),
      status: serializer.fromJson<String>(json['status']),
      masteredAt: serializer.fromJson<String?>(json['masteredAt']),
      fullSuccessCount: serializer.fromJson<int>(json['fullSuccessCount']),
      failCount: serializer.fromJson<int>(json['failCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dogId': serializer.toJson<String>(dogId),
      'skillId': serializer.toJson<String>(skillId),
      'status': serializer.toJson<String>(status),
      'masteredAt': serializer.toJson<String?>(masteredAt),
      'fullSuccessCount': serializer.toJson<int>(fullSuccessCount),
      'failCount': serializer.toJson<int>(failCount),
    };
  }

  DogSkillStatuse copyWith(
          {String? dogId,
          String? skillId,
          String? status,
          Value<String?> masteredAt = const Value.absent(),
          int? fullSuccessCount,
          int? failCount}) =>
      DogSkillStatuse(
        dogId: dogId ?? this.dogId,
        skillId: skillId ?? this.skillId,
        status: status ?? this.status,
        masteredAt: masteredAt.present ? masteredAt.value : this.masteredAt,
        fullSuccessCount: fullSuccessCount ?? this.fullSuccessCount,
        failCount: failCount ?? this.failCount,
      );
  DogSkillStatuse copyWithCompanion(DogSkillStatusesCompanion data) {
    return DogSkillStatuse(
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      status: data.status.present ? data.status.value : this.status,
      masteredAt:
          data.masteredAt.present ? data.masteredAt.value : this.masteredAt,
      fullSuccessCount: data.fullSuccessCount.present
          ? data.fullSuccessCount.value
          : this.fullSuccessCount,
      failCount: data.failCount.present ? data.failCount.value : this.failCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DogSkillStatuse(')
          ..write('dogId: $dogId, ')
          ..write('skillId: $skillId, ')
          ..write('status: $status, ')
          ..write('masteredAt: $masteredAt, ')
          ..write('fullSuccessCount: $fullSuccessCount, ')
          ..write('failCount: $failCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      dogId, skillId, status, masteredAt, fullSuccessCount, failCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DogSkillStatuse &&
          other.dogId == this.dogId &&
          other.skillId == this.skillId &&
          other.status == this.status &&
          other.masteredAt == this.masteredAt &&
          other.fullSuccessCount == this.fullSuccessCount &&
          other.failCount == this.failCount);
}

class DogSkillStatusesCompanion extends UpdateCompanion<DogSkillStatuse> {
  final Value<String> dogId;
  final Value<String> skillId;
  final Value<String> status;
  final Value<String?> masteredAt;
  final Value<int> fullSuccessCount;
  final Value<int> failCount;
  final Value<int> rowid;
  const DogSkillStatusesCompanion({
    this.dogId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.status = const Value.absent(),
    this.masteredAt = const Value.absent(),
    this.fullSuccessCount = const Value.absent(),
    this.failCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DogSkillStatusesCompanion.insert({
    required String dogId,
    required String skillId,
    required String status,
    this.masteredAt = const Value.absent(),
    this.fullSuccessCount = const Value.absent(),
    this.failCount = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : dogId = Value(dogId),
        skillId = Value(skillId),
        status = Value(status);
  static Insertable<DogSkillStatuse> custom({
    Expression<String>? dogId,
    Expression<String>? skillId,
    Expression<String>? status,
    Expression<String>? masteredAt,
    Expression<int>? fullSuccessCount,
    Expression<int>? failCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dogId != null) 'dog_id': dogId,
      if (skillId != null) 'skill_id': skillId,
      if (status != null) 'status': status,
      if (masteredAt != null) 'mastered_at': masteredAt,
      if (fullSuccessCount != null) 'full_success_count': fullSuccessCount,
      if (failCount != null) 'fail_count': failCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DogSkillStatusesCompanion copyWith(
      {Value<String>? dogId,
      Value<String>? skillId,
      Value<String>? status,
      Value<String?>? masteredAt,
      Value<int>? fullSuccessCount,
      Value<int>? failCount,
      Value<int>? rowid}) {
    return DogSkillStatusesCompanion(
      dogId: dogId ?? this.dogId,
      skillId: skillId ?? this.skillId,
      status: status ?? this.status,
      masteredAt: masteredAt ?? this.masteredAt,
      fullSuccessCount: fullSuccessCount ?? this.fullSuccessCount,
      failCount: failCount ?? this.failCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (masteredAt.present) {
      map['mastered_at'] = Variable<String>(masteredAt.value);
    }
    if (fullSuccessCount.present) {
      map['full_success_count'] = Variable<int>(fullSuccessCount.value);
    }
    if (failCount.present) {
      map['fail_count'] = Variable<int>(failCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DogSkillStatusesCompanion(')
          ..write('dogId: $dogId, ')
          ..write('skillId: $skillId, ')
          ..write('status: $status, ')
          ..write('masteredAt: $masteredAt, ')
          ..write('fullSuccessCount: $fullSuccessCount, ')
          ..write('failCount: $failCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeeklyPlansTable extends WeeklyPlans
    with TableInfo<$WeeklyPlansTable, WeeklyPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _weekStartMeta =
      const VerificationMeta('weekStart');
  @override
  late final GeneratedColumn<String> weekStart = GeneratedColumn<String>(
      'week_start', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _generatedByMeta =
      const VerificationMeta('generatedBy');
  @override
  late final GeneratedColumn<String> generatedBy = GeneratedColumn<String>(
      'generated_by', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _regenerateNextMeta =
      const VerificationMeta('regenerateNext');
  @override
  late final GeneratedColumn<bool> regenerateNext = GeneratedColumn<bool>(
      'regenerate_next', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("regenerate_next" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _pendingDiagnosisSkillsMeta =
      const VerificationMeta('pendingDiagnosisSkills');
  @override
  late final GeneratedColumn<String> pendingDiagnosisSkills =
      GeneratedColumn<String>('pending_diagnosis_skills', aliasedName, false,
          type: DriftSqlType.string,
          requiredDuringInsert: false,
          defaultValue: const Constant('[]'));
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        id,
        dogId,
        weekStart,
        generatedBy,
        status,
        createdAt,
        regenerateNext,
        pendingDiagnosisSkills
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_plans';
  @override
  VerificationContext validateIntegrity(Insertable<WeeklyPlan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('week_start')) {
      context.handle(_weekStartMeta,
          weekStart.isAcceptableOrUnknown(data['week_start']!, _weekStartMeta));
    } else if (isInserting) {
      context.missing(_weekStartMeta);
    }
    if (data.containsKey('generated_by')) {
      context.handle(
          _generatedByMeta,
          generatedBy.isAcceptableOrUnknown(
              data['generated_by']!, _generatedByMeta));
    } else if (isInserting) {
      context.missing(_generatedByMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('regenerate_next')) {
      context.handle(
          _regenerateNextMeta,
          regenerateNext.isAcceptableOrUnknown(
              data['regenerate_next']!, _regenerateNextMeta));
    }
    if (data.containsKey('pending_diagnosis_skills')) {
      context.handle(
          _pendingDiagnosisSkillsMeta,
          pendingDiagnosisSkills.isAcceptableOrUnknown(
              data['pending_diagnosis_skills']!, _pendingDiagnosisSkillsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {dogId, weekStart},
      ];
  @override
  WeeklyPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyPlan(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      weekStart: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}week_start'])!,
      generatedBy: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}generated_by'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      regenerateNext: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}regenerate_next'])!,
      pendingDiagnosisSkills: attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}pending_diagnosis_skills'])!,
    );
  }

  @override
  $WeeklyPlansTable createAlias(String alias) {
    return $WeeklyPlansTable(attachedDatabase, alias);
  }
}

class WeeklyPlan extends DataClass implements Insertable<WeeklyPlan> {
  final String clientUpdatedAt;
  final bool deleted;
  final String id;
  final String dogId;
  final String weekStart;
  final String generatedBy;
  final String status;
  final String createdAt;

  /// M2 起：ON-7 在本周已有记录时改了出生日期 / 困扰 / 每日时长，
  /// 下周生成走"全新生成"而不是 WP-6 调整。
  final bool regenerateNext;

  /// M3 起：诊断方案"加入下周计划"的技能 ID，JSON 数组。
  /// 生成下周计划时优先放入（source = ai_diagnosis），见 nextWeekPlan()。
  final String pendingDiagnosisSkills;
  const WeeklyPlan(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.id,
      required this.dogId,
      required this.weekStart,
      required this.generatedBy,
      required this.status,
      required this.createdAt,
      required this.regenerateNext,
      required this.pendingDiagnosisSkills});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['id'] = Variable<String>(id);
    map['dog_id'] = Variable<String>(dogId);
    map['week_start'] = Variable<String>(weekStart);
    map['generated_by'] = Variable<String>(generatedBy);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<String>(createdAt);
    map['regenerate_next'] = Variable<bool>(regenerateNext);
    map['pending_diagnosis_skills'] = Variable<String>(pendingDiagnosisSkills);
    return map;
  }

  WeeklyPlansCompanion toCompanion(bool nullToAbsent) {
    return WeeklyPlansCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      id: Value(id),
      dogId: Value(dogId),
      weekStart: Value(weekStart),
      generatedBy: Value(generatedBy),
      status: Value(status),
      createdAt: Value(createdAt),
      regenerateNext: Value(regenerateNext),
      pendingDiagnosisSkills: Value(pendingDiagnosisSkills),
    );
  }

  factory WeeklyPlan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyPlan(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      id: serializer.fromJson<String>(json['id']),
      dogId: serializer.fromJson<String>(json['dogId']),
      weekStart: serializer.fromJson<String>(json['weekStart']),
      generatedBy: serializer.fromJson<String>(json['generatedBy']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      regenerateNext: serializer.fromJson<bool>(json['regenerateNext']),
      pendingDiagnosisSkills:
          serializer.fromJson<String>(json['pendingDiagnosisSkills']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'id': serializer.toJson<String>(id),
      'dogId': serializer.toJson<String>(dogId),
      'weekStart': serializer.toJson<String>(weekStart),
      'generatedBy': serializer.toJson<String>(generatedBy),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<String>(createdAt),
      'regenerateNext': serializer.toJson<bool>(regenerateNext),
      'pendingDiagnosisSkills':
          serializer.toJson<String>(pendingDiagnosisSkills),
    };
  }

  WeeklyPlan copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? id,
          String? dogId,
          String? weekStart,
          String? generatedBy,
          String? status,
          String? createdAt,
          bool? regenerateNext,
          String? pendingDiagnosisSkills}) =>
      WeeklyPlan(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        id: id ?? this.id,
        dogId: dogId ?? this.dogId,
        weekStart: weekStart ?? this.weekStart,
        generatedBy: generatedBy ?? this.generatedBy,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        regenerateNext: regenerateNext ?? this.regenerateNext,
        pendingDiagnosisSkills:
            pendingDiagnosisSkills ?? this.pendingDiagnosisSkills,
      );
  WeeklyPlan copyWithCompanion(WeeklyPlansCompanion data) {
    return WeeklyPlan(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      id: data.id.present ? data.id.value : this.id,
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      weekStart: data.weekStart.present ? data.weekStart.value : this.weekStart,
      generatedBy:
          data.generatedBy.present ? data.generatedBy.value : this.generatedBy,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      regenerateNext: data.regenerateNext.present
          ? data.regenerateNext.value
          : this.regenerateNext,
      pendingDiagnosisSkills: data.pendingDiagnosisSkills.present
          ? data.pendingDiagnosisSkills.value
          : this.pendingDiagnosisSkills,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyPlan(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('dogId: $dogId, ')
          ..write('weekStart: $weekStart, ')
          ..write('generatedBy: $generatedBy, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('regenerateNext: $regenerateNext, ')
          ..write('pendingDiagnosisSkills: $pendingDiagnosisSkills')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientUpdatedAt,
      deleted,
      id,
      dogId,
      weekStart,
      generatedBy,
      status,
      createdAt,
      regenerateNext,
      pendingDiagnosisSkills);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyPlan &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.id == this.id &&
          other.dogId == this.dogId &&
          other.weekStart == this.weekStart &&
          other.generatedBy == this.generatedBy &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.regenerateNext == this.regenerateNext &&
          other.pendingDiagnosisSkills == this.pendingDiagnosisSkills);
}

class WeeklyPlansCompanion extends UpdateCompanion<WeeklyPlan> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> id;
  final Value<String> dogId;
  final Value<String> weekStart;
  final Value<String> generatedBy;
  final Value<String> status;
  final Value<String> createdAt;
  final Value<bool> regenerateNext;
  final Value<String> pendingDiagnosisSkills;
  final Value<int> rowid;
  const WeeklyPlansCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.id = const Value.absent(),
    this.dogId = const Value.absent(),
    this.weekStart = const Value.absent(),
    this.generatedBy = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.regenerateNext = const Value.absent(),
    this.pendingDiagnosisSkills = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeeklyPlansCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String id,
    required String dogId,
    required String weekStart,
    required String generatedBy,
    required String status,
    required String createdAt,
    this.regenerateNext = const Value.absent(),
    this.pendingDiagnosisSkills = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        dogId = Value(dogId),
        weekStart = Value(weekStart),
        generatedBy = Value(generatedBy),
        status = Value(status),
        createdAt = Value(createdAt);
  static Insertable<WeeklyPlan> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? id,
    Expression<String>? dogId,
    Expression<String>? weekStart,
    Expression<String>? generatedBy,
    Expression<String>? status,
    Expression<String>? createdAt,
    Expression<bool>? regenerateNext,
    Expression<String>? pendingDiagnosisSkills,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (id != null) 'id': id,
      if (dogId != null) 'dog_id': dogId,
      if (weekStart != null) 'week_start': weekStart,
      if (generatedBy != null) 'generated_by': generatedBy,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (regenerateNext != null) 'regenerate_next': regenerateNext,
      if (pendingDiagnosisSkills != null)
        'pending_diagnosis_skills': pendingDiagnosisSkills,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeeklyPlansCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? id,
      Value<String>? dogId,
      Value<String>? weekStart,
      Value<String>? generatedBy,
      Value<String>? status,
      Value<String>? createdAt,
      Value<bool>? regenerateNext,
      Value<String>? pendingDiagnosisSkills,
      Value<int>? rowid}) {
    return WeeklyPlansCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      id: id ?? this.id,
      dogId: dogId ?? this.dogId,
      weekStart: weekStart ?? this.weekStart,
      generatedBy: generatedBy ?? this.generatedBy,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      regenerateNext: regenerateNext ?? this.regenerateNext,
      pendingDiagnosisSkills:
          pendingDiagnosisSkills ?? this.pendingDiagnosisSkills,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (weekStart.present) {
      map['week_start'] = Variable<String>(weekStart.value);
    }
    if (generatedBy.present) {
      map['generated_by'] = Variable<String>(generatedBy.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (regenerateNext.present) {
      map['regenerate_next'] = Variable<bool>(regenerateNext.value);
    }
    if (pendingDiagnosisSkills.present) {
      map['pending_diagnosis_skills'] =
          Variable<String>(pendingDiagnosisSkills.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyPlansCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('dogId: $dogId, ')
          ..write('weekStart: $weekStart, ')
          ..write('generatedBy: $generatedBy, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('regenerateNext: $regenerateNext, ')
          ..write('pendingDiagnosisSkills: $pendingDiagnosisSkills, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlanGoalsTable extends PlanGoals
    with TableInfo<$PlanGoalsTable, PlanGoal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlanGoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skillIdMeta =
      const VerificationMeta('skillId');
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
      'skill_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _targetSessionsMeta =
      const VerificationMeta('targetSessions');
  @override
  late final GeneratedColumn<int> targetSessions = GeneratedColumn<int>(
      'target_sessions', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _completedSessionsMeta =
      const VerificationMeta('completedSessions');
  @override
  late final GeneratedColumn<int> completedSessions = GeneratedColumn<int>(
      'completed_sessions', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        planId,
        skillId,
        position,
        targetSessions,
        completedSessions,
        source
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'plan_goals';
  @override
  VerificationContext validateIntegrity(Insertable<PlanGoal> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(_skillIdMeta,
          skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta));
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    if (data.containsKey('target_sessions')) {
      context.handle(
          _targetSessionsMeta,
          targetSessions.isAcceptableOrUnknown(
              data['target_sessions']!, _targetSessionsMeta));
    } else if (isInserting) {
      context.missing(_targetSessionsMeta);
    }
    if (data.containsKey('completed_sessions')) {
      context.handle(
          _completedSessionsMeta,
          completedSessions.isAcceptableOrUnknown(
              data['completed_sessions']!, _completedSessionsMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {planId, skillId};
  @override
  PlanGoal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlanGoal(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id'])!,
      skillId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}skill_id'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
      targetSessions: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}target_sessions'])!,
      completedSessions: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}completed_sessions'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
    );
  }

  @override
  $PlanGoalsTable createAlias(String alias) {
    return $PlanGoalsTable(attachedDatabase, alias);
  }
}

class PlanGoal extends DataClass implements Insertable<PlanGoal> {
  final String clientUpdatedAt;
  final bool deleted;
  final String planId;
  final String skillId;
  final int position;
  final int targetSessions;
  final int completedSessions;
  final String source;
  const PlanGoal(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.planId,
      required this.skillId,
      required this.position,
      required this.targetSessions,
      required this.completedSessions,
      required this.source});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['plan_id'] = Variable<String>(planId);
    map['skill_id'] = Variable<String>(skillId);
    map['position'] = Variable<int>(position);
    map['target_sessions'] = Variable<int>(targetSessions);
    map['completed_sessions'] = Variable<int>(completedSessions);
    map['source'] = Variable<String>(source);
    return map;
  }

  PlanGoalsCompanion toCompanion(bool nullToAbsent) {
    return PlanGoalsCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      planId: Value(planId),
      skillId: Value(skillId),
      position: Value(position),
      targetSessions: Value(targetSessions),
      completedSessions: Value(completedSessions),
      source: Value(source),
    );
  }

  factory PlanGoal.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlanGoal(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      planId: serializer.fromJson<String>(json['planId']),
      skillId: serializer.fromJson<String>(json['skillId']),
      position: serializer.fromJson<int>(json['position']),
      targetSessions: serializer.fromJson<int>(json['targetSessions']),
      completedSessions: serializer.fromJson<int>(json['completedSessions']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'planId': serializer.toJson<String>(planId),
      'skillId': serializer.toJson<String>(skillId),
      'position': serializer.toJson<int>(position),
      'targetSessions': serializer.toJson<int>(targetSessions),
      'completedSessions': serializer.toJson<int>(completedSessions),
      'source': serializer.toJson<String>(source),
    };
  }

  PlanGoal copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? planId,
          String? skillId,
          int? position,
          int? targetSessions,
          int? completedSessions,
          String? source}) =>
      PlanGoal(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        planId: planId ?? this.planId,
        skillId: skillId ?? this.skillId,
        position: position ?? this.position,
        targetSessions: targetSessions ?? this.targetSessions,
        completedSessions: completedSessions ?? this.completedSessions,
        source: source ?? this.source,
      );
  PlanGoal copyWithCompanion(PlanGoalsCompanion data) {
    return PlanGoal(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      planId: data.planId.present ? data.planId.value : this.planId,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      position: data.position.present ? data.position.value : this.position,
      targetSessions: data.targetSessions.present
          ? data.targetSessions.value
          : this.targetSessions,
      completedSessions: data.completedSessions.present
          ? data.completedSessions.value
          : this.completedSessions,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlanGoal(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('planId: $planId, ')
          ..write('skillId: $skillId, ')
          ..write('position: $position, ')
          ..write('targetSessions: $targetSessions, ')
          ..write('completedSessions: $completedSessions, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientUpdatedAt, deleted, planId, skillId,
      position, targetSessions, completedSessions, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlanGoal &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.planId == this.planId &&
          other.skillId == this.skillId &&
          other.position == this.position &&
          other.targetSessions == this.targetSessions &&
          other.completedSessions == this.completedSessions &&
          other.source == this.source);
}

class PlanGoalsCompanion extends UpdateCompanion<PlanGoal> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> planId;
  final Value<String> skillId;
  final Value<int> position;
  final Value<int> targetSessions;
  final Value<int> completedSessions;
  final Value<String> source;
  final Value<int> rowid;
  const PlanGoalsCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.planId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.position = const Value.absent(),
    this.targetSessions = const Value.absent(),
    this.completedSessions = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlanGoalsCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String planId,
    required String skillId,
    required int position,
    required int targetSessions,
    this.completedSessions = const Value.absent(),
    required String source,
    this.rowid = const Value.absent(),
  })  : planId = Value(planId),
        skillId = Value(skillId),
        position = Value(position),
        targetSessions = Value(targetSessions),
        source = Value(source);
  static Insertable<PlanGoal> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? planId,
    Expression<String>? skillId,
    Expression<int>? position,
    Expression<int>? targetSessions,
    Expression<int>? completedSessions,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (planId != null) 'plan_id': planId,
      if (skillId != null) 'skill_id': skillId,
      if (position != null) 'position': position,
      if (targetSessions != null) 'target_sessions': targetSessions,
      if (completedSessions != null) 'completed_sessions': completedSessions,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlanGoalsCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? planId,
      Value<String>? skillId,
      Value<int>? position,
      Value<int>? targetSessions,
      Value<int>? completedSessions,
      Value<String>? source,
      Value<int>? rowid}) {
    return PlanGoalsCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      planId: planId ?? this.planId,
      skillId: skillId ?? this.skillId,
      position: position ?? this.position,
      targetSessions: targetSessions ?? this.targetSessions,
      completedSessions: completedSessions ?? this.completedSessions,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (targetSessions.present) {
      map['target_sessions'] = Variable<int>(targetSessions.value);
    }
    if (completedSessions.present) {
      map['completed_sessions'] = Variable<int>(completedSessions.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlanGoalsCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('planId: $planId, ')
          ..write('skillId: $skillId, ')
          ..write('position: $position, ')
          ..write('targetSessions: $targetSessions, ')
          ..write('completedSessions: $completedSessions, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DailyMiniTasksTable extends DailyMiniTasks
    with TableInfo<$DailyMiniTasksTable, DailyMiniTask> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyMiniTasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skillIdMeta =
      const VerificationMeta('skillId');
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
      'skill_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scriptPartMeta =
      const VerificationMeta('scriptPart');
  @override
  late final GeneratedColumn<int> scriptPart = GeneratedColumn<int>(
      'script_part', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [clientUpdatedAt, deleted, planId, skillId, scriptPart];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_mini_tasks';
  @override
  VerificationContext validateIntegrity(Insertable<DailyMiniTask> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(_skillIdMeta,
          skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta));
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('script_part')) {
      context.handle(
          _scriptPartMeta,
          scriptPart.isAcceptableOrUnknown(
              data['script_part']!, _scriptPartMeta));
    } else if (isInserting) {
      context.missing(_scriptPartMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {planId};
  @override
  DailyMiniTask map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyMiniTask(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id'])!,
      skillId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}skill_id'])!,
      scriptPart: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}script_part'])!,
    );
  }

  @override
  $DailyMiniTasksTable createAlias(String alias) {
    return $DailyMiniTasksTable(attachedDatabase, alias);
  }
}

class DailyMiniTask extends DataClass implements Insertable<DailyMiniTask> {
  final String clientUpdatedAt;
  final bool deleted;
  final String planId;
  final String skillId;
  final int scriptPart;
  const DailyMiniTask(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.planId,
      required this.skillId,
      required this.scriptPart});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['plan_id'] = Variable<String>(planId);
    map['skill_id'] = Variable<String>(skillId);
    map['script_part'] = Variable<int>(scriptPart);
    return map;
  }

  DailyMiniTasksCompanion toCompanion(bool nullToAbsent) {
    return DailyMiniTasksCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      planId: Value(planId),
      skillId: Value(skillId),
      scriptPart: Value(scriptPart),
    );
  }

  factory DailyMiniTask.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyMiniTask(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      planId: serializer.fromJson<String>(json['planId']),
      skillId: serializer.fromJson<String>(json['skillId']),
      scriptPart: serializer.fromJson<int>(json['scriptPart']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'planId': serializer.toJson<String>(planId),
      'skillId': serializer.toJson<String>(skillId),
      'scriptPart': serializer.toJson<int>(scriptPart),
    };
  }

  DailyMiniTask copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? planId,
          String? skillId,
          int? scriptPart}) =>
      DailyMiniTask(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        planId: planId ?? this.planId,
        skillId: skillId ?? this.skillId,
        scriptPart: scriptPart ?? this.scriptPart,
      );
  DailyMiniTask copyWithCompanion(DailyMiniTasksCompanion data) {
    return DailyMiniTask(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      planId: data.planId.present ? data.planId.value : this.planId,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      scriptPart:
          data.scriptPart.present ? data.scriptPart.value : this.scriptPart,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyMiniTask(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('planId: $planId, ')
          ..write('skillId: $skillId, ')
          ..write('scriptPart: $scriptPart')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(clientUpdatedAt, deleted, planId, skillId, scriptPart);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyMiniTask &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.planId == this.planId &&
          other.skillId == this.skillId &&
          other.scriptPart == this.scriptPart);
}

class DailyMiniTasksCompanion extends UpdateCompanion<DailyMiniTask> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> planId;
  final Value<String> skillId;
  final Value<int> scriptPart;
  final Value<int> rowid;
  const DailyMiniTasksCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.planId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.scriptPart = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DailyMiniTasksCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String planId,
    required String skillId,
    required int scriptPart,
    this.rowid = const Value.absent(),
  })  : planId = Value(planId),
        skillId = Value(skillId),
        scriptPart = Value(scriptPart);
  static Insertable<DailyMiniTask> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? planId,
    Expression<String>? skillId,
    Expression<int>? scriptPart,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (planId != null) 'plan_id': planId,
      if (skillId != null) 'skill_id': skillId,
      if (scriptPart != null) 'script_part': scriptPart,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DailyMiniTasksCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? planId,
      Value<String>? skillId,
      Value<int>? scriptPart,
      Value<int>? rowid}) {
    return DailyMiniTasksCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      planId: planId ?? this.planId,
      skillId: skillId ?? this.skillId,
      scriptPart: scriptPart ?? this.scriptPart,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (scriptPart.present) {
      map['script_part'] = Variable<int>(scriptPart.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyMiniTasksCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('planId: $planId, ')
          ..write('skillId: $skillId, ')
          ..write('scriptPart: $scriptPart, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OnboardingDraftsTable extends OnboardingDrafts
    with TableInfo<$OnboardingDraftsTable, OnboardingDraft> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OnboardingDraftsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, json, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'onboarding_drafts';
  @override
  VerificationContext validateIntegrity(Insertable<OnboardingDraft> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OnboardingDraft map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OnboardingDraft(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $OnboardingDraftsTable createAlias(String alias) {
    return $OnboardingDraftsTable(attachedDatabase, alias);
  }
}

class OnboardingDraft extends DataClass implements Insertable<OnboardingDraft> {
  final int id;
  final String json;
  final String updatedAt;
  const OnboardingDraft(
      {required this.id, required this.json, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['json'] = Variable<String>(json);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  OnboardingDraftsCompanion toCompanion(bool nullToAbsent) {
    return OnboardingDraftsCompanion(
      id: Value(id),
      json: Value(json),
      updatedAt: Value(updatedAt),
    );
  }

  factory OnboardingDraft.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OnboardingDraft(
      id: serializer.fromJson<int>(json['id']),
      json: serializer.fromJson<String>(json['json']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'json': serializer.toJson<String>(json),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  OnboardingDraft copyWith({int? id, String? json, String? updatedAt}) =>
      OnboardingDraft(
        id: id ?? this.id,
        json: json ?? this.json,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  OnboardingDraft copyWithCompanion(OnboardingDraftsCompanion data) {
    return OnboardingDraft(
      id: data.id.present ? data.id.value : this.id,
      json: data.json.present ? data.json.value : this.json,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingDraft(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, json, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OnboardingDraft &&
          other.id == this.id &&
          other.json == this.json &&
          other.updatedAt == this.updatedAt);
}

class OnboardingDraftsCompanion extends UpdateCompanion<OnboardingDraft> {
  final Value<int> id;
  final Value<String> json;
  final Value<String> updatedAt;
  const OnboardingDraftsCompanion({
    this.id = const Value.absent(),
    this.json = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  OnboardingDraftsCompanion.insert({
    this.id = const Value.absent(),
    required String json,
    required String updatedAt,
  })  : json = Value(json),
        updatedAt = Value(updatedAt);
  static Insertable<OnboardingDraft> custom({
    Expression<int>? id,
    Expression<String>? json,
    Expression<String>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (json != null) 'json': json,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  OnboardingDraftsCompanion copyWith(
      {Value<int>? id, Value<String>? json, Value<String>? updatedAt}) {
    return OnboardingDraftsCompanion(
      id: id ?? this.id,
      json: json ?? this.json,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OnboardingDraftsCompanion(')
          ..write('id: $id, ')
          ..write('json: $json, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TrainingSessionsTable extends TrainingSessions
    with TableInfo<$TrainingSessionsTable, TrainingSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrainingSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skillIdMeta =
      const VerificationMeta('skillId');
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
      'skill_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scriptPartMeta =
      const VerificationMeta('scriptPart');
  @override
  late final GeneratedColumn<int> scriptPart = GeneratedColumn<int>(
      'script_part', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
      'started_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<String> endedAt = GeneratedColumn<String>(
      'ended_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationSecMeta =
      const VerificationMeta('durationSec');
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
      'duration_sec', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _scoreMeta = const VerificationMeta('score');
  @override
  late final GeneratedColumn<String> score = GeneratedColumn<String>(
      'score', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteTextMeta =
      const VerificationMeta('noteText');
  @override
  late final GeneratedColumn<String> noteText = GeneratedColumn<String>(
      'note_text', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _noteVideoUrlMeta =
      const VerificationMeta('noteVideoUrl');
  @override
  late final GeneratedColumn<String> noteVideoUrl = GeneratedColumn<String>(
      'note_video_url', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _skippedStepsMeta =
      const VerificationMeta('skippedSteps');
  @override
  late final GeneratedColumn<String> skippedSteps = GeneratedColumn<String>(
      'skipped_steps', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _clickerCountMeta =
      const VerificationMeta('clickerCount');
  @override
  late final GeneratedColumn<int> clickerCount = GeneratedColumn<int>(
      'clicker_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<String> syncedAt = GeneratedColumn<String>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        id,
        dogId,
        userId,
        skillId,
        scriptPart,
        startedAt,
        endedAt,
        durationSec,
        score,
        noteText,
        noteVideoUrl,
        skippedSteps,
        clickerCount,
        syncedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'training_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<TrainingSession> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(_skillIdMeta,
          skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta));
    } else if (isInserting) {
      context.missing(_skillIdMeta);
    }
    if (data.containsKey('script_part')) {
      context.handle(
          _scriptPartMeta,
          scriptPart.isAcceptableOrUnknown(
              data['script_part']!, _scriptPartMeta));
    } else if (isInserting) {
      context.missing(_scriptPartMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
          _durationSecMeta,
          durationSec.isAcceptableOrUnknown(
              data['duration_sec']!, _durationSecMeta));
    } else if (isInserting) {
      context.missing(_durationSecMeta);
    }
    if (data.containsKey('score')) {
      context.handle(
          _scoreMeta, score.isAcceptableOrUnknown(data['score']!, _scoreMeta));
    } else if (isInserting) {
      context.missing(_scoreMeta);
    }
    if (data.containsKey('note_text')) {
      context.handle(_noteTextMeta,
          noteText.isAcceptableOrUnknown(data['note_text']!, _noteTextMeta));
    }
    if (data.containsKey('note_video_url')) {
      context.handle(
          _noteVideoUrlMeta,
          noteVideoUrl.isAcceptableOrUnknown(
              data['note_video_url']!, _noteVideoUrlMeta));
    }
    if (data.containsKey('skipped_steps')) {
      context.handle(
          _skippedStepsMeta,
          skippedSteps.isAcceptableOrUnknown(
              data['skipped_steps']!, _skippedStepsMeta));
    }
    if (data.containsKey('clicker_count')) {
      context.handle(
          _clickerCountMeta,
          clickerCount.isAcceptableOrUnknown(
              data['clicker_count']!, _clickerCountMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrainingSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrainingSession(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      skillId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}skill_id'])!,
      scriptPart: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}script_part'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ended_at'])!,
      durationSec: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_sec'])!,
      score: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}score'])!,
      noteText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note_text']),
      noteVideoUrl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note_video_url']),
      skippedSteps: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}skipped_steps'])!,
      clickerCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}clicker_count'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}synced_at']),
    );
  }

  @override
  $TrainingSessionsTable createAlias(String alias) {
    return $TrainingSessionsTable(attachedDatabase, alias);
  }
}

class TrainingSession extends DataClass implements Insertable<TrainingSession> {
  final String clientUpdatedAt;
  final bool deleted;
  final String id;
  final String dogId;
  final String userId;
  final String skillId;

  /// 0 表示 mini_script；≥1 为正式脚本的 part。
  final int scriptPart;
  final String startedAt;
  final String endedAt;
  final int durationSec;

  /// full | partial | none。记录页选定评分后才写库（跟练中途退出不写、不打卡）。
  final String score;
  final String? noteText;
  final String? noteVideoUrl;

  /// 被跳过的步骤编号（ScriptStep.step），JSON 数组。
  final String skippedSteps;
  final int clickerCount;
  final String? syncedAt;
  const TrainingSession(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.id,
      required this.dogId,
      required this.userId,
      required this.skillId,
      required this.scriptPart,
      required this.startedAt,
      required this.endedAt,
      required this.durationSec,
      required this.score,
      this.noteText,
      this.noteVideoUrl,
      required this.skippedSteps,
      required this.clickerCount,
      this.syncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['id'] = Variable<String>(id);
    map['dog_id'] = Variable<String>(dogId);
    map['user_id'] = Variable<String>(userId);
    map['skill_id'] = Variable<String>(skillId);
    map['script_part'] = Variable<int>(scriptPart);
    map['started_at'] = Variable<String>(startedAt);
    map['ended_at'] = Variable<String>(endedAt);
    map['duration_sec'] = Variable<int>(durationSec);
    map['score'] = Variable<String>(score);
    if (!nullToAbsent || noteText != null) {
      map['note_text'] = Variable<String>(noteText);
    }
    if (!nullToAbsent || noteVideoUrl != null) {
      map['note_video_url'] = Variable<String>(noteVideoUrl);
    }
    map['skipped_steps'] = Variable<String>(skippedSteps);
    map['clicker_count'] = Variable<int>(clickerCount);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<String>(syncedAt);
    }
    return map;
  }

  TrainingSessionsCompanion toCompanion(bool nullToAbsent) {
    return TrainingSessionsCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      id: Value(id),
      dogId: Value(dogId),
      userId: Value(userId),
      skillId: Value(skillId),
      scriptPart: Value(scriptPart),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      durationSec: Value(durationSec),
      score: Value(score),
      noteText: noteText == null && nullToAbsent
          ? const Value.absent()
          : Value(noteText),
      noteVideoUrl: noteVideoUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(noteVideoUrl),
      skippedSteps: Value(skippedSteps),
      clickerCount: Value(clickerCount),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
    );
  }

  factory TrainingSession.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrainingSession(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      id: serializer.fromJson<String>(json['id']),
      dogId: serializer.fromJson<String>(json['dogId']),
      userId: serializer.fromJson<String>(json['userId']),
      skillId: serializer.fromJson<String>(json['skillId']),
      scriptPart: serializer.fromJson<int>(json['scriptPart']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      endedAt: serializer.fromJson<String>(json['endedAt']),
      durationSec: serializer.fromJson<int>(json['durationSec']),
      score: serializer.fromJson<String>(json['score']),
      noteText: serializer.fromJson<String?>(json['noteText']),
      noteVideoUrl: serializer.fromJson<String?>(json['noteVideoUrl']),
      skippedSteps: serializer.fromJson<String>(json['skippedSteps']),
      clickerCount: serializer.fromJson<int>(json['clickerCount']),
      syncedAt: serializer.fromJson<String?>(json['syncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'id': serializer.toJson<String>(id),
      'dogId': serializer.toJson<String>(dogId),
      'userId': serializer.toJson<String>(userId),
      'skillId': serializer.toJson<String>(skillId),
      'scriptPart': serializer.toJson<int>(scriptPart),
      'startedAt': serializer.toJson<String>(startedAt),
      'endedAt': serializer.toJson<String>(endedAt),
      'durationSec': serializer.toJson<int>(durationSec),
      'score': serializer.toJson<String>(score),
      'noteText': serializer.toJson<String?>(noteText),
      'noteVideoUrl': serializer.toJson<String?>(noteVideoUrl),
      'skippedSteps': serializer.toJson<String>(skippedSteps),
      'clickerCount': serializer.toJson<int>(clickerCount),
      'syncedAt': serializer.toJson<String?>(syncedAt),
    };
  }

  TrainingSession copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? id,
          String? dogId,
          String? userId,
          String? skillId,
          int? scriptPart,
          String? startedAt,
          String? endedAt,
          int? durationSec,
          String? score,
          Value<String?> noteText = const Value.absent(),
          Value<String?> noteVideoUrl = const Value.absent(),
          String? skippedSteps,
          int? clickerCount,
          Value<String?> syncedAt = const Value.absent()}) =>
      TrainingSession(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        id: id ?? this.id,
        dogId: dogId ?? this.dogId,
        userId: userId ?? this.userId,
        skillId: skillId ?? this.skillId,
        scriptPart: scriptPart ?? this.scriptPart,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        durationSec: durationSec ?? this.durationSec,
        score: score ?? this.score,
        noteText: noteText.present ? noteText.value : this.noteText,
        noteVideoUrl:
            noteVideoUrl.present ? noteVideoUrl.value : this.noteVideoUrl,
        skippedSteps: skippedSteps ?? this.skippedSteps,
        clickerCount: clickerCount ?? this.clickerCount,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
      );
  TrainingSession copyWithCompanion(TrainingSessionsCompanion data) {
    return TrainingSession(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      id: data.id.present ? data.id.value : this.id,
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      userId: data.userId.present ? data.userId.value : this.userId,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      scriptPart:
          data.scriptPart.present ? data.scriptPart.value : this.scriptPart,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      durationSec:
          data.durationSec.present ? data.durationSec.value : this.durationSec,
      score: data.score.present ? data.score.value : this.score,
      noteText: data.noteText.present ? data.noteText.value : this.noteText,
      noteVideoUrl: data.noteVideoUrl.present
          ? data.noteVideoUrl.value
          : this.noteVideoUrl,
      skippedSteps: data.skippedSteps.present
          ? data.skippedSteps.value
          : this.skippedSteps,
      clickerCount: data.clickerCount.present
          ? data.clickerCount.value
          : this.clickerCount,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrainingSession(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('dogId: $dogId, ')
          ..write('userId: $userId, ')
          ..write('skillId: $skillId, ')
          ..write('scriptPart: $scriptPart, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSec: $durationSec, ')
          ..write('score: $score, ')
          ..write('noteText: $noteText, ')
          ..write('noteVideoUrl: $noteVideoUrl, ')
          ..write('skippedSteps: $skippedSteps, ')
          ..write('clickerCount: $clickerCount, ')
          ..write('syncedAt: $syncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientUpdatedAt,
      deleted,
      id,
      dogId,
      userId,
      skillId,
      scriptPart,
      startedAt,
      endedAt,
      durationSec,
      score,
      noteText,
      noteVideoUrl,
      skippedSteps,
      clickerCount,
      syncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrainingSession &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.id == this.id &&
          other.dogId == this.dogId &&
          other.userId == this.userId &&
          other.skillId == this.skillId &&
          other.scriptPart == this.scriptPart &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.durationSec == this.durationSec &&
          other.score == this.score &&
          other.noteText == this.noteText &&
          other.noteVideoUrl == this.noteVideoUrl &&
          other.skippedSteps == this.skippedSteps &&
          other.clickerCount == this.clickerCount &&
          other.syncedAt == this.syncedAt);
}

class TrainingSessionsCompanion extends UpdateCompanion<TrainingSession> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> id;
  final Value<String> dogId;
  final Value<String> userId;
  final Value<String> skillId;
  final Value<int> scriptPart;
  final Value<String> startedAt;
  final Value<String> endedAt;
  final Value<int> durationSec;
  final Value<String> score;
  final Value<String?> noteText;
  final Value<String?> noteVideoUrl;
  final Value<String> skippedSteps;
  final Value<int> clickerCount;
  final Value<String?> syncedAt;
  final Value<int> rowid;
  const TrainingSessionsCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.id = const Value.absent(),
    this.dogId = const Value.absent(),
    this.userId = const Value.absent(),
    this.skillId = const Value.absent(),
    this.scriptPart = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.score = const Value.absent(),
    this.noteText = const Value.absent(),
    this.noteVideoUrl = const Value.absent(),
    this.skippedSteps = const Value.absent(),
    this.clickerCount = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrainingSessionsCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String id,
    required String dogId,
    required String userId,
    required String skillId,
    required int scriptPart,
    required String startedAt,
    required String endedAt,
    required int durationSec,
    required String score,
    this.noteText = const Value.absent(),
    this.noteVideoUrl = const Value.absent(),
    this.skippedSteps = const Value.absent(),
    this.clickerCount = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        dogId = Value(dogId),
        userId = Value(userId),
        skillId = Value(skillId),
        scriptPart = Value(scriptPart),
        startedAt = Value(startedAt),
        endedAt = Value(endedAt),
        durationSec = Value(durationSec),
        score = Value(score);
  static Insertable<TrainingSession> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? id,
    Expression<String>? dogId,
    Expression<String>? userId,
    Expression<String>? skillId,
    Expression<int>? scriptPart,
    Expression<String>? startedAt,
    Expression<String>? endedAt,
    Expression<int>? durationSec,
    Expression<String>? score,
    Expression<String>? noteText,
    Expression<String>? noteVideoUrl,
    Expression<String>? skippedSteps,
    Expression<int>? clickerCount,
    Expression<String>? syncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (id != null) 'id': id,
      if (dogId != null) 'dog_id': dogId,
      if (userId != null) 'user_id': userId,
      if (skillId != null) 'skill_id': skillId,
      if (scriptPart != null) 'script_part': scriptPart,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (durationSec != null) 'duration_sec': durationSec,
      if (score != null) 'score': score,
      if (noteText != null) 'note_text': noteText,
      if (noteVideoUrl != null) 'note_video_url': noteVideoUrl,
      if (skippedSteps != null) 'skipped_steps': skippedSteps,
      if (clickerCount != null) 'clicker_count': clickerCount,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrainingSessionsCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? id,
      Value<String>? dogId,
      Value<String>? userId,
      Value<String>? skillId,
      Value<int>? scriptPart,
      Value<String>? startedAt,
      Value<String>? endedAt,
      Value<int>? durationSec,
      Value<String>? score,
      Value<String?>? noteText,
      Value<String?>? noteVideoUrl,
      Value<String>? skippedSteps,
      Value<int>? clickerCount,
      Value<String?>? syncedAt,
      Value<int>? rowid}) {
    return TrainingSessionsCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      id: id ?? this.id,
      dogId: dogId ?? this.dogId,
      userId: userId ?? this.userId,
      skillId: skillId ?? this.skillId,
      scriptPart: scriptPart ?? this.scriptPart,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      durationSec: durationSec ?? this.durationSec,
      score: score ?? this.score,
      noteText: noteText ?? this.noteText,
      noteVideoUrl: noteVideoUrl ?? this.noteVideoUrl,
      skippedSteps: skippedSteps ?? this.skippedSteps,
      clickerCount: clickerCount ?? this.clickerCount,
      syncedAt: syncedAt ?? this.syncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (scriptPart.present) {
      map['script_part'] = Variable<int>(scriptPart.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<String>(endedAt.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (score.present) {
      map['score'] = Variable<String>(score.value);
    }
    if (noteText.present) {
      map['note_text'] = Variable<String>(noteText.value);
    }
    if (noteVideoUrl.present) {
      map['note_video_url'] = Variable<String>(noteVideoUrl.value);
    }
    if (skippedSteps.present) {
      map['skipped_steps'] = Variable<String>(skippedSteps.value);
    }
    if (clickerCount.present) {
      map['clicker_count'] = Variable<int>(clickerCount.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<String>(syncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrainingSessionsCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('dogId: $dogId, ')
          ..write('userId: $userId, ')
          ..write('skillId: $skillId, ')
          ..write('scriptPart: $scriptPart, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('durationSec: $durationSec, ')
          ..write('score: $score, ')
          ..write('noteText: $noteText, ')
          ..write('noteVideoUrl: $noteVideoUrl, ')
          ..write('skippedSteps: $skippedSteps, ')
          ..write('clickerCount: $clickerCount, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StreaksTable extends Streaks with TableInfo<$StreaksTable, Streak> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreaksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _currentDaysMeta =
      const VerificationMeta('currentDays');
  @override
  late final GeneratedColumn<int> currentDays = GeneratedColumn<int>(
      'current_days', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _longestDaysMeta =
      const VerificationMeta('longestDays');
  @override
  late final GeneratedColumn<int> longestDays = GeneratedColumn<int>(
      'longest_days', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastCheckinDateMeta =
      const VerificationMeta('lastCheckinDate');
  @override
  late final GeneratedColumn<String> lastCheckinDate = GeneratedColumn<String>(
      'last_checkin_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [dogId, currentDays, longestDays, lastCheckinDate];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streaks';
  @override
  VerificationContext validateIntegrity(Insertable<Streak> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('current_days')) {
      context.handle(
          _currentDaysMeta,
          currentDays.isAcceptableOrUnknown(
              data['current_days']!, _currentDaysMeta));
    }
    if (data.containsKey('longest_days')) {
      context.handle(
          _longestDaysMeta,
          longestDays.isAcceptableOrUnknown(
              data['longest_days']!, _longestDaysMeta));
    }
    if (data.containsKey('last_checkin_date')) {
      context.handle(
          _lastCheckinDateMeta,
          lastCheckinDate.isAcceptableOrUnknown(
              data['last_checkin_date']!, _lastCheckinDateMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dogId};
  @override
  Streak map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Streak(
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      currentDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_days'])!,
      longestDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}longest_days'])!,
      lastCheckinDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_checkin_date']),
    );
  }

  @override
  $StreaksTable createAlias(String alias) {
    return $StreaksTable(attachedDatabase, alias);
  }
}

class Streak extends DataClass implements Insertable<Streak> {
  final String dogId;
  final int currentDays;
  final int longestDays;
  final String? lastCheckinDate;
  const Streak(
      {required this.dogId,
      required this.currentDays,
      required this.longestDays,
      this.lastCheckinDate});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dog_id'] = Variable<String>(dogId);
    map['current_days'] = Variable<int>(currentDays);
    map['longest_days'] = Variable<int>(longestDays);
    if (!nullToAbsent || lastCheckinDate != null) {
      map['last_checkin_date'] = Variable<String>(lastCheckinDate);
    }
    return map;
  }

  StreaksCompanion toCompanion(bool nullToAbsent) {
    return StreaksCompanion(
      dogId: Value(dogId),
      currentDays: Value(currentDays),
      longestDays: Value(longestDays),
      lastCheckinDate: lastCheckinDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastCheckinDate),
    );
  }

  factory Streak.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Streak(
      dogId: serializer.fromJson<String>(json['dogId']),
      currentDays: serializer.fromJson<int>(json['currentDays']),
      longestDays: serializer.fromJson<int>(json['longestDays']),
      lastCheckinDate: serializer.fromJson<String?>(json['lastCheckinDate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dogId': serializer.toJson<String>(dogId),
      'currentDays': serializer.toJson<int>(currentDays),
      'longestDays': serializer.toJson<int>(longestDays),
      'lastCheckinDate': serializer.toJson<String?>(lastCheckinDate),
    };
  }

  Streak copyWith(
          {String? dogId,
          int? currentDays,
          int? longestDays,
          Value<String?> lastCheckinDate = const Value.absent()}) =>
      Streak(
        dogId: dogId ?? this.dogId,
        currentDays: currentDays ?? this.currentDays,
        longestDays: longestDays ?? this.longestDays,
        lastCheckinDate: lastCheckinDate.present
            ? lastCheckinDate.value
            : this.lastCheckinDate,
      );
  Streak copyWithCompanion(StreaksCompanion data) {
    return Streak(
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      currentDays:
          data.currentDays.present ? data.currentDays.value : this.currentDays,
      longestDays:
          data.longestDays.present ? data.longestDays.value : this.longestDays,
      lastCheckinDate: data.lastCheckinDate.present
          ? data.lastCheckinDate.value
          : this.lastCheckinDate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Streak(')
          ..write('dogId: $dogId, ')
          ..write('currentDays: $currentDays, ')
          ..write('longestDays: $longestDays, ')
          ..write('lastCheckinDate: $lastCheckinDate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(dogId, currentDays, longestDays, lastCheckinDate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Streak &&
          other.dogId == this.dogId &&
          other.currentDays == this.currentDays &&
          other.longestDays == this.longestDays &&
          other.lastCheckinDate == this.lastCheckinDate);
}

class StreaksCompanion extends UpdateCompanion<Streak> {
  final Value<String> dogId;
  final Value<int> currentDays;
  final Value<int> longestDays;
  final Value<String?> lastCheckinDate;
  final Value<int> rowid;
  const StreaksCompanion({
    this.dogId = const Value.absent(),
    this.currentDays = const Value.absent(),
    this.longestDays = const Value.absent(),
    this.lastCheckinDate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StreaksCompanion.insert({
    required String dogId,
    this.currentDays = const Value.absent(),
    this.longestDays = const Value.absent(),
    this.lastCheckinDate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dogId = Value(dogId);
  static Insertable<Streak> custom({
    Expression<String>? dogId,
    Expression<int>? currentDays,
    Expression<int>? longestDays,
    Expression<String>? lastCheckinDate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dogId != null) 'dog_id': dogId,
      if (currentDays != null) 'current_days': currentDays,
      if (longestDays != null) 'longest_days': longestDays,
      if (lastCheckinDate != null) 'last_checkin_date': lastCheckinDate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StreaksCompanion copyWith(
      {Value<String>? dogId,
      Value<int>? currentDays,
      Value<int>? longestDays,
      Value<String?>? lastCheckinDate,
      Value<int>? rowid}) {
    return StreaksCompanion(
      dogId: dogId ?? this.dogId,
      currentDays: currentDays ?? this.currentDays,
      longestDays: longestDays ?? this.longestDays,
      lastCheckinDate: lastCheckinDate ?? this.lastCheckinDate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (currentDays.present) {
      map['current_days'] = Variable<int>(currentDays.value);
    }
    if (longestDays.present) {
      map['longest_days'] = Variable<int>(longestDays.value);
    }
    if (lastCheckinDate.present) {
      map['last_checkin_date'] = Variable<String>(lastCheckinDate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreaksCompanion(')
          ..write('dogId: $dogId, ')
          ..write('currentDays: $currentDays, ')
          ..write('longestDays: $longestDays, ')
          ..write('lastCheckinDate: $lastCheckinDate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WeeklyReportsTable extends WeeklyReports
    with TableInfo<$WeeklyReportsTable, WeeklyReport> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeeklyReportsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _planIdMeta = const VerificationMeta('planId');
  @override
  late final GeneratedColumn<String> planId = GeneratedColumn<String>(
      'plan_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _summaryJsonMeta =
      const VerificationMeta('summaryJson');
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
      'summary_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _aiCommentMeta =
      const VerificationMeta('aiComment');
  @override
  late final GeneratedColumn<String> aiComment = GeneratedColumn<String>(
      'ai_comment', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nextPlanIdMeta =
      const VerificationMeta('nextPlanId');
  @override
  late final GeneratedColumn<String> nextPlanId = GeneratedColumn<String>(
      'next_plan_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _readAtMeta = const VerificationMeta('readAt');
  @override
  late final GeneratedColumn<String> readAt = GeneratedColumn<String>(
      'read_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        id,
        dogId,
        planId,
        summaryJson,
        aiComment,
        nextPlanId,
        createdAt,
        readAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weekly_reports';
  @override
  VerificationContext validateIntegrity(Insertable<WeeklyReport> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('plan_id')) {
      context.handle(_planIdMeta,
          planId.isAcceptableOrUnknown(data['plan_id']!, _planIdMeta));
    } else if (isInserting) {
      context.missing(_planIdMeta);
    }
    if (data.containsKey('summary_json')) {
      context.handle(
          _summaryJsonMeta,
          summaryJson.isAcceptableOrUnknown(
              data['summary_json']!, _summaryJsonMeta));
    } else if (isInserting) {
      context.missing(_summaryJsonMeta);
    }
    if (data.containsKey('ai_comment')) {
      context.handle(_aiCommentMeta,
          aiComment.isAcceptableOrUnknown(data['ai_comment']!, _aiCommentMeta));
    } else if (isInserting) {
      context.missing(_aiCommentMeta);
    }
    if (data.containsKey('next_plan_id')) {
      context.handle(
          _nextPlanIdMeta,
          nextPlanId.isAcceptableOrUnknown(
              data['next_plan_id']!, _nextPlanIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('read_at')) {
      context.handle(_readAtMeta,
          readAt.isAcceptableOrUnknown(data['read_at']!, _readAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
        {planId},
      ];
  @override
  WeeklyReport map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeeklyReport(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      planId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}plan_id'])!,
      summaryJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}summary_json'])!,
      aiComment: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ai_comment'])!,
      nextPlanId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}next_plan_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      readAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}read_at']),
    );
  }

  @override
  $WeeklyReportsTable createAlias(String alias) {
    return $WeeklyReportsTable(attachedDatabase, alias);
  }
}

class WeeklyReport extends DataClass implements Insertable<WeeklyReport> {
  final String clientUpdatedAt;
  final bool deleted;
  final String id;
  final String dogId;
  final String planId;
  final String summaryJson;
  final String aiComment;
  final String? nextPlanId;
  final String createdAt;

  /// 首页"上周周报已生成"入口用；数据模型文档没有这一列，M2 新增。
  final String? readAt;
  const WeeklyReport(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.id,
      required this.dogId,
      required this.planId,
      required this.summaryJson,
      required this.aiComment,
      this.nextPlanId,
      required this.createdAt,
      this.readAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['id'] = Variable<String>(id);
    map['dog_id'] = Variable<String>(dogId);
    map['plan_id'] = Variable<String>(planId);
    map['summary_json'] = Variable<String>(summaryJson);
    map['ai_comment'] = Variable<String>(aiComment);
    if (!nullToAbsent || nextPlanId != null) {
      map['next_plan_id'] = Variable<String>(nextPlanId);
    }
    map['created_at'] = Variable<String>(createdAt);
    if (!nullToAbsent || readAt != null) {
      map['read_at'] = Variable<String>(readAt);
    }
    return map;
  }

  WeeklyReportsCompanion toCompanion(bool nullToAbsent) {
    return WeeklyReportsCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      id: Value(id),
      dogId: Value(dogId),
      planId: Value(planId),
      summaryJson: Value(summaryJson),
      aiComment: Value(aiComment),
      nextPlanId: nextPlanId == null && nullToAbsent
          ? const Value.absent()
          : Value(nextPlanId),
      createdAt: Value(createdAt),
      readAt:
          readAt == null && nullToAbsent ? const Value.absent() : Value(readAt),
    );
  }

  factory WeeklyReport.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeeklyReport(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      id: serializer.fromJson<String>(json['id']),
      dogId: serializer.fromJson<String>(json['dogId']),
      planId: serializer.fromJson<String>(json['planId']),
      summaryJson: serializer.fromJson<String>(json['summaryJson']),
      aiComment: serializer.fromJson<String>(json['aiComment']),
      nextPlanId: serializer.fromJson<String?>(json['nextPlanId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      readAt: serializer.fromJson<String?>(json['readAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'id': serializer.toJson<String>(id),
      'dogId': serializer.toJson<String>(dogId),
      'planId': serializer.toJson<String>(planId),
      'summaryJson': serializer.toJson<String>(summaryJson),
      'aiComment': serializer.toJson<String>(aiComment),
      'nextPlanId': serializer.toJson<String?>(nextPlanId),
      'createdAt': serializer.toJson<String>(createdAt),
      'readAt': serializer.toJson<String?>(readAt),
    };
  }

  WeeklyReport copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? id,
          String? dogId,
          String? planId,
          String? summaryJson,
          String? aiComment,
          Value<String?> nextPlanId = const Value.absent(),
          String? createdAt,
          Value<String?> readAt = const Value.absent()}) =>
      WeeklyReport(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        id: id ?? this.id,
        dogId: dogId ?? this.dogId,
        planId: planId ?? this.planId,
        summaryJson: summaryJson ?? this.summaryJson,
        aiComment: aiComment ?? this.aiComment,
        nextPlanId: nextPlanId.present ? nextPlanId.value : this.nextPlanId,
        createdAt: createdAt ?? this.createdAt,
        readAt: readAt.present ? readAt.value : this.readAt,
      );
  WeeklyReport copyWithCompanion(WeeklyReportsCompanion data) {
    return WeeklyReport(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      id: data.id.present ? data.id.value : this.id,
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      planId: data.planId.present ? data.planId.value : this.planId,
      summaryJson:
          data.summaryJson.present ? data.summaryJson.value : this.summaryJson,
      aiComment: data.aiComment.present ? data.aiComment.value : this.aiComment,
      nextPlanId:
          data.nextPlanId.present ? data.nextPlanId.value : this.nextPlanId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      readAt: data.readAt.present ? data.readAt.value : this.readAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyReport(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('dogId: $dogId, ')
          ..write('planId: $planId, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('aiComment: $aiComment, ')
          ..write('nextPlanId: $nextPlanId, ')
          ..write('createdAt: $createdAt, ')
          ..write('readAt: $readAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientUpdatedAt, deleted, id, dogId, planId,
      summaryJson, aiComment, nextPlanId, createdAt, readAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeeklyReport &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.id == this.id &&
          other.dogId == this.dogId &&
          other.planId == this.planId &&
          other.summaryJson == this.summaryJson &&
          other.aiComment == this.aiComment &&
          other.nextPlanId == this.nextPlanId &&
          other.createdAt == this.createdAt &&
          other.readAt == this.readAt);
}

class WeeklyReportsCompanion extends UpdateCompanion<WeeklyReport> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> id;
  final Value<String> dogId;
  final Value<String> planId;
  final Value<String> summaryJson;
  final Value<String> aiComment;
  final Value<String?> nextPlanId;
  final Value<String> createdAt;
  final Value<String?> readAt;
  final Value<int> rowid;
  const WeeklyReportsCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.id = const Value.absent(),
    this.dogId = const Value.absent(),
    this.planId = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.aiComment = const Value.absent(),
    this.nextPlanId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WeeklyReportsCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String id,
    required String dogId,
    required String planId,
    required String summaryJson,
    required String aiComment,
    this.nextPlanId = const Value.absent(),
    required String createdAt,
    this.readAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        dogId = Value(dogId),
        planId = Value(planId),
        summaryJson = Value(summaryJson),
        aiComment = Value(aiComment),
        createdAt = Value(createdAt);
  static Insertable<WeeklyReport> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? id,
    Expression<String>? dogId,
    Expression<String>? planId,
    Expression<String>? summaryJson,
    Expression<String>? aiComment,
    Expression<String>? nextPlanId,
    Expression<String>? createdAt,
    Expression<String>? readAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (id != null) 'id': id,
      if (dogId != null) 'dog_id': dogId,
      if (planId != null) 'plan_id': planId,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (aiComment != null) 'ai_comment': aiComment,
      if (nextPlanId != null) 'next_plan_id': nextPlanId,
      if (createdAt != null) 'created_at': createdAt,
      if (readAt != null) 'read_at': readAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WeeklyReportsCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? id,
      Value<String>? dogId,
      Value<String>? planId,
      Value<String>? summaryJson,
      Value<String>? aiComment,
      Value<String?>? nextPlanId,
      Value<String>? createdAt,
      Value<String?>? readAt,
      Value<int>? rowid}) {
    return WeeklyReportsCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      id: id ?? this.id,
      dogId: dogId ?? this.dogId,
      planId: planId ?? this.planId,
      summaryJson: summaryJson ?? this.summaryJson,
      aiComment: aiComment ?? this.aiComment,
      nextPlanId: nextPlanId ?? this.nextPlanId,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (planId.present) {
      map['plan_id'] = Variable<String>(planId.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (aiComment.present) {
      map['ai_comment'] = Variable<String>(aiComment.value);
    }
    if (nextPlanId.present) {
      map['next_plan_id'] = Variable<String>(nextPlanId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (readAt.present) {
      map['read_at'] = Variable<String>(readAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeeklyReportsCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('dogId: $dogId, ')
          ..write('planId: $planId, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('aiComment: $aiComment, ')
          ..write('nextPlanId: $nextPlanId, ')
          ..write('createdAt: $createdAt, ')
          ..write('readAt: $readAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiConversationsTable extends AiConversations
    with TableInfo<$AiConversationsTable, AiConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _skillIdMeta =
      const VerificationMeta('skillId');
  @override
  late final GeneratedColumn<String> skillId = GeneratedColumn<String>(
      'skill_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _issueIdMeta =
      const VerificationMeta('issueId');
  @override
  late final GeneratedColumn<String> issueId = GeneratedColumn<String>(
      'issue_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        id,
        dogId,
        type,
        skillId,
        issueId,
        createdAt,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_conversations';
  @override
  VerificationContext validateIntegrity(Insertable<AiConversation> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('skill_id')) {
      context.handle(_skillIdMeta,
          skillId.isAcceptableOrUnknown(data['skill_id']!, _skillIdMeta));
    }
    if (data.containsKey('issue_id')) {
      context.handle(_issueIdMeta,
          issueId.isAcceptableOrUnknown(data['issue_id']!, _issueIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AiConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiConversation(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      skillId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}skill_id']),
      issueId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}issue_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $AiConversationsTable createAlias(String alias) {
    return $AiConversationsTable(attachedDatabase, alias);
  }
}

class AiConversation extends DataClass implements Insertable<AiConversation> {
  final String clientUpdatedAt;
  final bool deleted;
  final String id;
  final String dogId;
  final String type;
  final String? skillId;
  final String? issueId;
  final String createdAt;
  final String updatedAt;
  const AiConversation(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.id,
      required this.dogId,
      required this.type,
      this.skillId,
      this.issueId,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['id'] = Variable<String>(id);
    map['dog_id'] = Variable<String>(dogId);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || skillId != null) {
      map['skill_id'] = Variable<String>(skillId);
    }
    if (!nullToAbsent || issueId != null) {
      map['issue_id'] = Variable<String>(issueId);
    }
    map['created_at'] = Variable<String>(createdAt);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  AiConversationsCompanion toCompanion(bool nullToAbsent) {
    return AiConversationsCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      id: Value(id),
      dogId: Value(dogId),
      type: Value(type),
      skillId: skillId == null && nullToAbsent
          ? const Value.absent()
          : Value(skillId),
      issueId: issueId == null && nullToAbsent
          ? const Value.absent()
          : Value(issueId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory AiConversation.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiConversation(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      id: serializer.fromJson<String>(json['id']),
      dogId: serializer.fromJson<String>(json['dogId']),
      type: serializer.fromJson<String>(json['type']),
      skillId: serializer.fromJson<String?>(json['skillId']),
      issueId: serializer.fromJson<String?>(json['issueId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'id': serializer.toJson<String>(id),
      'dogId': serializer.toJson<String>(dogId),
      'type': serializer.toJson<String>(type),
      'skillId': serializer.toJson<String?>(skillId),
      'issueId': serializer.toJson<String?>(issueId),
      'createdAt': serializer.toJson<String>(createdAt),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  AiConversation copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? id,
          String? dogId,
          String? type,
          Value<String?> skillId = const Value.absent(),
          Value<String?> issueId = const Value.absent(),
          String? createdAt,
          String? updatedAt}) =>
      AiConversation(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        id: id ?? this.id,
        dogId: dogId ?? this.dogId,
        type: type ?? this.type,
        skillId: skillId.present ? skillId.value : this.skillId,
        issueId: issueId.present ? issueId.value : this.issueId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AiConversation copyWithCompanion(AiConversationsCompanion data) {
    return AiConversation(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      id: data.id.present ? data.id.value : this.id,
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      type: data.type.present ? data.type.value : this.type,
      skillId: data.skillId.present ? data.skillId.value : this.skillId,
      issueId: data.issueId.present ? data.issueId.value : this.issueId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiConversation(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('dogId: $dogId, ')
          ..write('type: $type, ')
          ..write('skillId: $skillId, ')
          ..write('issueId: $issueId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientUpdatedAt, deleted, id, dogId, type,
      skillId, issueId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiConversation &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.id == this.id &&
          other.dogId == this.dogId &&
          other.type == this.type &&
          other.skillId == this.skillId &&
          other.issueId == this.issueId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class AiConversationsCompanion extends UpdateCompanion<AiConversation> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> id;
  final Value<String> dogId;
  final Value<String> type;
  final Value<String?> skillId;
  final Value<String?> issueId;
  final Value<String> createdAt;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const AiConversationsCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.id = const Value.absent(),
    this.dogId = const Value.absent(),
    this.type = const Value.absent(),
    this.skillId = const Value.absent(),
    this.issueId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiConversationsCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String id,
    required String dogId,
    required String type,
    this.skillId = const Value.absent(),
    this.issueId = const Value.absent(),
    required String createdAt,
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        dogId = Value(dogId),
        type = Value(type),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<AiConversation> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? id,
    Expression<String>? dogId,
    Expression<String>? type,
    Expression<String>? skillId,
    Expression<String>? issueId,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (id != null) 'id': id,
      if (dogId != null) 'dog_id': dogId,
      if (type != null) 'type': type,
      if (skillId != null) 'skill_id': skillId,
      if (issueId != null) 'issue_id': issueId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiConversationsCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? id,
      Value<String>? dogId,
      Value<String>? type,
      Value<String?>? skillId,
      Value<String?>? issueId,
      Value<String>? createdAt,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return AiConversationsCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      id: id ?? this.id,
      dogId: dogId ?? this.dogId,
      type: type ?? this.type,
      skillId: skillId ?? this.skillId,
      issueId: issueId ?? this.issueId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (skillId.present) {
      map['skill_id'] = Variable<String>(skillId.value);
    }
    if (issueId.present) {
      map['issue_id'] = Variable<String>(issueId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiConversationsCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('dogId: $dogId, ')
          ..write('type: $type, ')
          ..write('skillId: $skillId, ')
          ..write('issueId: $issueId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AiMessagesTable extends AiMessages
    with TableInfo<$AiMessagesTable, AiMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AiMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
      'role', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentMeta =
      const VerificationMeta('content');
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
      'content', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _citedContentIdsMeta =
      const VerificationMeta('citedContentIds');
  @override
  late final GeneratedColumn<String> citedContentIds = GeneratedColumn<String>(
      'cited_content_ids', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('[]'));
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        id,
        conversationId,
        role,
        content,
        citedContentIds,
        kind,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ai_messages';
  @override
  VerificationContext validateIntegrity(Insertable<AiMessage> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
          _roleMeta, role.isAcceptableOrUnknown(data['role']!, _roleMeta));
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('content')) {
      context.handle(_contentMeta,
          content.isAcceptableOrUnknown(data['content']!, _contentMeta));
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('cited_content_ids')) {
      context.handle(
          _citedContentIdsMeta,
          citedContentIds.isAcceptableOrUnknown(
              data['cited_content_ids']!, _citedContentIdsMeta));
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
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
  AiMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AiMessage(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      role: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}role'])!,
      content: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content'])!,
      citedContentIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}cited_content_ids'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AiMessagesTable createAlias(String alias) {
    return $AiMessagesTable(attachedDatabase, alias);
  }
}

class AiMessage extends DataClass implements Insertable<AiMessage> {
  final String clientUpdatedAt;
  final bool deleted;
  final String id;
  final String conversationId;
  final String role;
  final String content;

  /// 引用的内容 ID，JSON 数组。
  final String citedContentIds;

  /// normal | guard_health | guard_no_hit | diagnosis_q | diagnosis_result
  final String kind;
  final String createdAt;
  const AiMessage(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.id,
      required this.conversationId,
      required this.role,
      required this.content,
      required this.citedContentIds,
      required this.kind,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['role'] = Variable<String>(role);
    map['content'] = Variable<String>(content);
    map['cited_content_ids'] = Variable<String>(citedContentIds);
    map['kind'] = Variable<String>(kind);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  AiMessagesCompanion toCompanion(bool nullToAbsent) {
    return AiMessagesCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      id: Value(id),
      conversationId: Value(conversationId),
      role: Value(role),
      content: Value(content),
      citedContentIds: Value(citedContentIds),
      kind: Value(kind),
      createdAt: Value(createdAt),
    );
  }

  factory AiMessage.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AiMessage(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      role: serializer.fromJson<String>(json['role']),
      content: serializer.fromJson<String>(json['content']),
      citedContentIds: serializer.fromJson<String>(json['citedContentIds']),
      kind: serializer.fromJson<String>(json['kind']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'role': serializer.toJson<String>(role),
      'content': serializer.toJson<String>(content),
      'citedContentIds': serializer.toJson<String>(citedContentIds),
      'kind': serializer.toJson<String>(kind),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  AiMessage copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? id,
          String? conversationId,
          String? role,
          String? content,
          String? citedContentIds,
          String? kind,
          String? createdAt}) =>
      AiMessage(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        role: role ?? this.role,
        content: content ?? this.content,
        citedContentIds: citedContentIds ?? this.citedContentIds,
        kind: kind ?? this.kind,
        createdAt: createdAt ?? this.createdAt,
      );
  AiMessage copyWithCompanion(AiMessagesCompanion data) {
    return AiMessage(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      role: data.role.present ? data.role.value : this.role,
      content: data.content.present ? data.content.value : this.content,
      citedContentIds: data.citedContentIds.present
          ? data.citedContentIds.value
          : this.citedContentIds,
      kind: data.kind.present ? data.kind.value : this.kind,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AiMessage(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('citedContentIds: $citedContentIds, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientUpdatedAt, deleted, id, conversationId,
      role, content, citedContentIds, kind, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AiMessage &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.role == this.role &&
          other.content == this.content &&
          other.citedContentIds == this.citedContentIds &&
          other.kind == this.kind &&
          other.createdAt == this.createdAt);
}

class AiMessagesCompanion extends UpdateCompanion<AiMessage> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> role;
  final Value<String> content;
  final Value<String> citedContentIds;
  final Value<String> kind;
  final Value<String> createdAt;
  final Value<int> rowid;
  const AiMessagesCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.role = const Value.absent(),
    this.content = const Value.absent(),
    this.citedContentIds = const Value.absent(),
    this.kind = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AiMessagesCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String id,
    required String conversationId,
    required String role,
    required String content,
    this.citedContentIds = const Value.absent(),
    required String kind,
    required String createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        conversationId = Value(conversationId),
        role = Value(role),
        content = Value(content),
        kind = Value(kind),
        createdAt = Value(createdAt);
  static Insertable<AiMessage> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? role,
    Expression<String>? content,
    Expression<String>? citedContentIds,
    Expression<String>? kind,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (role != null) 'role': role,
      if (content != null) 'content': content,
      if (citedContentIds != null) 'cited_content_ids': citedContentIds,
      if (kind != null) 'kind': kind,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AiMessagesCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? id,
      Value<String>? conversationId,
      Value<String>? role,
      Value<String>? content,
      Value<String>? citedContentIds,
      Value<String>? kind,
      Value<String>? createdAt,
      Value<int>? rowid}) {
    return AiMessagesCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      role: role ?? this.role,
      content: content ?? this.content,
      citedContentIds: citedContentIds ?? this.citedContentIds,
      kind: kind ?? this.kind,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (citedContentIds.present) {
      map['cited_content_ids'] = Variable<String>(citedContentIds.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AiMessagesCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('role: $role, ')
          ..write('content: $content, ')
          ..write('citedContentIds: $citedContentIds, ')
          ..write('kind: $kind, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DiagnosisResultsTable extends DiagnosisResults
    with TableInfo<$DiagnosisResultsTable, DiagnosisResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DiagnosisResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _conversationIdMeta =
      const VerificationMeta('conversationId');
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
      'conversation_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _issueIdMeta =
      const VerificationMeta('issueId');
  @override
  late final GeneratedColumn<String> issueId = GeneratedColumn<String>(
      'issue_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resultKeyMeta =
      const VerificationMeta('resultKey');
  @override
  late final GeneratedColumn<String> resultKey = GeneratedColumn<String>(
      'result_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _solutionSkillIdsMeta =
      const VerificationMeta('solutionSkillIds');
  @override
  late final GeneratedColumn<String> solutionSkillIds = GeneratedColumn<String>(
      'solution_skill_ids', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addedToPlanIdMeta =
      const VerificationMeta('addedToPlanId');
  @override
  late final GeneratedColumn<String> addedToPlanId = GeneratedColumn<String>(
      'added_to_plan_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        id,
        conversationId,
        dogId,
        issueId,
        resultKey,
        solutionSkillIds,
        addedToPlanId,
        userId,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'diagnosis_results';
  @override
  VerificationContext validateIntegrity(Insertable<DiagnosisResult> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
          _conversationIdMeta,
          conversationId.isAcceptableOrUnknown(
              data['conversation_id']!, _conversationIdMeta));
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('issue_id')) {
      context.handle(_issueIdMeta,
          issueId.isAcceptableOrUnknown(data['issue_id']!, _issueIdMeta));
    } else if (isInserting) {
      context.missing(_issueIdMeta);
    }
    if (data.containsKey('result_key')) {
      context.handle(_resultKeyMeta,
          resultKey.isAcceptableOrUnknown(data['result_key']!, _resultKeyMeta));
    } else if (isInserting) {
      context.missing(_resultKeyMeta);
    }
    if (data.containsKey('solution_skill_ids')) {
      context.handle(
          _solutionSkillIdsMeta,
          solutionSkillIds.isAcceptableOrUnknown(
              data['solution_skill_ids']!, _solutionSkillIdsMeta));
    } else if (isInserting) {
      context.missing(_solutionSkillIdsMeta);
    }
    if (data.containsKey('added_to_plan_id')) {
      context.handle(
          _addedToPlanIdMeta,
          addedToPlanId.isAcceptableOrUnknown(
              data['added_to_plan_id']!, _addedToPlanIdMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
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
  DiagnosisResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DiagnosisResult(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      conversationId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}conversation_id'])!,
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      issueId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}issue_id'])!,
      resultKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result_key'])!,
      solutionSkillIds: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}solution_skill_ids'])!,
      addedToPlanId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}added_to_plan_id']),
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $DiagnosisResultsTable createAlias(String alias) {
    return $DiagnosisResultsTable(attachedDatabase, alias);
  }
}

class DiagnosisResult extends DataClass implements Insertable<DiagnosisResult> {
  final String clientUpdatedAt;
  final bool deleted;
  final String id;
  final String conversationId;
  final String dogId;
  final String issueId;
  final String resultKey;

  /// JSON 数组。
  final String solutionSkillIds;

  /// 加入本周计划时为该计划 id；加入下周或未加入为 null。
  final String? addedToPlanId;

  /// M4（FM-5）：做诊断的成员。M3 旧记录为空。
  final String? userId;
  final String createdAt;
  const DiagnosisResult(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.id,
      required this.conversationId,
      required this.dogId,
      required this.issueId,
      required this.resultKey,
      required this.solutionSkillIds,
      this.addedToPlanId,
      this.userId,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['dog_id'] = Variable<String>(dogId);
    map['issue_id'] = Variable<String>(issueId);
    map['result_key'] = Variable<String>(resultKey);
    map['solution_skill_ids'] = Variable<String>(solutionSkillIds);
    if (!nullToAbsent || addedToPlanId != null) {
      map['added_to_plan_id'] = Variable<String>(addedToPlanId);
    }
    if (!nullToAbsent || userId != null) {
      map['user_id'] = Variable<String>(userId);
    }
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  DiagnosisResultsCompanion toCompanion(bool nullToAbsent) {
    return DiagnosisResultsCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      id: Value(id),
      conversationId: Value(conversationId),
      dogId: Value(dogId),
      issueId: Value(issueId),
      resultKey: Value(resultKey),
      solutionSkillIds: Value(solutionSkillIds),
      addedToPlanId: addedToPlanId == null && nullToAbsent
          ? const Value.absent()
          : Value(addedToPlanId),
      userId:
          userId == null && nullToAbsent ? const Value.absent() : Value(userId),
      createdAt: Value(createdAt),
    );
  }

  factory DiagnosisResult.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DiagnosisResult(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      dogId: serializer.fromJson<String>(json['dogId']),
      issueId: serializer.fromJson<String>(json['issueId']),
      resultKey: serializer.fromJson<String>(json['resultKey']),
      solutionSkillIds: serializer.fromJson<String>(json['solutionSkillIds']),
      addedToPlanId: serializer.fromJson<String?>(json['addedToPlanId']),
      userId: serializer.fromJson<String?>(json['userId']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'dogId': serializer.toJson<String>(dogId),
      'issueId': serializer.toJson<String>(issueId),
      'resultKey': serializer.toJson<String>(resultKey),
      'solutionSkillIds': serializer.toJson<String>(solutionSkillIds),
      'addedToPlanId': serializer.toJson<String?>(addedToPlanId),
      'userId': serializer.toJson<String?>(userId),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  DiagnosisResult copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? id,
          String? conversationId,
          String? dogId,
          String? issueId,
          String? resultKey,
          String? solutionSkillIds,
          Value<String?> addedToPlanId = const Value.absent(),
          Value<String?> userId = const Value.absent(),
          String? createdAt}) =>
      DiagnosisResult(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        id: id ?? this.id,
        conversationId: conversationId ?? this.conversationId,
        dogId: dogId ?? this.dogId,
        issueId: issueId ?? this.issueId,
        resultKey: resultKey ?? this.resultKey,
        solutionSkillIds: solutionSkillIds ?? this.solutionSkillIds,
        addedToPlanId:
            addedToPlanId.present ? addedToPlanId.value : this.addedToPlanId,
        userId: userId.present ? userId.value : this.userId,
        createdAt: createdAt ?? this.createdAt,
      );
  DiagnosisResult copyWithCompanion(DiagnosisResultsCompanion data) {
    return DiagnosisResult(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      issueId: data.issueId.present ? data.issueId.value : this.issueId,
      resultKey: data.resultKey.present ? data.resultKey.value : this.resultKey,
      solutionSkillIds: data.solutionSkillIds.present
          ? data.solutionSkillIds.value
          : this.solutionSkillIds,
      addedToPlanId: data.addedToPlanId.present
          ? data.addedToPlanId.value
          : this.addedToPlanId,
      userId: data.userId.present ? data.userId.value : this.userId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DiagnosisResult(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('dogId: $dogId, ')
          ..write('issueId: $issueId, ')
          ..write('resultKey: $resultKey, ')
          ..write('solutionSkillIds: $solutionSkillIds, ')
          ..write('addedToPlanId: $addedToPlanId, ')
          ..write('userId: $userId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientUpdatedAt,
      deleted,
      id,
      conversationId,
      dogId,
      issueId,
      resultKey,
      solutionSkillIds,
      addedToPlanId,
      userId,
      createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DiagnosisResult &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.dogId == this.dogId &&
          other.issueId == this.issueId &&
          other.resultKey == this.resultKey &&
          other.solutionSkillIds == this.solutionSkillIds &&
          other.addedToPlanId == this.addedToPlanId &&
          other.userId == this.userId &&
          other.createdAt == this.createdAt);
}

class DiagnosisResultsCompanion extends UpdateCompanion<DiagnosisResult> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> dogId;
  final Value<String> issueId;
  final Value<String> resultKey;
  final Value<String> solutionSkillIds;
  final Value<String?> addedToPlanId;
  final Value<String?> userId;
  final Value<String> createdAt;
  final Value<int> rowid;
  const DiagnosisResultsCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.dogId = const Value.absent(),
    this.issueId = const Value.absent(),
    this.resultKey = const Value.absent(),
    this.solutionSkillIds = const Value.absent(),
    this.addedToPlanId = const Value.absent(),
    this.userId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DiagnosisResultsCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String id,
    required String conversationId,
    required String dogId,
    required String issueId,
    required String resultKey,
    required String solutionSkillIds,
    this.addedToPlanId = const Value.absent(),
    this.userId = const Value.absent(),
    required String createdAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        conversationId = Value(conversationId),
        dogId = Value(dogId),
        issueId = Value(issueId),
        resultKey = Value(resultKey),
        solutionSkillIds = Value(solutionSkillIds),
        createdAt = Value(createdAt);
  static Insertable<DiagnosisResult> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? dogId,
    Expression<String>? issueId,
    Expression<String>? resultKey,
    Expression<String>? solutionSkillIds,
    Expression<String>? addedToPlanId,
    Expression<String>? userId,
    Expression<String>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (dogId != null) 'dog_id': dogId,
      if (issueId != null) 'issue_id': issueId,
      if (resultKey != null) 'result_key': resultKey,
      if (solutionSkillIds != null) 'solution_skill_ids': solutionSkillIds,
      if (addedToPlanId != null) 'added_to_plan_id': addedToPlanId,
      if (userId != null) 'user_id': userId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DiagnosisResultsCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? id,
      Value<String>? conversationId,
      Value<String>? dogId,
      Value<String>? issueId,
      Value<String>? resultKey,
      Value<String>? solutionSkillIds,
      Value<String?>? addedToPlanId,
      Value<String?>? userId,
      Value<String>? createdAt,
      Value<int>? rowid}) {
    return DiagnosisResultsCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      dogId: dogId ?? this.dogId,
      issueId: issueId ?? this.issueId,
      resultKey: resultKey ?? this.resultKey,
      solutionSkillIds: solutionSkillIds ?? this.solutionSkillIds,
      addedToPlanId: addedToPlanId ?? this.addedToPlanId,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (issueId.present) {
      map['issue_id'] = Variable<String>(issueId.value);
    }
    if (resultKey.present) {
      map['result_key'] = Variable<String>(resultKey.value);
    }
    if (solutionSkillIds.present) {
      map['solution_skill_ids'] = Variable<String>(solutionSkillIds.value);
    }
    if (addedToPlanId.present) {
      map['added_to_plan_id'] = Variable<String>(addedToPlanId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DiagnosisResultsCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('dogId: $dogId, ')
          ..write('issueId: $issueId, ')
          ..write('resultKey: $resultKey, ')
          ..write('solutionSkillIds: $solutionSkillIds, ')
          ..write('addedToPlanId: $addedToPlanId, ')
          ..write('userId: $userId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReminderSettingsTable extends ReminderSettings
    with TableInfo<$ReminderSettingsTable, ReminderSetting> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _enabledMeta =
      const VerificationMeta('enabled');
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
      'enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("enabled" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
      'hour', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(19));
  static const VerificationMeta _minuteMeta = const VerificationMeta('minute');
  @override
  late final GeneratedColumn<int> minute = GeneratedColumn<int>(
      'minute', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [dogId, enabled, hour, minute, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminder_settings';
  @override
  VerificationContext validateIntegrity(Insertable<ReminderSetting> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(_enabledMeta,
          enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta));
    }
    if (data.containsKey('hour')) {
      context.handle(
          _hourMeta, hour.isAcceptableOrUnknown(data['hour']!, _hourMeta));
    }
    if (data.containsKey('minute')) {
      context.handle(_minuteMeta,
          minute.isAcceptableOrUnknown(data['minute']!, _minuteMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dogId};
  @override
  ReminderSetting map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderSetting(
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      enabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}enabled'])!,
      hour: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}hour'])!,
      minute: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}minute'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ReminderSettingsTable createAlias(String alias) {
    return $ReminderSettingsTable(attachedDatabase, alias);
  }
}

class ReminderSetting extends DataClass implements Insertable<ReminderSetting> {
  final String dogId;
  final bool enabled;
  final int hour;
  final int minute;
  final String updatedAt;
  const ReminderSetting(
      {required this.dogId,
      required this.enabled,
      required this.hour,
      required this.minute,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dog_id'] = Variable<String>(dogId);
    map['enabled'] = Variable<bool>(enabled);
    map['hour'] = Variable<int>(hour);
    map['minute'] = Variable<int>(minute);
    map['updated_at'] = Variable<String>(updatedAt);
    return map;
  }

  ReminderSettingsCompanion toCompanion(bool nullToAbsent) {
    return ReminderSettingsCompanion(
      dogId: Value(dogId),
      enabled: Value(enabled),
      hour: Value(hour),
      minute: Value(minute),
      updatedAt: Value(updatedAt),
    );
  }

  factory ReminderSetting.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderSetting(
      dogId: serializer.fromJson<String>(json['dogId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      hour: serializer.fromJson<int>(json['hour']),
      minute: serializer.fromJson<int>(json['minute']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dogId': serializer.toJson<String>(dogId),
      'enabled': serializer.toJson<bool>(enabled),
      'hour': serializer.toJson<int>(hour),
      'minute': serializer.toJson<int>(minute),
      'updatedAt': serializer.toJson<String>(updatedAt),
    };
  }

  ReminderSetting copyWith(
          {String? dogId,
          bool? enabled,
          int? hour,
          int? minute,
          String? updatedAt}) =>
      ReminderSetting(
        dogId: dogId ?? this.dogId,
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  ReminderSetting copyWithCompanion(ReminderSettingsCompanion data) {
    return ReminderSetting(
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      hour: data.hour.present ? data.hour.value : this.hour,
      minute: data.minute.present ? data.minute.value : this.minute,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderSetting(')
          ..write('dogId: $dogId, ')
          ..write('enabled: $enabled, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dogId, enabled, hour, minute, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderSetting &&
          other.dogId == this.dogId &&
          other.enabled == this.enabled &&
          other.hour == this.hour &&
          other.minute == this.minute &&
          other.updatedAt == this.updatedAt);
}

class ReminderSettingsCompanion extends UpdateCompanion<ReminderSetting> {
  final Value<String> dogId;
  final Value<bool> enabled;
  final Value<int> hour;
  final Value<int> minute;
  final Value<String> updatedAt;
  final Value<int> rowid;
  const ReminderSettingsCompanion({
    this.dogId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ReminderSettingsCompanion.insert({
    required String dogId,
    this.enabled = const Value.absent(),
    this.hour = const Value.absent(),
    this.minute = const Value.absent(),
    required String updatedAt,
    this.rowid = const Value.absent(),
  })  : dogId = Value(dogId),
        updatedAt = Value(updatedAt);
  static Insertable<ReminderSetting> custom({
    Expression<String>? dogId,
    Expression<bool>? enabled,
    Expression<int>? hour,
    Expression<int>? minute,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dogId != null) 'dog_id': dogId,
      if (enabled != null) 'enabled': enabled,
      if (hour != null) 'hour': hour,
      if (minute != null) 'minute': minute,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ReminderSettingsCompanion copyWith(
      {Value<String>? dogId,
      Value<bool>? enabled,
      Value<int>? hour,
      Value<int>? minute,
      Value<String>? updatedAt,
      Value<int>? rowid}) {
    return ReminderSettingsCompanion(
      dogId: dogId ?? this.dogId,
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (minute.present) {
      map['minute'] = Variable<int>(minute.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderSettingsCompanion(')
          ..write('dogId: $dogId, ')
          ..write('enabled: $enabled, ')
          ..write('hour: $hour, ')
          ..write('minute: $minute, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CareRemindersTable extends CareReminders
    with TableInfo<$CareRemindersTable, CareReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CareRemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _templateIdMeta =
      const VerificationMeta('templateId');
  @override
  late final GeneratedColumn<String> templateId = GeneratedColumn<String>(
      'template_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _dueDateMeta =
      const VerificationMeta('dueDate');
  @override
  late final GeneratedColumn<String> dueDate = GeneratedColumn<String>(
      'due_date', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _doneAtMeta = const VerificationMeta('doneAt');
  @override
  late final GeneratedColumn<String> doneAt = GeneratedColumn<String>(
      'done_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _skippedMeta =
      const VerificationMeta('skipped');
  @override
  late final GeneratedColumn<bool> skipped = GeneratedColumn<bool>(
      'skipped', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("skipped" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        clientUpdatedAt,
        deleted,
        id,
        dogId,
        templateId,
        type,
        title,
        note,
        dueDate,
        doneAt,
        skipped,
        source
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'care_reminders';
  @override
  VerificationContext validateIntegrity(Insertable<CareReminder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('template_id')) {
      context.handle(
          _templateIdMeta,
          templateId.isAcceptableOrUnknown(
              data['template_id']!, _templateIdMeta));
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('due_date')) {
      context.handle(_dueDateMeta,
          dueDate.isAcceptableOrUnknown(data['due_date']!, _dueDateMeta));
    } else if (isInserting) {
      context.missing(_dueDateMeta);
    }
    if (data.containsKey('done_at')) {
      context.handle(_doneAtMeta,
          doneAt.isAcceptableOrUnknown(data['done_at']!, _doneAtMeta));
    }
    if (data.containsKey('skipped')) {
      context.handle(_skippedMeta,
          skipped.isAcceptableOrUnknown(data['skipped']!, _skippedMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CareReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CareReminder(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      templateId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}template_id']),
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note'])!,
      dueDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}due_date'])!,
      doneAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}done_at']),
      skipped: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}skipped'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
    );
  }

  @override
  $CareRemindersTable createAlias(String alias) {
    return $CareRemindersTable(attachedDatabase, alias);
  }
}

class CareReminder extends DataClass implements Insertable<CareReminder> {
  final String clientUpdatedAt;
  final bool deleted;
  final String id;
  final String dogId;

  /// care_calendar.yaml 的条目 id；用户手动新增为空。
  final String? templateId;

  /// vaccine | deworm_internal | deworm_external
  final String type;
  final String title;
  final String note;
  final String dueDate;
  final String? doneAt;
  final bool skipped;

  /// default | user（用户改过日期的默认条目也视为 user，修改出生日期时不动）
  final String source;
  const CareReminder(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.id,
      required this.dogId,
      this.templateId,
      required this.type,
      required this.title,
      required this.note,
      required this.dueDate,
      this.doneAt,
      required this.skipped,
      required this.source});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['id'] = Variable<String>(id);
    map['dog_id'] = Variable<String>(dogId);
    if (!nullToAbsent || templateId != null) {
      map['template_id'] = Variable<String>(templateId);
    }
    map['type'] = Variable<String>(type);
    map['title'] = Variable<String>(title);
    map['note'] = Variable<String>(note);
    map['due_date'] = Variable<String>(dueDate);
    if (!nullToAbsent || doneAt != null) {
      map['done_at'] = Variable<String>(doneAt);
    }
    map['skipped'] = Variable<bool>(skipped);
    map['source'] = Variable<String>(source);
    return map;
  }

  CareRemindersCompanion toCompanion(bool nullToAbsent) {
    return CareRemindersCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      id: Value(id),
      dogId: Value(dogId),
      templateId: templateId == null && nullToAbsent
          ? const Value.absent()
          : Value(templateId),
      type: Value(type),
      title: Value(title),
      note: Value(note),
      dueDate: Value(dueDate),
      doneAt:
          doneAt == null && nullToAbsent ? const Value.absent() : Value(doneAt),
      skipped: Value(skipped),
      source: Value(source),
    );
  }

  factory CareReminder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CareReminder(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      id: serializer.fromJson<String>(json['id']),
      dogId: serializer.fromJson<String>(json['dogId']),
      templateId: serializer.fromJson<String?>(json['templateId']),
      type: serializer.fromJson<String>(json['type']),
      title: serializer.fromJson<String>(json['title']),
      note: serializer.fromJson<String>(json['note']),
      dueDate: serializer.fromJson<String>(json['dueDate']),
      doneAt: serializer.fromJson<String?>(json['doneAt']),
      skipped: serializer.fromJson<bool>(json['skipped']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'id': serializer.toJson<String>(id),
      'dogId': serializer.toJson<String>(dogId),
      'templateId': serializer.toJson<String?>(templateId),
      'type': serializer.toJson<String>(type),
      'title': serializer.toJson<String>(title),
      'note': serializer.toJson<String>(note),
      'dueDate': serializer.toJson<String>(dueDate),
      'doneAt': serializer.toJson<String?>(doneAt),
      'skipped': serializer.toJson<bool>(skipped),
      'source': serializer.toJson<String>(source),
    };
  }

  CareReminder copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? id,
          String? dogId,
          Value<String?> templateId = const Value.absent(),
          String? type,
          String? title,
          String? note,
          String? dueDate,
          Value<String?> doneAt = const Value.absent(),
          bool? skipped,
          String? source}) =>
      CareReminder(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        id: id ?? this.id,
        dogId: dogId ?? this.dogId,
        templateId: templateId.present ? templateId.value : this.templateId,
        type: type ?? this.type,
        title: title ?? this.title,
        note: note ?? this.note,
        dueDate: dueDate ?? this.dueDate,
        doneAt: doneAt.present ? doneAt.value : this.doneAt,
        skipped: skipped ?? this.skipped,
        source: source ?? this.source,
      );
  CareReminder copyWithCompanion(CareRemindersCompanion data) {
    return CareReminder(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      id: data.id.present ? data.id.value : this.id,
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      templateId:
          data.templateId.present ? data.templateId.value : this.templateId,
      type: data.type.present ? data.type.value : this.type,
      title: data.title.present ? data.title.value : this.title,
      note: data.note.present ? data.note.value : this.note,
      dueDate: data.dueDate.present ? data.dueDate.value : this.dueDate,
      doneAt: data.doneAt.present ? data.doneAt.value : this.doneAt,
      skipped: data.skipped.present ? data.skipped.value : this.skipped,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CareReminder(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('dogId: $dogId, ')
          ..write('templateId: $templateId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('dueDate: $dueDate, ')
          ..write('doneAt: $doneAt, ')
          ..write('skipped: $skipped, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(clientUpdatedAt, deleted, id, dogId,
      templateId, type, title, note, dueDate, doneAt, skipped, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CareReminder &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.id == this.id &&
          other.dogId == this.dogId &&
          other.templateId == this.templateId &&
          other.type == this.type &&
          other.title == this.title &&
          other.note == this.note &&
          other.dueDate == this.dueDate &&
          other.doneAt == this.doneAt &&
          other.skipped == this.skipped &&
          other.source == this.source);
}

class CareRemindersCompanion extends UpdateCompanion<CareReminder> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> id;
  final Value<String> dogId;
  final Value<String?> templateId;
  final Value<String> type;
  final Value<String> title;
  final Value<String> note;
  final Value<String> dueDate;
  final Value<String?> doneAt;
  final Value<bool> skipped;
  final Value<String> source;
  final Value<int> rowid;
  const CareRemindersCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.id = const Value.absent(),
    this.dogId = const Value.absent(),
    this.templateId = const Value.absent(),
    this.type = const Value.absent(),
    this.title = const Value.absent(),
    this.note = const Value.absent(),
    this.dueDate = const Value.absent(),
    this.doneAt = const Value.absent(),
    this.skipped = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CareRemindersCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String id,
    required String dogId,
    this.templateId = const Value.absent(),
    required String type,
    required String title,
    this.note = const Value.absent(),
    required String dueDate,
    this.doneAt = const Value.absent(),
    this.skipped = const Value.absent(),
    required String source,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        dogId = Value(dogId),
        type = Value(type),
        title = Value(title),
        dueDate = Value(dueDate),
        source = Value(source);
  static Insertable<CareReminder> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? id,
    Expression<String>? dogId,
    Expression<String>? templateId,
    Expression<String>? type,
    Expression<String>? title,
    Expression<String>? note,
    Expression<String>? dueDate,
    Expression<String>? doneAt,
    Expression<bool>? skipped,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (id != null) 'id': id,
      if (dogId != null) 'dog_id': dogId,
      if (templateId != null) 'template_id': templateId,
      if (type != null) 'type': type,
      if (title != null) 'title': title,
      if (note != null) 'note': note,
      if (dueDate != null) 'due_date': dueDate,
      if (doneAt != null) 'done_at': doneAt,
      if (skipped != null) 'skipped': skipped,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CareRemindersCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? id,
      Value<String>? dogId,
      Value<String?>? templateId,
      Value<String>? type,
      Value<String>? title,
      Value<String>? note,
      Value<String>? dueDate,
      Value<String?>? doneAt,
      Value<bool>? skipped,
      Value<String>? source,
      Value<int>? rowid}) {
    return CareRemindersCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      id: id ?? this.id,
      dogId: dogId ?? this.dogId,
      templateId: templateId ?? this.templateId,
      type: type ?? this.type,
      title: title ?? this.title,
      note: note ?? this.note,
      dueDate: dueDate ?? this.dueDate,
      doneAt: doneAt ?? this.doneAt,
      skipped: skipped ?? this.skipped,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (templateId.present) {
      map['template_id'] = Variable<String>(templateId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (dueDate.present) {
      map['due_date'] = Variable<String>(dueDate.value);
    }
    if (doneAt.present) {
      map['done_at'] = Variable<String>(doneAt.value);
    }
    if (skipped.present) {
      map['skipped'] = Variable<bool>(skipped.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CareRemindersCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('id: $id, ')
          ..write('dogId: $dogId, ')
          ..write('templateId: $templateId, ')
          ..write('type: $type, ')
          ..write('title: $title, ')
          ..write('note: $note, ')
          ..write('dueDate: $dueDate, ')
          ..write('doneAt: $doneAt, ')
          ..write('skipped: $skipped, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DogBadgesTable extends DogBadges
    with TableInfo<$DogBadgesTable, DogBadge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DogBadgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _clientUpdatedAtMeta =
      const VerificationMeta('clientUpdatedAt');
  @override
  late final GeneratedColumn<String> clientUpdatedAt = GeneratedColumn<String>(
      'client_updated_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _badgeIdMeta =
      const VerificationMeta('badgeId');
  @override
  late final GeneratedColumn<String> badgeId = GeneratedColumn<String>(
      'badge_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _earnedAtMeta =
      const VerificationMeta('earnedAt');
  @override
  late final GeneratedColumn<String> earnedAt = GeneratedColumn<String>(
      'earned_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _earnedByUserIdMeta =
      const VerificationMeta('earnedByUserId');
  @override
  late final GeneratedColumn<String> earnedByUserId = GeneratedColumn<String>(
      'earned_by_user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [clientUpdatedAt, deleted, dogId, badgeId, earnedAt, earnedByUserId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dog_badges';
  @override
  VerificationContext validateIntegrity(Insertable<DogBadge> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('client_updated_at')) {
      context.handle(
          _clientUpdatedAtMeta,
          clientUpdatedAt.isAcceptableOrUnknown(
              data['client_updated_at']!, _clientUpdatedAtMeta));
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('badge_id')) {
      context.handle(_badgeIdMeta,
          badgeId.isAcceptableOrUnknown(data['badge_id']!, _badgeIdMeta));
    } else if (isInserting) {
      context.missing(_badgeIdMeta);
    }
    if (data.containsKey('earned_at')) {
      context.handle(_earnedAtMeta,
          earnedAt.isAcceptableOrUnknown(data['earned_at']!, _earnedAtMeta));
    } else if (isInserting) {
      context.missing(_earnedAtMeta);
    }
    if (data.containsKey('earned_by_user_id')) {
      context.handle(
          _earnedByUserIdMeta,
          earnedByUserId.isAcceptableOrUnknown(
              data['earned_by_user_id']!, _earnedByUserIdMeta));
    } else if (isInserting) {
      context.missing(_earnedByUserIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dogId, badgeId};
  @override
  DogBadge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DogBadge(
      clientUpdatedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}client_updated_at'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      badgeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}badge_id'])!,
      earnedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}earned_at'])!,
      earnedByUserId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}earned_by_user_id'])!,
    );
  }

  @override
  $DogBadgesTable createAlias(String alias) {
    return $DogBadgesTable(attachedDatabase, alias);
  }
}

class DogBadge extends DataClass implements Insertable<DogBadge> {
  final String clientUpdatedAt;
  final bool deleted;
  final String dogId;
  final String badgeId;
  final String earnedAt;
  final String earnedByUserId;
  const DogBadge(
      {required this.clientUpdatedAt,
      required this.deleted,
      required this.dogId,
      required this.badgeId,
      required this.earnedAt,
      required this.earnedByUserId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['client_updated_at'] = Variable<String>(clientUpdatedAt);
    map['deleted'] = Variable<bool>(deleted);
    map['dog_id'] = Variable<String>(dogId);
    map['badge_id'] = Variable<String>(badgeId);
    map['earned_at'] = Variable<String>(earnedAt);
    map['earned_by_user_id'] = Variable<String>(earnedByUserId);
    return map;
  }

  DogBadgesCompanion toCompanion(bool nullToAbsent) {
    return DogBadgesCompanion(
      clientUpdatedAt: Value(clientUpdatedAt),
      deleted: Value(deleted),
      dogId: Value(dogId),
      badgeId: Value(badgeId),
      earnedAt: Value(earnedAt),
      earnedByUserId: Value(earnedByUserId),
    );
  }

  factory DogBadge.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DogBadge(
      clientUpdatedAt: serializer.fromJson<String>(json['clientUpdatedAt']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      dogId: serializer.fromJson<String>(json['dogId']),
      badgeId: serializer.fromJson<String>(json['badgeId']),
      earnedAt: serializer.fromJson<String>(json['earnedAt']),
      earnedByUserId: serializer.fromJson<String>(json['earnedByUserId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'clientUpdatedAt': serializer.toJson<String>(clientUpdatedAt),
      'deleted': serializer.toJson<bool>(deleted),
      'dogId': serializer.toJson<String>(dogId),
      'badgeId': serializer.toJson<String>(badgeId),
      'earnedAt': serializer.toJson<String>(earnedAt),
      'earnedByUserId': serializer.toJson<String>(earnedByUserId),
    };
  }

  DogBadge copyWith(
          {String? clientUpdatedAt,
          bool? deleted,
          String? dogId,
          String? badgeId,
          String? earnedAt,
          String? earnedByUserId}) =>
      DogBadge(
        clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
        deleted: deleted ?? this.deleted,
        dogId: dogId ?? this.dogId,
        badgeId: badgeId ?? this.badgeId,
        earnedAt: earnedAt ?? this.earnedAt,
        earnedByUserId: earnedByUserId ?? this.earnedByUserId,
      );
  DogBadge copyWithCompanion(DogBadgesCompanion data) {
    return DogBadge(
      clientUpdatedAt: data.clientUpdatedAt.present
          ? data.clientUpdatedAt.value
          : this.clientUpdatedAt,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      badgeId: data.badgeId.present ? data.badgeId.value : this.badgeId,
      earnedAt: data.earnedAt.present ? data.earnedAt.value : this.earnedAt,
      earnedByUserId: data.earnedByUserId.present
          ? data.earnedByUserId.value
          : this.earnedByUserId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DogBadge(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dogId: $dogId, ')
          ..write('badgeId: $badgeId, ')
          ..write('earnedAt: $earnedAt, ')
          ..write('earnedByUserId: $earnedByUserId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      clientUpdatedAt, deleted, dogId, badgeId, earnedAt, earnedByUserId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DogBadge &&
          other.clientUpdatedAt == this.clientUpdatedAt &&
          other.deleted == this.deleted &&
          other.dogId == this.dogId &&
          other.badgeId == this.badgeId &&
          other.earnedAt == this.earnedAt &&
          other.earnedByUserId == this.earnedByUserId);
}

class DogBadgesCompanion extends UpdateCompanion<DogBadge> {
  final Value<String> clientUpdatedAt;
  final Value<bool> deleted;
  final Value<String> dogId;
  final Value<String> badgeId;
  final Value<String> earnedAt;
  final Value<String> earnedByUserId;
  final Value<int> rowid;
  const DogBadgesCompanion({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    this.dogId = const Value.absent(),
    this.badgeId = const Value.absent(),
    this.earnedAt = const Value.absent(),
    this.earnedByUserId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DogBadgesCompanion.insert({
    this.clientUpdatedAt = const Value.absent(),
    this.deleted = const Value.absent(),
    required String dogId,
    required String badgeId,
    required String earnedAt,
    required String earnedByUserId,
    this.rowid = const Value.absent(),
  })  : dogId = Value(dogId),
        badgeId = Value(badgeId),
        earnedAt = Value(earnedAt),
        earnedByUserId = Value(earnedByUserId);
  static Insertable<DogBadge> custom({
    Expression<String>? clientUpdatedAt,
    Expression<bool>? deleted,
    Expression<String>? dogId,
    Expression<String>? badgeId,
    Expression<String>? earnedAt,
    Expression<String>? earnedByUserId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (clientUpdatedAt != null) 'client_updated_at': clientUpdatedAt,
      if (deleted != null) 'deleted': deleted,
      if (dogId != null) 'dog_id': dogId,
      if (badgeId != null) 'badge_id': badgeId,
      if (earnedAt != null) 'earned_at': earnedAt,
      if (earnedByUserId != null) 'earned_by_user_id': earnedByUserId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DogBadgesCompanion copyWith(
      {Value<String>? clientUpdatedAt,
      Value<bool>? deleted,
      Value<String>? dogId,
      Value<String>? badgeId,
      Value<String>? earnedAt,
      Value<String>? earnedByUserId,
      Value<int>? rowid}) {
    return DogBadgesCompanion(
      clientUpdatedAt: clientUpdatedAt ?? this.clientUpdatedAt,
      deleted: deleted ?? this.deleted,
      dogId: dogId ?? this.dogId,
      badgeId: badgeId ?? this.badgeId,
      earnedAt: earnedAt ?? this.earnedAt,
      earnedByUserId: earnedByUserId ?? this.earnedByUserId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (clientUpdatedAt.present) {
      map['client_updated_at'] = Variable<String>(clientUpdatedAt.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (badgeId.present) {
      map['badge_id'] = Variable<String>(badgeId.value);
    }
    if (earnedAt.present) {
      map['earned_at'] = Variable<String>(earnedAt.value);
    }
    if (earnedByUserId.present) {
      map['earned_by_user_id'] = Variable<String>(earnedByUserId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DogBadgesCompanion(')
          ..write('clientUpdatedAt: $clientUpdatedAt, ')
          ..write('deleted: $deleted, ')
          ..write('dogId: $dogId, ')
          ..write('badgeId: $badgeId, ')
          ..write('earnedAt: $earnedAt, ')
          ..write('earnedByUserId: $earnedByUserId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAccountsTable extends LocalAccounts
    with TableInfo<$LocalAccountsTable, LocalAccount> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAccountsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _tokenMeta = const VerificationMeta('token');
  @override
  late final GeneratedColumn<String> token = GeneratedColumn<String>(
      'token', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
      'created_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, userId, token, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_accounts';
  @override
  VerificationContext validateIntegrity(Insertable<LocalAccount> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('token')) {
      context.handle(
          _tokenMeta, token.isAcceptableOrUnknown(data['token']!, _tokenMeta));
    } else if (isInserting) {
      context.missing(_tokenMeta);
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
  LocalAccount map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAccount(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      token: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}token'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalAccountsTable createAlias(String alias) {
    return $LocalAccountsTable(attachedDatabase, alias);
  }
}

class LocalAccount extends DataClass implements Insertable<LocalAccount> {
  final int id;
  final String userId;
  final String token;
  final String createdAt;
  const LocalAccount(
      {required this.id,
      required this.userId,
      required this.token,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['token'] = Variable<String>(token);
    map['created_at'] = Variable<String>(createdAt);
    return map;
  }

  LocalAccountsCompanion toCompanion(bool nullToAbsent) {
    return LocalAccountsCompanion(
      id: Value(id),
      userId: Value(userId),
      token: Value(token),
      createdAt: Value(createdAt),
    );
  }

  factory LocalAccount.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAccount(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      token: serializer.fromJson<String>(json['token']),
      createdAt: serializer.fromJson<String>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'token': serializer.toJson<String>(token),
      'createdAt': serializer.toJson<String>(createdAt),
    };
  }

  LocalAccount copyWith(
          {int? id, String? userId, String? token, String? createdAt}) =>
      LocalAccount(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        token: token ?? this.token,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalAccount copyWithCompanion(LocalAccountsCompanion data) {
    return LocalAccount(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      token: data.token.present ? data.token.value : this.token,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAccount(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('token: $token, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userId, token, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAccount &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.token == this.token &&
          other.createdAt == this.createdAt);
}

class LocalAccountsCompanion extends UpdateCompanion<LocalAccount> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> token;
  final Value<String> createdAt;
  const LocalAccountsCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.token = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LocalAccountsCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String token,
    required String createdAt,
  })  : userId = Value(userId),
        token = Value(token),
        createdAt = Value(createdAt);
  static Insertable<LocalAccount> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? token,
    Expression<String>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (token != null) 'token': token,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LocalAccountsCompanion copyWith(
      {Value<int>? id,
      Value<String>? userId,
      Value<String>? token,
      Value<String>? createdAt}) {
    return LocalAccountsCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      token: token ?? this.token,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (token.present) {
      map['token'] = Variable<String>(token.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAccountsCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('token: $token, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SyncStatesTable extends SyncStates
    with TableInfo<$SyncStatesTable, SyncState> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _householdIdMeta =
      const VerificationMeta('householdId');
  @override
  late final GeneratedColumn<String> householdId = GeneratedColumn<String>(
      'household_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _lastPullSeqMeta =
      const VerificationMeta('lastPullSeq');
  @override
  late final GeneratedColumn<int> lastPullSeq = GeneratedColumn<int>(
      'last_pull_seq', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastPushAtMeta =
      const VerificationMeta('lastPushAt');
  @override
  late final GeneratedColumn<String> lastPushAt = GeneratedColumn<String>(
      'last_push_at', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [householdId, lastPullSeq, lastPushAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_states';
  @override
  VerificationContext validateIntegrity(Insertable<SyncState> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('household_id')) {
      context.handle(
          _householdIdMeta,
          householdId.isAcceptableOrUnknown(
              data['household_id']!, _householdIdMeta));
    } else if (isInserting) {
      context.missing(_householdIdMeta);
    }
    if (data.containsKey('last_pull_seq')) {
      context.handle(
          _lastPullSeqMeta,
          lastPullSeq.isAcceptableOrUnknown(
              data['last_pull_seq']!, _lastPullSeqMeta));
    }
    if (data.containsKey('last_push_at')) {
      context.handle(
          _lastPushAtMeta,
          lastPushAt.isAcceptableOrUnknown(
              data['last_push_at']!, _lastPushAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {householdId};
  @override
  SyncState map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncState(
      householdId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}household_id'])!,
      lastPullSeq: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_pull_seq'])!,
      lastPushAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_push_at']),
    );
  }

  @override
  $SyncStatesTable createAlias(String alias) {
    return $SyncStatesTable(attachedDatabase, alias);
  }
}

class SyncState extends DataClass implements Insertable<SyncState> {
  final String householdId;
  final int lastPullSeq;
  final String? lastPushAt;
  const SyncState(
      {required this.householdId, required this.lastPullSeq, this.lastPushAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['household_id'] = Variable<String>(householdId);
    map['last_pull_seq'] = Variable<int>(lastPullSeq);
    if (!nullToAbsent || lastPushAt != null) {
      map['last_push_at'] = Variable<String>(lastPushAt);
    }
    return map;
  }

  SyncStatesCompanion toCompanion(bool nullToAbsent) {
    return SyncStatesCompanion(
      householdId: Value(householdId),
      lastPullSeq: Value(lastPullSeq),
      lastPushAt: lastPushAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPushAt),
    );
  }

  factory SyncState.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncState(
      householdId: serializer.fromJson<String>(json['householdId']),
      lastPullSeq: serializer.fromJson<int>(json['lastPullSeq']),
      lastPushAt: serializer.fromJson<String?>(json['lastPushAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'householdId': serializer.toJson<String>(householdId),
      'lastPullSeq': serializer.toJson<int>(lastPullSeq),
      'lastPushAt': serializer.toJson<String?>(lastPushAt),
    };
  }

  SyncState copyWith(
          {String? householdId,
          int? lastPullSeq,
          Value<String?> lastPushAt = const Value.absent()}) =>
      SyncState(
        householdId: householdId ?? this.householdId,
        lastPullSeq: lastPullSeq ?? this.lastPullSeq,
        lastPushAt: lastPushAt.present ? lastPushAt.value : this.lastPushAt,
      );
  SyncState copyWithCompanion(SyncStatesCompanion data) {
    return SyncState(
      householdId:
          data.householdId.present ? data.householdId.value : this.householdId,
      lastPullSeq:
          data.lastPullSeq.present ? data.lastPullSeq.value : this.lastPullSeq,
      lastPushAt:
          data.lastPushAt.present ? data.lastPushAt.value : this.lastPushAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncState(')
          ..write('householdId: $householdId, ')
          ..write('lastPullSeq: $lastPullSeq, ')
          ..write('lastPushAt: $lastPushAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(householdId, lastPullSeq, lastPushAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncState &&
          other.householdId == this.householdId &&
          other.lastPullSeq == this.lastPullSeq &&
          other.lastPushAt == this.lastPushAt);
}

class SyncStatesCompanion extends UpdateCompanion<SyncState> {
  final Value<String> householdId;
  final Value<int> lastPullSeq;
  final Value<String?> lastPushAt;
  final Value<int> rowid;
  const SyncStatesCompanion({
    this.householdId = const Value.absent(),
    this.lastPullSeq = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStatesCompanion.insert({
    required String householdId,
    this.lastPullSeq = const Value.absent(),
    this.lastPushAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : householdId = Value(householdId);
  static Insertable<SyncState> custom({
    Expression<String>? householdId,
    Expression<int>? lastPullSeq,
    Expression<String>? lastPushAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (householdId != null) 'household_id': householdId,
      if (lastPullSeq != null) 'last_pull_seq': lastPullSeq,
      if (lastPushAt != null) 'last_push_at': lastPushAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStatesCompanion copyWith(
      {Value<String>? householdId,
      Value<int>? lastPullSeq,
      Value<String?>? lastPushAt,
      Value<int>? rowid}) {
    return SyncStatesCompanion(
      householdId: householdId ?? this.householdId,
      lastPullSeq: lastPullSeq ?? this.lastPullSeq,
      lastPushAt: lastPushAt ?? this.lastPushAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (householdId.present) {
      map['household_id'] = Variable<String>(householdId.value);
    }
    if (lastPullSeq.present) {
      map['last_pull_seq'] = Variable<int>(lastPullSeq.value);
    }
    if (lastPushAt.present) {
      map['last_push_at'] = Variable<String>(lastPushAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStatesCompanion(')
          ..write('householdId: $householdId, ')
          ..write('lastPullSeq: $lastPullSeq, ')
          ..write('lastPushAt: $lastPushAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncOutboxTable extends SyncOutbox
    with TableInfo<$SyncOutboxTable, SyncOutboxData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncOutboxTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tblMeta = const VerificationMeta('tbl');
  @override
  late final GeneratedColumn<String> tbl = GeneratedColumn<String>(
      'table_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _pkMeta = const VerificationMeta('pk');
  @override
  late final GeneratedColumn<String> pk = GeneratedColumn<String>(
      'pk', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _deletedMeta =
      const VerificationMeta('deleted');
  @override
  late final GeneratedColumn<bool> deleted = GeneratedColumn<bool>(
      'deleted', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("deleted" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _versionMeta =
      const VerificationMeta('version');
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
      'version', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _changedAtMeta =
      const VerificationMeta('changedAt');
  @override
  late final GeneratedColumn<String> changedAt = GeneratedColumn<String>(
      'changed_at', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  @override
  List<GeneratedColumn> get $columns => [tbl, pk, deleted, version, changedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_outbox';
  @override
  VerificationContext validateIntegrity(Insertable<SyncOutboxData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('table_name')) {
      context.handle(
          _tblMeta, tbl.isAcceptableOrUnknown(data['table_name']!, _tblMeta));
    } else if (isInserting) {
      context.missing(_tblMeta);
    }
    if (data.containsKey('pk')) {
      context.handle(_pkMeta, pk.isAcceptableOrUnknown(data['pk']!, _pkMeta));
    } else if (isInserting) {
      context.missing(_pkMeta);
    }
    if (data.containsKey('deleted')) {
      context.handle(_deletedMeta,
          deleted.isAcceptableOrUnknown(data['deleted']!, _deletedMeta));
    }
    if (data.containsKey('version')) {
      context.handle(_versionMeta,
          version.isAcceptableOrUnknown(data['version']!, _versionMeta));
    }
    if (data.containsKey('changed_at')) {
      context.handle(_changedAtMeta,
          changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tbl, pk};
  @override
  SyncOutboxData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncOutboxData(
      tbl: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}table_name'])!,
      pk: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}pk'])!,
      deleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}deleted'])!,
      version: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}version'])!,
      changedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}changed_at'])!,
    );
  }

  @override
  $SyncOutboxTable createAlias(String alias) {
    return $SyncOutboxTable(attachedDatabase, alias);
  }
}

class SyncOutboxData extends DataClass implements Insertable<SyncOutboxData> {
  final String tbl;
  final String pk;
  final bool deleted;
  final int version;

  /// 最近一次本地变更时刻（ISO 8601 UTC 毫秒）；墓碑上行时作为 client_updated_at。
  final String changedAt;
  const SyncOutboxData(
      {required this.tbl,
      required this.pk,
      required this.deleted,
      required this.version,
      required this.changedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['table_name'] = Variable<String>(tbl);
    map['pk'] = Variable<String>(pk);
    map['deleted'] = Variable<bool>(deleted);
    map['version'] = Variable<int>(version);
    map['changed_at'] = Variable<String>(changedAt);
    return map;
  }

  SyncOutboxCompanion toCompanion(bool nullToAbsent) {
    return SyncOutboxCompanion(
      tbl: Value(tbl),
      pk: Value(pk),
      deleted: Value(deleted),
      version: Value(version),
      changedAt: Value(changedAt),
    );
  }

  factory SyncOutboxData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncOutboxData(
      tbl: serializer.fromJson<String>(json['tbl']),
      pk: serializer.fromJson<String>(json['pk']),
      deleted: serializer.fromJson<bool>(json['deleted']),
      version: serializer.fromJson<int>(json['version']),
      changedAt: serializer.fromJson<String>(json['changedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tbl': serializer.toJson<String>(tbl),
      'pk': serializer.toJson<String>(pk),
      'deleted': serializer.toJson<bool>(deleted),
      'version': serializer.toJson<int>(version),
      'changedAt': serializer.toJson<String>(changedAt),
    };
  }

  SyncOutboxData copyWith(
          {String? tbl,
          String? pk,
          bool? deleted,
          int? version,
          String? changedAt}) =>
      SyncOutboxData(
        tbl: tbl ?? this.tbl,
        pk: pk ?? this.pk,
        deleted: deleted ?? this.deleted,
        version: version ?? this.version,
        changedAt: changedAt ?? this.changedAt,
      );
  SyncOutboxData copyWithCompanion(SyncOutboxCompanion data) {
    return SyncOutboxData(
      tbl: data.tbl.present ? data.tbl.value : this.tbl,
      pk: data.pk.present ? data.pk.value : this.pk,
      deleted: data.deleted.present ? data.deleted.value : this.deleted,
      version: data.version.present ? data.version.value : this.version,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxData(')
          ..write('tbl: $tbl, ')
          ..write('pk: $pk, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tbl, pk, deleted, version, changedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncOutboxData &&
          other.tbl == this.tbl &&
          other.pk == this.pk &&
          other.deleted == this.deleted &&
          other.version == this.version &&
          other.changedAt == this.changedAt);
}

class SyncOutboxCompanion extends UpdateCompanion<SyncOutboxData> {
  final Value<String> tbl;
  final Value<String> pk;
  final Value<bool> deleted;
  final Value<int> version;
  final Value<String> changedAt;
  final Value<int> rowid;
  const SyncOutboxCompanion({
    this.tbl = const Value.absent(),
    this.pk = const Value.absent(),
    this.deleted = const Value.absent(),
    this.version = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncOutboxCompanion.insert({
    required String tbl,
    required String pk,
    this.deleted = const Value.absent(),
    this.version = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : tbl = Value(tbl),
        pk = Value(pk);
  static Insertable<SyncOutboxData> custom({
    Expression<String>? tbl,
    Expression<String>? pk,
    Expression<bool>? deleted,
    Expression<int>? version,
    Expression<String>? changedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tbl != null) 'table_name': tbl,
      if (pk != null) 'pk': pk,
      if (deleted != null) 'deleted': deleted,
      if (version != null) 'version': version,
      if (changedAt != null) 'changed_at': changedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncOutboxCompanion copyWith(
      {Value<String>? tbl,
      Value<String>? pk,
      Value<bool>? deleted,
      Value<int>? version,
      Value<String>? changedAt,
      Value<int>? rowid}) {
    return SyncOutboxCompanion(
      tbl: tbl ?? this.tbl,
      pk: pk ?? this.pk,
      deleted: deleted ?? this.deleted,
      version: version ?? this.version,
      changedAt: changedAt ?? this.changedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tbl.present) {
      map['table_name'] = Variable<String>(tbl.value);
    }
    if (pk.present) {
      map['pk'] = Variable<String>(pk.value);
    }
    if (deleted.present) {
      map['deleted'] = Variable<bool>(deleted.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<String>(changedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncOutboxCompanion(')
          ..write('tbl: $tbl, ')
          ..write('pk: $pk, ')
          ..write('deleted: $deleted, ')
          ..write('version: $version, ')
          ..write('changedAt: $changedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncFlagsTable extends SyncFlags
    with TableInfo<$SyncFlagsTable, SyncFlag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncFlagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _applyingMeta =
      const VerificationMeta('applying');
  @override
  late final GeneratedColumn<bool> applying = GeneratedColumn<bool>(
      'applying', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("applying" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [id, applying];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_flags';
  @override
  VerificationContext validateIntegrity(Insertable<SyncFlag> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('applying')) {
      context.handle(_applyingMeta,
          applying.isAcceptableOrUnknown(data['applying']!, _applyingMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncFlag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncFlag(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      applying: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}applying'])!,
    );
  }

  @override
  $SyncFlagsTable createAlias(String alias) {
    return $SyncFlagsTable(attachedDatabase, alias);
  }
}

class SyncFlag extends DataClass implements Insertable<SyncFlag> {
  final int id;
  final bool applying;
  const SyncFlag({required this.id, required this.applying});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['applying'] = Variable<bool>(applying);
    return map;
  }

  SyncFlagsCompanion toCompanion(bool nullToAbsent) {
    return SyncFlagsCompanion(
      id: Value(id),
      applying: Value(applying),
    );
  }

  factory SyncFlag.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncFlag(
      id: serializer.fromJson<int>(json['id']),
      applying: serializer.fromJson<bool>(json['applying']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'applying': serializer.toJson<bool>(applying),
    };
  }

  SyncFlag copyWith({int? id, bool? applying}) => SyncFlag(
        id: id ?? this.id,
        applying: applying ?? this.applying,
      );
  SyncFlag copyWithCompanion(SyncFlagsCompanion data) {
    return SyncFlag(
      id: data.id.present ? data.id.value : this.id,
      applying: data.applying.present ? data.applying.value : this.applying,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncFlag(')
          ..write('id: $id, ')
          ..write('applying: $applying')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, applying);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncFlag &&
          other.id == this.id &&
          other.applying == this.applying);
}

class SyncFlagsCompanion extends UpdateCompanion<SyncFlag> {
  final Value<int> id;
  final Value<bool> applying;
  const SyncFlagsCompanion({
    this.id = const Value.absent(),
    this.applying = const Value.absent(),
  });
  SyncFlagsCompanion.insert({
    this.id = const Value.absent(),
    this.applying = const Value.absent(),
  });
  static Insertable<SyncFlag> custom({
    Expression<int>? id,
    Expression<bool>? applying,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (applying != null) 'applying': applying,
    });
  }

  SyncFlagsCompanion copyWith({Value<int>? id, Value<bool>? applying}) {
    return SyncFlagsCompanion(
      id: id ?? this.id,
      applying: applying ?? this.applying,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (applying.present) {
      map['applying'] = Variable<bool>(applying.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncFlagsCompanion(')
          ..write('id: $id, ')
          ..write('applying: $applying')
          ..write(')'))
        .toString();
  }
}

class $BadgePopupsSeenTable extends BadgePopupsSeen
    with TableInfo<$BadgePopupsSeenTable, BadgePopupsSeenData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BadgePopupsSeenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dogIdMeta = const VerificationMeta('dogId');
  @override
  late final GeneratedColumn<String> dogId = GeneratedColumn<String>(
      'dog_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _badgeIdMeta =
      const VerificationMeta('badgeId');
  @override
  late final GeneratedColumn<String> badgeId = GeneratedColumn<String>(
      'badge_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _seenAtMeta = const VerificationMeta('seenAt');
  @override
  late final GeneratedColumn<String> seenAt = GeneratedColumn<String>(
      'seen_at', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [dogId, badgeId, seenAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'badge_popups_seen';
  @override
  VerificationContext validateIntegrity(
      Insertable<BadgePopupsSeenData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('dog_id')) {
      context.handle(
          _dogIdMeta, dogId.isAcceptableOrUnknown(data['dog_id']!, _dogIdMeta));
    } else if (isInserting) {
      context.missing(_dogIdMeta);
    }
    if (data.containsKey('badge_id')) {
      context.handle(_badgeIdMeta,
          badgeId.isAcceptableOrUnknown(data['badge_id']!, _badgeIdMeta));
    } else if (isInserting) {
      context.missing(_badgeIdMeta);
    }
    if (data.containsKey('seen_at')) {
      context.handle(_seenAtMeta,
          seenAt.isAcceptableOrUnknown(data['seen_at']!, _seenAtMeta));
    } else if (isInserting) {
      context.missing(_seenAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dogId, badgeId};
  @override
  BadgePopupsSeenData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BadgePopupsSeenData(
      dogId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}dog_id'])!,
      badgeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}badge_id'])!,
      seenAt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}seen_at'])!,
    );
  }

  @override
  $BadgePopupsSeenTable createAlias(String alias) {
    return $BadgePopupsSeenTable(attachedDatabase, alias);
  }
}

class BadgePopupsSeenData extends DataClass
    implements Insertable<BadgePopupsSeenData> {
  final String dogId;
  final String badgeId;
  final String seenAt;
  const BadgePopupsSeenData(
      {required this.dogId, required this.badgeId, required this.seenAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['dog_id'] = Variable<String>(dogId);
    map['badge_id'] = Variable<String>(badgeId);
    map['seen_at'] = Variable<String>(seenAt);
    return map;
  }

  BadgePopupsSeenCompanion toCompanion(bool nullToAbsent) {
    return BadgePopupsSeenCompanion(
      dogId: Value(dogId),
      badgeId: Value(badgeId),
      seenAt: Value(seenAt),
    );
  }

  factory BadgePopupsSeenData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BadgePopupsSeenData(
      dogId: serializer.fromJson<String>(json['dogId']),
      badgeId: serializer.fromJson<String>(json['badgeId']),
      seenAt: serializer.fromJson<String>(json['seenAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dogId': serializer.toJson<String>(dogId),
      'badgeId': serializer.toJson<String>(badgeId),
      'seenAt': serializer.toJson<String>(seenAt),
    };
  }

  BadgePopupsSeenData copyWith(
          {String? dogId, String? badgeId, String? seenAt}) =>
      BadgePopupsSeenData(
        dogId: dogId ?? this.dogId,
        badgeId: badgeId ?? this.badgeId,
        seenAt: seenAt ?? this.seenAt,
      );
  BadgePopupsSeenData copyWithCompanion(BadgePopupsSeenCompanion data) {
    return BadgePopupsSeenData(
      dogId: data.dogId.present ? data.dogId.value : this.dogId,
      badgeId: data.badgeId.present ? data.badgeId.value : this.badgeId,
      seenAt: data.seenAt.present ? data.seenAt.value : this.seenAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BadgePopupsSeenData(')
          ..write('dogId: $dogId, ')
          ..write('badgeId: $badgeId, ')
          ..write('seenAt: $seenAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dogId, badgeId, seenAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BadgePopupsSeenData &&
          other.dogId == this.dogId &&
          other.badgeId == this.badgeId &&
          other.seenAt == this.seenAt);
}

class BadgePopupsSeenCompanion extends UpdateCompanion<BadgePopupsSeenData> {
  final Value<String> dogId;
  final Value<String> badgeId;
  final Value<String> seenAt;
  final Value<int> rowid;
  const BadgePopupsSeenCompanion({
    this.dogId = const Value.absent(),
    this.badgeId = const Value.absent(),
    this.seenAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BadgePopupsSeenCompanion.insert({
    required String dogId,
    required String badgeId,
    required String seenAt,
    this.rowid = const Value.absent(),
  })  : dogId = Value(dogId),
        badgeId = Value(badgeId),
        seenAt = Value(seenAt);
  static Insertable<BadgePopupsSeenData> custom({
    Expression<String>? dogId,
    Expression<String>? badgeId,
    Expression<String>? seenAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dogId != null) 'dog_id': dogId,
      if (badgeId != null) 'badge_id': badgeId,
      if (seenAt != null) 'seen_at': seenAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BadgePopupsSeenCompanion copyWith(
      {Value<String>? dogId,
      Value<String>? badgeId,
      Value<String>? seenAt,
      Value<int>? rowid}) {
    return BadgePopupsSeenCompanion(
      dogId: dogId ?? this.dogId,
      badgeId: badgeId ?? this.badgeId,
      seenAt: seenAt ?? this.seenAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dogId.present) {
      map['dog_id'] = Variable<String>(dogId.value);
    }
    if (badgeId.present) {
      map['badge_id'] = Variable<String>(badgeId.value);
    }
    if (seenAt.present) {
      map['seen_at'] = Variable<String>(seenAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BadgePopupsSeenCompanion(')
          ..write('dogId: $dogId, ')
          ..write('badgeId: $badgeId, ')
          ..write('seenAt: $seenAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ContentVersionsTable contentVersions =
      $ContentVersionsTable(this);
  late final $ContentSkillsTable contentSkills = $ContentSkillsTable(this);
  late final $ContentIssuesTable contentIssues = $ContentIssuesTable(this);
  late final $ContentBadgesTable contentBadges = $ContentBadgesTable(this);
  late final $ContentCareItemsTable contentCareItems =
      $ContentCareItemsTable(this);
  late final $ContentAiLexiconsTable contentAiLexicons =
      $ContentAiLexiconsTable(this);
  late final $UsersTable users = $UsersTable(this);
  late final $HouseholdsTable households = $HouseholdsTable(this);
  late final $HouseholdMembersTable householdMembers =
      $HouseholdMembersTable(this);
  late final $DogsTable dogs = $DogsTable(this);
  late final $DogConcernsTable dogConcerns = $DogConcernsTable(this);
  late final $DogCuesTable dogCues = $DogCuesTable(this);
  late final $DogSkillStatusesTable dogSkillStatuses =
      $DogSkillStatusesTable(this);
  late final $WeeklyPlansTable weeklyPlans = $WeeklyPlansTable(this);
  late final $PlanGoalsTable planGoals = $PlanGoalsTable(this);
  late final $DailyMiniTasksTable dailyMiniTasks = $DailyMiniTasksTable(this);
  late final $OnboardingDraftsTable onboardingDrafts =
      $OnboardingDraftsTable(this);
  late final $TrainingSessionsTable trainingSessions =
      $TrainingSessionsTable(this);
  late final $StreaksTable streaks = $StreaksTable(this);
  late final $WeeklyReportsTable weeklyReports = $WeeklyReportsTable(this);
  late final $AiConversationsTable aiConversations =
      $AiConversationsTable(this);
  late final $AiMessagesTable aiMessages = $AiMessagesTable(this);
  late final $DiagnosisResultsTable diagnosisResults =
      $DiagnosisResultsTable(this);
  late final $ReminderSettingsTable reminderSettings =
      $ReminderSettingsTable(this);
  late final $CareRemindersTable careReminders = $CareRemindersTable(this);
  late final $DogBadgesTable dogBadges = $DogBadgesTable(this);
  late final $LocalAccountsTable localAccounts = $LocalAccountsTable(this);
  late final $SyncStatesTable syncStates = $SyncStatesTable(this);
  late final $SyncOutboxTable syncOutbox = $SyncOutboxTable(this);
  late final $SyncFlagsTable syncFlags = $SyncFlagsTable(this);
  late final $BadgePopupsSeenTable badgePopupsSeen =
      $BadgePopupsSeenTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        contentVersions,
        contentSkills,
        contentIssues,
        contentBadges,
        contentCareItems,
        contentAiLexicons,
        users,
        households,
        householdMembers,
        dogs,
        dogConcerns,
        dogCues,
        dogSkillStatuses,
        weeklyPlans,
        planGoals,
        dailyMiniTasks,
        onboardingDrafts,
        trainingSessions,
        streaks,
        weeklyReports,
        aiConversations,
        aiMessages,
        diagnosisResults,
        reminderSettings,
        careReminders,
        dogBadges,
        localAccounts,
        syncStates,
        syncOutbox,
        syncFlags,
        badgePopupsSeen
      ];
}

typedef $$ContentVersionsTableCreateCompanionBuilder = ContentVersionsCompanion
    Function({
  required String version,
  required String loadedAt,
  Value<int> rowid,
});
typedef $$ContentVersionsTableUpdateCompanionBuilder = ContentVersionsCompanion
    Function({
  Value<String> version,
  Value<String> loadedAt,
  Value<int> rowid,
});

class $$ContentVersionsTableFilterComposer
    extends Composer<_$AppDatabase, $ContentVersionsTable> {
  $$ContentVersionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get loadedAt => $composableBuilder(
      column: $table.loadedAt, builder: (column) => ColumnFilters(column));
}

class $$ContentVersionsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentVersionsTable> {
  $$ContentVersionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get loadedAt => $composableBuilder(
      column: $table.loadedAt, builder: (column) => ColumnOrderings(column));
}

class $$ContentVersionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentVersionsTable> {
  $$ContentVersionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get loadedAt =>
      $composableBuilder(column: $table.loadedAt, builder: (column) => column);
}

class $$ContentVersionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContentVersionsTable,
    ContentVersion,
    $$ContentVersionsTableFilterComposer,
    $$ContentVersionsTableOrderingComposer,
    $$ContentVersionsTableAnnotationComposer,
    $$ContentVersionsTableCreateCompanionBuilder,
    $$ContentVersionsTableUpdateCompanionBuilder,
    (
      ContentVersion,
      BaseReferences<_$AppDatabase, $ContentVersionsTable, ContentVersion>
    ),
    ContentVersion,
    PrefetchHooks Function()> {
  $$ContentVersionsTableTableManager(
      _$AppDatabase db, $ContentVersionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentVersionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentVersionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentVersionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> version = const Value.absent(),
            Value<String> loadedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentVersionsCompanion(
            version: version,
            loadedAt: loadedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String version,
            required String loadedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentVersionsCompanion.insert(
            version: version,
            loadedAt: loadedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContentVersionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContentVersionsTable,
    ContentVersion,
    $$ContentVersionsTableFilterComposer,
    $$ContentVersionsTableOrderingComposer,
    $$ContentVersionsTableAnnotationComposer,
    $$ContentVersionsTableCreateCompanionBuilder,
    $$ContentVersionsTableUpdateCompanionBuilder,
    (
      ContentVersion,
      BaseReferences<_$AppDatabase, $ContentVersionsTable, ContentVersion>
    ),
    ContentVersion,
    PrefetchHooks Function()>;
typedef $$ContentSkillsTableCreateCompanionBuilder = ContentSkillsCompanion
    Function({
  required String id,
  required String version,
  required String json,
  Value<int> rowid,
});
typedef $$ContentSkillsTableUpdateCompanionBuilder = ContentSkillsCompanion
    Function({
  Value<String> id,
  Value<String> version,
  Value<String> json,
  Value<int> rowid,
});

class $$ContentSkillsTableFilterComposer
    extends Composer<_$AppDatabase, $ContentSkillsTable> {
  $$ContentSkillsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));
}

class $$ContentSkillsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentSkillsTable> {
  $$ContentSkillsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));
}

class $$ContentSkillsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentSkillsTable> {
  $$ContentSkillsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$ContentSkillsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContentSkillsTable,
    ContentSkill,
    $$ContentSkillsTableFilterComposer,
    $$ContentSkillsTableOrderingComposer,
    $$ContentSkillsTableAnnotationComposer,
    $$ContentSkillsTableCreateCompanionBuilder,
    $$ContentSkillsTableUpdateCompanionBuilder,
    (
      ContentSkill,
      BaseReferences<_$AppDatabase, $ContentSkillsTable, ContentSkill>
    ),
    ContentSkill,
    PrefetchHooks Function()> {
  $$ContentSkillsTableTableManager(_$AppDatabase db, $ContentSkillsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentSkillsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentSkillsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentSkillsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> version = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentSkillsCompanion(
            id: id,
            version: version,
            json: json,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String version,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentSkillsCompanion.insert(
            id: id,
            version: version,
            json: json,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContentSkillsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContentSkillsTable,
    ContentSkill,
    $$ContentSkillsTableFilterComposer,
    $$ContentSkillsTableOrderingComposer,
    $$ContentSkillsTableAnnotationComposer,
    $$ContentSkillsTableCreateCompanionBuilder,
    $$ContentSkillsTableUpdateCompanionBuilder,
    (
      ContentSkill,
      BaseReferences<_$AppDatabase, $ContentSkillsTable, ContentSkill>
    ),
    ContentSkill,
    PrefetchHooks Function()>;
typedef $$ContentIssuesTableCreateCompanionBuilder = ContentIssuesCompanion
    Function({
  required String id,
  required String version,
  required String json,
  Value<int> rowid,
});
typedef $$ContentIssuesTableUpdateCompanionBuilder = ContentIssuesCompanion
    Function({
  Value<String> id,
  Value<String> version,
  Value<String> json,
  Value<int> rowid,
});

class $$ContentIssuesTableFilterComposer
    extends Composer<_$AppDatabase, $ContentIssuesTable> {
  $$ContentIssuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));
}

class $$ContentIssuesTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentIssuesTable> {
  $$ContentIssuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));
}

class $$ContentIssuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentIssuesTable> {
  $$ContentIssuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$ContentIssuesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContentIssuesTable,
    ContentIssue,
    $$ContentIssuesTableFilterComposer,
    $$ContentIssuesTableOrderingComposer,
    $$ContentIssuesTableAnnotationComposer,
    $$ContentIssuesTableCreateCompanionBuilder,
    $$ContentIssuesTableUpdateCompanionBuilder,
    (
      ContentIssue,
      BaseReferences<_$AppDatabase, $ContentIssuesTable, ContentIssue>
    ),
    ContentIssue,
    PrefetchHooks Function()> {
  $$ContentIssuesTableTableManager(_$AppDatabase db, $ContentIssuesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentIssuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentIssuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentIssuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> version = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentIssuesCompanion(
            id: id,
            version: version,
            json: json,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String version,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentIssuesCompanion.insert(
            id: id,
            version: version,
            json: json,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContentIssuesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContentIssuesTable,
    ContentIssue,
    $$ContentIssuesTableFilterComposer,
    $$ContentIssuesTableOrderingComposer,
    $$ContentIssuesTableAnnotationComposer,
    $$ContentIssuesTableCreateCompanionBuilder,
    $$ContentIssuesTableUpdateCompanionBuilder,
    (
      ContentIssue,
      BaseReferences<_$AppDatabase, $ContentIssuesTable, ContentIssue>
    ),
    ContentIssue,
    PrefetchHooks Function()>;
typedef $$ContentBadgesTableCreateCompanionBuilder = ContentBadgesCompanion
    Function({
  required String id,
  required String version,
  required String json,
  Value<int> rowid,
});
typedef $$ContentBadgesTableUpdateCompanionBuilder = ContentBadgesCompanion
    Function({
  Value<String> id,
  Value<String> version,
  Value<String> json,
  Value<int> rowid,
});

class $$ContentBadgesTableFilterComposer
    extends Composer<_$AppDatabase, $ContentBadgesTable> {
  $$ContentBadgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));
}

class $$ContentBadgesTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentBadgesTable> {
  $$ContentBadgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));
}

class $$ContentBadgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentBadgesTable> {
  $$ContentBadgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$ContentBadgesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContentBadgesTable,
    ContentBadge,
    $$ContentBadgesTableFilterComposer,
    $$ContentBadgesTableOrderingComposer,
    $$ContentBadgesTableAnnotationComposer,
    $$ContentBadgesTableCreateCompanionBuilder,
    $$ContentBadgesTableUpdateCompanionBuilder,
    (
      ContentBadge,
      BaseReferences<_$AppDatabase, $ContentBadgesTable, ContentBadge>
    ),
    ContentBadge,
    PrefetchHooks Function()> {
  $$ContentBadgesTableTableManager(_$AppDatabase db, $ContentBadgesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentBadgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentBadgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentBadgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> version = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentBadgesCompanion(
            id: id,
            version: version,
            json: json,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String version,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentBadgesCompanion.insert(
            id: id,
            version: version,
            json: json,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContentBadgesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContentBadgesTable,
    ContentBadge,
    $$ContentBadgesTableFilterComposer,
    $$ContentBadgesTableOrderingComposer,
    $$ContentBadgesTableAnnotationComposer,
    $$ContentBadgesTableCreateCompanionBuilder,
    $$ContentBadgesTableUpdateCompanionBuilder,
    (
      ContentBadge,
      BaseReferences<_$AppDatabase, $ContentBadgesTable, ContentBadge>
    ),
    ContentBadge,
    PrefetchHooks Function()>;
typedef $$ContentCareItemsTableCreateCompanionBuilder
    = ContentCareItemsCompanion Function({
  required String id,
  required String version,
  required String json,
  Value<int> rowid,
});
typedef $$ContentCareItemsTableUpdateCompanionBuilder
    = ContentCareItemsCompanion Function({
  Value<String> id,
  Value<String> version,
  Value<String> json,
  Value<int> rowid,
});

class $$ContentCareItemsTableFilterComposer
    extends Composer<_$AppDatabase, $ContentCareItemsTable> {
  $$ContentCareItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));
}

class $$ContentCareItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentCareItemsTable> {
  $$ContentCareItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));
}

class $$ContentCareItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentCareItemsTable> {
  $$ContentCareItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$ContentCareItemsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContentCareItemsTable,
    ContentCareItem,
    $$ContentCareItemsTableFilterComposer,
    $$ContentCareItemsTableOrderingComposer,
    $$ContentCareItemsTableAnnotationComposer,
    $$ContentCareItemsTableCreateCompanionBuilder,
    $$ContentCareItemsTableUpdateCompanionBuilder,
    (
      ContentCareItem,
      BaseReferences<_$AppDatabase, $ContentCareItemsTable, ContentCareItem>
    ),
    ContentCareItem,
    PrefetchHooks Function()> {
  $$ContentCareItemsTableTableManager(
      _$AppDatabase db, $ContentCareItemsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentCareItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentCareItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentCareItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> version = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentCareItemsCompanion(
            id: id,
            version: version,
            json: json,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String version,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentCareItemsCompanion.insert(
            id: id,
            version: version,
            json: json,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContentCareItemsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContentCareItemsTable,
    ContentCareItem,
    $$ContentCareItemsTableFilterComposer,
    $$ContentCareItemsTableOrderingComposer,
    $$ContentCareItemsTableAnnotationComposer,
    $$ContentCareItemsTableCreateCompanionBuilder,
    $$ContentCareItemsTableUpdateCompanionBuilder,
    (
      ContentCareItem,
      BaseReferences<_$AppDatabase, $ContentCareItemsTable, ContentCareItem>
    ),
    ContentCareItem,
    PrefetchHooks Function()>;
typedef $$ContentAiLexiconsTableCreateCompanionBuilder
    = ContentAiLexiconsCompanion Function({
  required String id,
  required String version,
  required String json,
  Value<int> rowid,
});
typedef $$ContentAiLexiconsTableUpdateCompanionBuilder
    = ContentAiLexiconsCompanion Function({
  Value<String> id,
  Value<String> version,
  Value<String> json,
  Value<int> rowid,
});

class $$ContentAiLexiconsTableFilterComposer
    extends Composer<_$AppDatabase, $ContentAiLexiconsTable> {
  $$ContentAiLexiconsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));
}

class $$ContentAiLexiconsTableOrderingComposer
    extends Composer<_$AppDatabase, $ContentAiLexiconsTable> {
  $$ContentAiLexiconsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));
}

class $$ContentAiLexiconsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ContentAiLexiconsTable> {
  $$ContentAiLexiconsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);
}

class $$ContentAiLexiconsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ContentAiLexiconsTable,
    ContentAiLexicon,
    $$ContentAiLexiconsTableFilterComposer,
    $$ContentAiLexiconsTableOrderingComposer,
    $$ContentAiLexiconsTableAnnotationComposer,
    $$ContentAiLexiconsTableCreateCompanionBuilder,
    $$ContentAiLexiconsTableUpdateCompanionBuilder,
    (
      ContentAiLexicon,
      BaseReferences<_$AppDatabase, $ContentAiLexiconsTable, ContentAiLexicon>
    ),
    ContentAiLexicon,
    PrefetchHooks Function()> {
  $$ContentAiLexiconsTableTableManager(
      _$AppDatabase db, $ContentAiLexiconsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ContentAiLexiconsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ContentAiLexiconsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ContentAiLexiconsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> version = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentAiLexiconsCompanion(
            id: id,
            version: version,
            json: json,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String version,
            required String json,
            Value<int> rowid = const Value.absent(),
          }) =>
              ContentAiLexiconsCompanion.insert(
            id: id,
            version: version,
            json: json,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ContentAiLexiconsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ContentAiLexiconsTable,
    ContentAiLexicon,
    $$ContentAiLexiconsTableFilterComposer,
    $$ContentAiLexiconsTableOrderingComposer,
    $$ContentAiLexiconsTableAnnotationComposer,
    $$ContentAiLexiconsTableCreateCompanionBuilder,
    $$ContentAiLexiconsTableUpdateCompanionBuilder,
    (
      ContentAiLexicon,
      BaseReferences<_$AppDatabase, $ContentAiLexiconsTable, ContentAiLexicon>
    ),
    ContentAiLexicon,
    PrefetchHooks Function()>;
typedef $$UsersTableCreateCompanionBuilder = UsersCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String id,
  Value<String?> phoneOrEmail,
  required String nickname,
  Value<String?> avatarUrl,
  required String createdAt,
  Value<int> rowid,
});
typedef $$UsersTableUpdateCompanionBuilder = UsersCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> id,
  Value<String?> phoneOrEmail,
  Value<String> nickname,
  Value<String?> avatarUrl,
  Value<String> createdAt,
  Value<int> rowid,
});

class $$UsersTableFilterComposer extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get phoneOrEmail => $composableBuilder(
      column: $table.phoneOrEmail, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nickname => $composableBuilder(
      column: $table.nickname, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$UsersTableOrderingComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get phoneOrEmail => $composableBuilder(
      column: $table.phoneOrEmail,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nickname => $composableBuilder(
      column: $table.nickname, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarUrl => $composableBuilder(
      column: $table.avatarUrl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$UsersTableAnnotationComposer
    extends Composer<_$AppDatabase, $UsersTable> {
  $$UsersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get phoneOrEmail => $composableBuilder(
      column: $table.phoneOrEmail, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get avatarUrl =>
      $composableBuilder(column: $table.avatarUrl, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UsersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
    User,
    PrefetchHooks Function()> {
  $$UsersTableTableManager(_$AppDatabase db, $UsersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UsersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UsersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UsersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String?> phoneOrEmail = const Value.absent(),
            Value<String> nickname = const Value.absent(),
            Value<String?> avatarUrl = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            phoneOrEmail: phoneOrEmail,
            nickname: nickname,
            avatarUrl: avatarUrl,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String id,
            Value<String?> phoneOrEmail = const Value.absent(),
            required String nickname,
            Value<String?> avatarUrl = const Value.absent(),
            required String createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              UsersCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            phoneOrEmail: phoneOrEmail,
            nickname: nickname,
            avatarUrl: avatarUrl,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UsersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UsersTable,
    User,
    $$UsersTableFilterComposer,
    $$UsersTableOrderingComposer,
    $$UsersTableAnnotationComposer,
    $$UsersTableCreateCompanionBuilder,
    $$UsersTableUpdateCompanionBuilder,
    (User, BaseReferences<_$AppDatabase, $UsersTable, User>),
    User,
    PrefetchHooks Function()>;
typedef $$HouseholdsTableCreateCompanionBuilder = HouseholdsCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String id,
  required String name,
  required String creatorUserId,
  Value<String?> inviteCode,
  required String createdAt,
  Value<int> rowid,
});
typedef $$HouseholdsTableUpdateCompanionBuilder = HouseholdsCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> id,
  Value<String> name,
  Value<String> creatorUserId,
  Value<String?> inviteCode,
  Value<String> createdAt,
  Value<int> rowid,
});

class $$HouseholdsTableFilterComposer
    extends Composer<_$AppDatabase, $HouseholdsTable> {
  $$HouseholdsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get creatorUserId => $composableBuilder(
      column: $table.creatorUserId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get inviteCode => $composableBuilder(
      column: $table.inviteCode, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$HouseholdsTableOrderingComposer
    extends Composer<_$AppDatabase, $HouseholdsTable> {
  $$HouseholdsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get creatorUserId => $composableBuilder(
      column: $table.creatorUserId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get inviteCode => $composableBuilder(
      column: $table.inviteCode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$HouseholdsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HouseholdsTable> {
  $$HouseholdsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get creatorUserId => $composableBuilder(
      column: $table.creatorUserId, builder: (column) => column);

  GeneratedColumn<String> get inviteCode => $composableBuilder(
      column: $table.inviteCode, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$HouseholdsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HouseholdsTable,
    Household,
    $$HouseholdsTableFilterComposer,
    $$HouseholdsTableOrderingComposer,
    $$HouseholdsTableAnnotationComposer,
    $$HouseholdsTableCreateCompanionBuilder,
    $$HouseholdsTableUpdateCompanionBuilder,
    (Household, BaseReferences<_$AppDatabase, $HouseholdsTable, Household>),
    Household,
    PrefetchHooks Function()> {
  $$HouseholdsTableTableManager(_$AppDatabase db, $HouseholdsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HouseholdsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HouseholdsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HouseholdsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> creatorUserId = const Value.absent(),
            Value<String?> inviteCode = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HouseholdsCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            name: name,
            creatorUserId: creatorUserId,
            inviteCode: inviteCode,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String id,
            required String name,
            required String creatorUserId,
            Value<String?> inviteCode = const Value.absent(),
            required String createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              HouseholdsCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            name: name,
            creatorUserId: creatorUserId,
            inviteCode: inviteCode,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HouseholdsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HouseholdsTable,
    Household,
    $$HouseholdsTableFilterComposer,
    $$HouseholdsTableOrderingComposer,
    $$HouseholdsTableAnnotationComposer,
    $$HouseholdsTableCreateCompanionBuilder,
    $$HouseholdsTableUpdateCompanionBuilder,
    (Household, BaseReferences<_$AppDatabase, $HouseholdsTable, Household>),
    Household,
    PrefetchHooks Function()>;
typedef $$HouseholdMembersTableCreateCompanionBuilder
    = HouseholdMembersCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String householdId,
  required String userId,
  required String role,
  required String joinedAt,
  Value<int> rowid,
});
typedef $$HouseholdMembersTableUpdateCompanionBuilder
    = HouseholdMembersCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> householdId,
  Value<String> userId,
  Value<String> role,
  Value<String> joinedAt,
  Value<int> rowid,
});

class $$HouseholdMembersTableFilterComposer
    extends Composer<_$AppDatabase, $HouseholdMembersTable> {
  $$HouseholdMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get joinedAt => $composableBuilder(
      column: $table.joinedAt, builder: (column) => ColumnFilters(column));
}

class $$HouseholdMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $HouseholdMembersTable> {
  $$HouseholdMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get joinedAt => $composableBuilder(
      column: $table.joinedAt, builder: (column) => ColumnOrderings(column));
}

class $$HouseholdMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $HouseholdMembersTable> {
  $$HouseholdMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get joinedAt =>
      $composableBuilder(column: $table.joinedAt, builder: (column) => column);
}

class $$HouseholdMembersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HouseholdMembersTable,
    HouseholdMember,
    $$HouseholdMembersTableFilterComposer,
    $$HouseholdMembersTableOrderingComposer,
    $$HouseholdMembersTableAnnotationComposer,
    $$HouseholdMembersTableCreateCompanionBuilder,
    $$HouseholdMembersTableUpdateCompanionBuilder,
    (
      HouseholdMember,
      BaseReferences<_$AppDatabase, $HouseholdMembersTable, HouseholdMember>
    ),
    HouseholdMember,
    PrefetchHooks Function()> {
  $$HouseholdMembersTableTableManager(
      _$AppDatabase db, $HouseholdMembersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HouseholdMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HouseholdMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HouseholdMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> householdId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> joinedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HouseholdMembersCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            householdId: householdId,
            userId: userId,
            role: role,
            joinedAt: joinedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String householdId,
            required String userId,
            required String role,
            required String joinedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              HouseholdMembersCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            householdId: householdId,
            userId: userId,
            role: role,
            joinedAt: joinedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HouseholdMembersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HouseholdMembersTable,
    HouseholdMember,
    $$HouseholdMembersTableFilterComposer,
    $$HouseholdMembersTableOrderingComposer,
    $$HouseholdMembersTableAnnotationComposer,
    $$HouseholdMembersTableCreateCompanionBuilder,
    $$HouseholdMembersTableUpdateCompanionBuilder,
    (
      HouseholdMember,
      BaseReferences<_$AppDatabase, $HouseholdMembersTable, HouseholdMember>
    ),
    HouseholdMember,
    PrefetchHooks Function()>;
typedef $$DogsTableCreateCompanionBuilder = DogsCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String id,
  required String householdId,
  required String name,
  required String birthDate,
  required String breedId,
  required String breedText,
  required String sex,
  required String homeDate,
  required String livingEnv,
  required int dailyMinutes,
  required int trainerCount,
  required String createdAt,
  required String updatedAt,
  Value<String> initialMastered,
  Value<int> rowid,
});
typedef $$DogsTableUpdateCompanionBuilder = DogsCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> id,
  Value<String> householdId,
  Value<String> name,
  Value<String> birthDate,
  Value<String> breedId,
  Value<String> breedText,
  Value<String> sex,
  Value<String> homeDate,
  Value<String> livingEnv,
  Value<int> dailyMinutes,
  Value<int> trainerCount,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<String> initialMastered,
  Value<int> rowid,
});

class $$DogsTableFilterComposer extends Composer<_$AppDatabase, $DogsTable> {
  $$DogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get birthDate => $composableBuilder(
      column: $table.birthDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get breedId => $composableBuilder(
      column: $table.breedId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get breedText => $composableBuilder(
      column: $table.breedText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sex => $composableBuilder(
      column: $table.sex, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get homeDate => $composableBuilder(
      column: $table.homeDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get livingEnv => $composableBuilder(
      column: $table.livingEnv, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyMinutes => $composableBuilder(
      column: $table.dailyMinutes, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get trainerCount => $composableBuilder(
      column: $table.trainerCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get initialMastered => $composableBuilder(
      column: $table.initialMastered,
      builder: (column) => ColumnFilters(column));
}

class $$DogsTableOrderingComposer extends Composer<_$AppDatabase, $DogsTable> {
  $$DogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get birthDate => $composableBuilder(
      column: $table.birthDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get breedId => $composableBuilder(
      column: $table.breedId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get breedText => $composableBuilder(
      column: $table.breedText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sex => $composableBuilder(
      column: $table.sex, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get homeDate => $composableBuilder(
      column: $table.homeDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get livingEnv => $composableBuilder(
      column: $table.livingEnv, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dailyMinutes => $composableBuilder(
      column: $table.dailyMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get trainerCount => $composableBuilder(
      column: $table.trainerCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get initialMastered => $composableBuilder(
      column: $table.initialMastered,
      builder: (column) => ColumnOrderings(column));
}

class $$DogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DogsTable> {
  $$DogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<String> get breedId =>
      $composableBuilder(column: $table.breedId, builder: (column) => column);

  GeneratedColumn<String> get breedText =>
      $composableBuilder(column: $table.breedText, builder: (column) => column);

  GeneratedColumn<String> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<String> get homeDate =>
      $composableBuilder(column: $table.homeDate, builder: (column) => column);

  GeneratedColumn<String> get livingEnv =>
      $composableBuilder(column: $table.livingEnv, builder: (column) => column);

  GeneratedColumn<int> get dailyMinutes => $composableBuilder(
      column: $table.dailyMinutes, builder: (column) => column);

  GeneratedColumn<int> get trainerCount => $composableBuilder(
      column: $table.trainerCount, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get initialMastered => $composableBuilder(
      column: $table.initialMastered, builder: (column) => column);
}

class $$DogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DogsTable,
    Dog,
    $$DogsTableFilterComposer,
    $$DogsTableOrderingComposer,
    $$DogsTableAnnotationComposer,
    $$DogsTableCreateCompanionBuilder,
    $$DogsTableUpdateCompanionBuilder,
    (Dog, BaseReferences<_$AppDatabase, $DogsTable, Dog>),
    Dog,
    PrefetchHooks Function()> {
  $$DogsTableTableManager(_$AppDatabase db, $DogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> householdId = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> birthDate = const Value.absent(),
            Value<String> breedId = const Value.absent(),
            Value<String> breedText = const Value.absent(),
            Value<String> sex = const Value.absent(),
            Value<String> homeDate = const Value.absent(),
            Value<String> livingEnv = const Value.absent(),
            Value<int> dailyMinutes = const Value.absent(),
            Value<int> trainerCount = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<String> initialMastered = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DogsCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            householdId: householdId,
            name: name,
            birthDate: birthDate,
            breedId: breedId,
            breedText: breedText,
            sex: sex,
            homeDate: homeDate,
            livingEnv: livingEnv,
            dailyMinutes: dailyMinutes,
            trainerCount: trainerCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            initialMastered: initialMastered,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String id,
            required String householdId,
            required String name,
            required String birthDate,
            required String breedId,
            required String breedText,
            required String sex,
            required String homeDate,
            required String livingEnv,
            required int dailyMinutes,
            required int trainerCount,
            required String createdAt,
            required String updatedAt,
            Value<String> initialMastered = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DogsCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            householdId: householdId,
            name: name,
            birthDate: birthDate,
            breedId: breedId,
            breedText: breedText,
            sex: sex,
            homeDate: homeDate,
            livingEnv: livingEnv,
            dailyMinutes: dailyMinutes,
            trainerCount: trainerCount,
            createdAt: createdAt,
            updatedAt: updatedAt,
            initialMastered: initialMastered,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DogsTable,
    Dog,
    $$DogsTableFilterComposer,
    $$DogsTableOrderingComposer,
    $$DogsTableAnnotationComposer,
    $$DogsTableCreateCompanionBuilder,
    $$DogsTableUpdateCompanionBuilder,
    (Dog, BaseReferences<_$AppDatabase, $DogsTable, Dog>),
    Dog,
    PrefetchHooks Function()>;
typedef $$DogConcernsTableCreateCompanionBuilder = DogConcernsCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String dogId,
  required String issueId,
  required String createdAt,
  Value<int> rowid,
});
typedef $$DogConcernsTableUpdateCompanionBuilder = DogConcernsCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> dogId,
  Value<String> issueId,
  Value<String> createdAt,
  Value<int> rowid,
});

class $$DogConcernsTableFilterComposer
    extends Composer<_$AppDatabase, $DogConcernsTable> {
  $$DogConcernsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get issueId => $composableBuilder(
      column: $table.issueId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$DogConcernsTableOrderingComposer
    extends Composer<_$AppDatabase, $DogConcernsTable> {
  $$DogConcernsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get issueId => $composableBuilder(
      column: $table.issueId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$DogConcernsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DogConcernsTable> {
  $$DogConcernsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get issueId =>
      $composableBuilder(column: $table.issueId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DogConcernsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DogConcernsTable,
    DogConcern,
    $$DogConcernsTableFilterComposer,
    $$DogConcernsTableOrderingComposer,
    $$DogConcernsTableAnnotationComposer,
    $$DogConcernsTableCreateCompanionBuilder,
    $$DogConcernsTableUpdateCompanionBuilder,
    (DogConcern, BaseReferences<_$AppDatabase, $DogConcernsTable, DogConcern>),
    DogConcern,
    PrefetchHooks Function()> {
  $$DogConcernsTableTableManager(_$AppDatabase db, $DogConcernsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DogConcernsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DogConcernsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DogConcernsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> dogId = const Value.absent(),
            Value<String> issueId = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DogConcernsCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            dogId: dogId,
            issueId: issueId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String dogId,
            required String issueId,
            required String createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DogConcernsCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            dogId: dogId,
            issueId: issueId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DogConcernsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DogConcernsTable,
    DogConcern,
    $$DogConcernsTableFilterComposer,
    $$DogConcernsTableOrderingComposer,
    $$DogConcernsTableAnnotationComposer,
    $$DogConcernsTableCreateCompanionBuilder,
    $$DogConcernsTableUpdateCompanionBuilder,
    (DogConcern, BaseReferences<_$AppDatabase, $DogConcernsTable, DogConcern>),
    DogConcern,
    PrefetchHooks Function()>;
typedef $$DogCuesTableCreateCompanionBuilder = DogCuesCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String dogId,
  required String skillId,
  required String cueWord,
  required String gestureText,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$DogCuesTableUpdateCompanionBuilder = DogCuesCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> dogId,
  Value<String> skillId,
  Value<String> cueWord,
  Value<String> gestureText,
  Value<String> updatedAt,
  Value<int> rowid,
});

class $$DogCuesTableFilterComposer
    extends Composer<_$AppDatabase, $DogCuesTable> {
  $$DogCuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get cueWord => $composableBuilder(
      column: $table.cueWord, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get gestureText => $composableBuilder(
      column: $table.gestureText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$DogCuesTableOrderingComposer
    extends Composer<_$AppDatabase, $DogCuesTable> {
  $$DogCuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get cueWord => $composableBuilder(
      column: $table.cueWord, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get gestureText => $composableBuilder(
      column: $table.gestureText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$DogCuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DogCuesTable> {
  $$DogCuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<String> get cueWord =>
      $composableBuilder(column: $table.cueWord, builder: (column) => column);

  GeneratedColumn<String> get gestureText => $composableBuilder(
      column: $table.gestureText, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DogCuesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DogCuesTable,
    DogCue,
    $$DogCuesTableFilterComposer,
    $$DogCuesTableOrderingComposer,
    $$DogCuesTableAnnotationComposer,
    $$DogCuesTableCreateCompanionBuilder,
    $$DogCuesTableUpdateCompanionBuilder,
    (DogCue, BaseReferences<_$AppDatabase, $DogCuesTable, DogCue>),
    DogCue,
    PrefetchHooks Function()> {
  $$DogCuesTableTableManager(_$AppDatabase db, $DogCuesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DogCuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DogCuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DogCuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> dogId = const Value.absent(),
            Value<String> skillId = const Value.absent(),
            Value<String> cueWord = const Value.absent(),
            Value<String> gestureText = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DogCuesCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            dogId: dogId,
            skillId: skillId,
            cueWord: cueWord,
            gestureText: gestureText,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String dogId,
            required String skillId,
            required String cueWord,
            required String gestureText,
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DogCuesCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            dogId: dogId,
            skillId: skillId,
            cueWord: cueWord,
            gestureText: gestureText,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DogCuesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DogCuesTable,
    DogCue,
    $$DogCuesTableFilterComposer,
    $$DogCuesTableOrderingComposer,
    $$DogCuesTableAnnotationComposer,
    $$DogCuesTableCreateCompanionBuilder,
    $$DogCuesTableUpdateCompanionBuilder,
    (DogCue, BaseReferences<_$AppDatabase, $DogCuesTable, DogCue>),
    DogCue,
    PrefetchHooks Function()>;
typedef $$DogSkillStatusesTableCreateCompanionBuilder
    = DogSkillStatusesCompanion Function({
  required String dogId,
  required String skillId,
  required String status,
  Value<String?> masteredAt,
  Value<int> fullSuccessCount,
  Value<int> failCount,
  Value<int> rowid,
});
typedef $$DogSkillStatusesTableUpdateCompanionBuilder
    = DogSkillStatusesCompanion Function({
  Value<String> dogId,
  Value<String> skillId,
  Value<String> status,
  Value<String?> masteredAt,
  Value<int> fullSuccessCount,
  Value<int> failCount,
  Value<int> rowid,
});

class $$DogSkillStatusesTableFilterComposer
    extends Composer<_$AppDatabase, $DogSkillStatusesTable> {
  $$DogSkillStatusesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get masteredAt => $composableBuilder(
      column: $table.masteredAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fullSuccessCount => $composableBuilder(
      column: $table.fullSuccessCount,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get failCount => $composableBuilder(
      column: $table.failCount, builder: (column) => ColumnFilters(column));
}

class $$DogSkillStatusesTableOrderingComposer
    extends Composer<_$AppDatabase, $DogSkillStatusesTable> {
  $$DogSkillStatusesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get masteredAt => $composableBuilder(
      column: $table.masteredAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fullSuccessCount => $composableBuilder(
      column: $table.fullSuccessCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get failCount => $composableBuilder(
      column: $table.failCount, builder: (column) => ColumnOrderings(column));
}

class $$DogSkillStatusesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DogSkillStatusesTable> {
  $$DogSkillStatusesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get masteredAt => $composableBuilder(
      column: $table.masteredAt, builder: (column) => column);

  GeneratedColumn<int> get fullSuccessCount => $composableBuilder(
      column: $table.fullSuccessCount, builder: (column) => column);

  GeneratedColumn<int> get failCount =>
      $composableBuilder(column: $table.failCount, builder: (column) => column);
}

class $$DogSkillStatusesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DogSkillStatusesTable,
    DogSkillStatuse,
    $$DogSkillStatusesTableFilterComposer,
    $$DogSkillStatusesTableOrderingComposer,
    $$DogSkillStatusesTableAnnotationComposer,
    $$DogSkillStatusesTableCreateCompanionBuilder,
    $$DogSkillStatusesTableUpdateCompanionBuilder,
    (
      DogSkillStatuse,
      BaseReferences<_$AppDatabase, $DogSkillStatusesTable, DogSkillStatuse>
    ),
    DogSkillStatuse,
    PrefetchHooks Function()> {
  $$DogSkillStatusesTableTableManager(
      _$AppDatabase db, $DogSkillStatusesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DogSkillStatusesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DogSkillStatusesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DogSkillStatusesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> dogId = const Value.absent(),
            Value<String> skillId = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String?> masteredAt = const Value.absent(),
            Value<int> fullSuccessCount = const Value.absent(),
            Value<int> failCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DogSkillStatusesCompanion(
            dogId: dogId,
            skillId: skillId,
            status: status,
            masteredAt: masteredAt,
            fullSuccessCount: fullSuccessCount,
            failCount: failCount,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String dogId,
            required String skillId,
            required String status,
            Value<String?> masteredAt = const Value.absent(),
            Value<int> fullSuccessCount = const Value.absent(),
            Value<int> failCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DogSkillStatusesCompanion.insert(
            dogId: dogId,
            skillId: skillId,
            status: status,
            masteredAt: masteredAt,
            fullSuccessCount: fullSuccessCount,
            failCount: failCount,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DogSkillStatusesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DogSkillStatusesTable,
    DogSkillStatuse,
    $$DogSkillStatusesTableFilterComposer,
    $$DogSkillStatusesTableOrderingComposer,
    $$DogSkillStatusesTableAnnotationComposer,
    $$DogSkillStatusesTableCreateCompanionBuilder,
    $$DogSkillStatusesTableUpdateCompanionBuilder,
    (
      DogSkillStatuse,
      BaseReferences<_$AppDatabase, $DogSkillStatusesTable, DogSkillStatuse>
    ),
    DogSkillStatuse,
    PrefetchHooks Function()>;
typedef $$WeeklyPlansTableCreateCompanionBuilder = WeeklyPlansCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String id,
  required String dogId,
  required String weekStart,
  required String generatedBy,
  required String status,
  required String createdAt,
  Value<bool> regenerateNext,
  Value<String> pendingDiagnosisSkills,
  Value<int> rowid,
});
typedef $$WeeklyPlansTableUpdateCompanionBuilder = WeeklyPlansCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> id,
  Value<String> dogId,
  Value<String> weekStart,
  Value<String> generatedBy,
  Value<String> status,
  Value<String> createdAt,
  Value<bool> regenerateNext,
  Value<String> pendingDiagnosisSkills,
  Value<int> rowid,
});

class $$WeeklyPlansTableFilterComposer
    extends Composer<_$AppDatabase, $WeeklyPlansTable> {
  $$WeeklyPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get weekStart => $composableBuilder(
      column: $table.weekStart, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get generatedBy => $composableBuilder(
      column: $table.generatedBy, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get regenerateNext => $composableBuilder(
      column: $table.regenerateNext,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pendingDiagnosisSkills => $composableBuilder(
      column: $table.pendingDiagnosisSkills,
      builder: (column) => ColumnFilters(column));
}

class $$WeeklyPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $WeeklyPlansTable> {
  $$WeeklyPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get weekStart => $composableBuilder(
      column: $table.weekStart, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get generatedBy => $composableBuilder(
      column: $table.generatedBy, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get regenerateNext => $composableBuilder(
      column: $table.regenerateNext,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pendingDiagnosisSkills => $composableBuilder(
      column: $table.pendingDiagnosisSkills,
      builder: (column) => ColumnOrderings(column));
}

class $$WeeklyPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeeklyPlansTable> {
  $$WeeklyPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get weekStart =>
      $composableBuilder(column: $table.weekStart, builder: (column) => column);

  GeneratedColumn<String> get generatedBy => $composableBuilder(
      column: $table.generatedBy, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<bool> get regenerateNext => $composableBuilder(
      column: $table.regenerateNext, builder: (column) => column);

  GeneratedColumn<String> get pendingDiagnosisSkills => $composableBuilder(
      column: $table.pendingDiagnosisSkills, builder: (column) => column);
}

class $$WeeklyPlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WeeklyPlansTable,
    WeeklyPlan,
    $$WeeklyPlansTableFilterComposer,
    $$WeeklyPlansTableOrderingComposer,
    $$WeeklyPlansTableAnnotationComposer,
    $$WeeklyPlansTableCreateCompanionBuilder,
    $$WeeklyPlansTableUpdateCompanionBuilder,
    (WeeklyPlan, BaseReferences<_$AppDatabase, $WeeklyPlansTable, WeeklyPlan>),
    WeeklyPlan,
    PrefetchHooks Function()> {
  $$WeeklyPlansTableTableManager(_$AppDatabase db, $WeeklyPlansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklyPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklyPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklyPlansTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> dogId = const Value.absent(),
            Value<String> weekStart = const Value.absent(),
            Value<String> generatedBy = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<bool> regenerateNext = const Value.absent(),
            Value<String> pendingDiagnosisSkills = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WeeklyPlansCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            dogId: dogId,
            weekStart: weekStart,
            generatedBy: generatedBy,
            status: status,
            createdAt: createdAt,
            regenerateNext: regenerateNext,
            pendingDiagnosisSkills: pendingDiagnosisSkills,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String id,
            required String dogId,
            required String weekStart,
            required String generatedBy,
            required String status,
            required String createdAt,
            Value<bool> regenerateNext = const Value.absent(),
            Value<String> pendingDiagnosisSkills = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WeeklyPlansCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            dogId: dogId,
            weekStart: weekStart,
            generatedBy: generatedBy,
            status: status,
            createdAt: createdAt,
            regenerateNext: regenerateNext,
            pendingDiagnosisSkills: pendingDiagnosisSkills,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WeeklyPlansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WeeklyPlansTable,
    WeeklyPlan,
    $$WeeklyPlansTableFilterComposer,
    $$WeeklyPlansTableOrderingComposer,
    $$WeeklyPlansTableAnnotationComposer,
    $$WeeklyPlansTableCreateCompanionBuilder,
    $$WeeklyPlansTableUpdateCompanionBuilder,
    (WeeklyPlan, BaseReferences<_$AppDatabase, $WeeklyPlansTable, WeeklyPlan>),
    WeeklyPlan,
    PrefetchHooks Function()>;
typedef $$PlanGoalsTableCreateCompanionBuilder = PlanGoalsCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String planId,
  required String skillId,
  required int position,
  required int targetSessions,
  Value<int> completedSessions,
  required String source,
  Value<int> rowid,
});
typedef $$PlanGoalsTableUpdateCompanionBuilder = PlanGoalsCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> planId,
  Value<String> skillId,
  Value<int> position,
  Value<int> targetSessions,
  Value<int> completedSessions,
  Value<String> source,
  Value<int> rowid,
});

class $$PlanGoalsTableFilterComposer
    extends Composer<_$AppDatabase, $PlanGoalsTable> {
  $$PlanGoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get targetSessions => $composableBuilder(
      column: $table.targetSessions,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completedSessions => $composableBuilder(
      column: $table.completedSessions,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));
}

class $$PlanGoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $PlanGoalsTable> {
  $$PlanGoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get targetSessions => $composableBuilder(
      column: $table.targetSessions,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completedSessions => $composableBuilder(
      column: $table.completedSessions,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));
}

class $$PlanGoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PlanGoalsTable> {
  $$PlanGoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<int> get targetSessions => $composableBuilder(
      column: $table.targetSessions, builder: (column) => column);

  GeneratedColumn<int> get completedSessions => $composableBuilder(
      column: $table.completedSessions, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$PlanGoalsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PlanGoalsTable,
    PlanGoal,
    $$PlanGoalsTableFilterComposer,
    $$PlanGoalsTableOrderingComposer,
    $$PlanGoalsTableAnnotationComposer,
    $$PlanGoalsTableCreateCompanionBuilder,
    $$PlanGoalsTableUpdateCompanionBuilder,
    (PlanGoal, BaseReferences<_$AppDatabase, $PlanGoalsTable, PlanGoal>),
    PlanGoal,
    PrefetchHooks Function()> {
  $$PlanGoalsTableTableManager(_$AppDatabase db, $PlanGoalsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlanGoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlanGoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlanGoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> planId = const Value.absent(),
            Value<String> skillId = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<int> targetSessions = const Value.absent(),
            Value<int> completedSessions = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PlanGoalsCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            planId: planId,
            skillId: skillId,
            position: position,
            targetSessions: targetSessions,
            completedSessions: completedSessions,
            source: source,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String planId,
            required String skillId,
            required int position,
            required int targetSessions,
            Value<int> completedSessions = const Value.absent(),
            required String source,
            Value<int> rowid = const Value.absent(),
          }) =>
              PlanGoalsCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            planId: planId,
            skillId: skillId,
            position: position,
            targetSessions: targetSessions,
            completedSessions: completedSessions,
            source: source,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PlanGoalsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PlanGoalsTable,
    PlanGoal,
    $$PlanGoalsTableFilterComposer,
    $$PlanGoalsTableOrderingComposer,
    $$PlanGoalsTableAnnotationComposer,
    $$PlanGoalsTableCreateCompanionBuilder,
    $$PlanGoalsTableUpdateCompanionBuilder,
    (PlanGoal, BaseReferences<_$AppDatabase, $PlanGoalsTable, PlanGoal>),
    PlanGoal,
    PrefetchHooks Function()>;
typedef $$DailyMiniTasksTableCreateCompanionBuilder = DailyMiniTasksCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String planId,
  required String skillId,
  required int scriptPart,
  Value<int> rowid,
});
typedef $$DailyMiniTasksTableUpdateCompanionBuilder = DailyMiniTasksCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> planId,
  Value<String> skillId,
  Value<int> scriptPart,
  Value<int> rowid,
});

class $$DailyMiniTasksTableFilterComposer
    extends Composer<_$AppDatabase, $DailyMiniTasksTable> {
  $$DailyMiniTasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get scriptPart => $composableBuilder(
      column: $table.scriptPart, builder: (column) => ColumnFilters(column));
}

class $$DailyMiniTasksTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyMiniTasksTable> {
  $$DailyMiniTasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scriptPart => $composableBuilder(
      column: $table.scriptPart, builder: (column) => ColumnOrderings(column));
}

class $$DailyMiniTasksTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyMiniTasksTable> {
  $$DailyMiniTasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get scriptPart => $composableBuilder(
      column: $table.scriptPart, builder: (column) => column);
}

class $$DailyMiniTasksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DailyMiniTasksTable,
    DailyMiniTask,
    $$DailyMiniTasksTableFilterComposer,
    $$DailyMiniTasksTableOrderingComposer,
    $$DailyMiniTasksTableAnnotationComposer,
    $$DailyMiniTasksTableCreateCompanionBuilder,
    $$DailyMiniTasksTableUpdateCompanionBuilder,
    (
      DailyMiniTask,
      BaseReferences<_$AppDatabase, $DailyMiniTasksTable, DailyMiniTask>
    ),
    DailyMiniTask,
    PrefetchHooks Function()> {
  $$DailyMiniTasksTableTableManager(
      _$AppDatabase db, $DailyMiniTasksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyMiniTasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyMiniTasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyMiniTasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> planId = const Value.absent(),
            Value<String> skillId = const Value.absent(),
            Value<int> scriptPart = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DailyMiniTasksCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            planId: planId,
            skillId: skillId,
            scriptPart: scriptPart,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String planId,
            required String skillId,
            required int scriptPart,
            Value<int> rowid = const Value.absent(),
          }) =>
              DailyMiniTasksCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            planId: planId,
            skillId: skillId,
            scriptPart: scriptPart,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DailyMiniTasksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DailyMiniTasksTable,
    DailyMiniTask,
    $$DailyMiniTasksTableFilterComposer,
    $$DailyMiniTasksTableOrderingComposer,
    $$DailyMiniTasksTableAnnotationComposer,
    $$DailyMiniTasksTableCreateCompanionBuilder,
    $$DailyMiniTasksTableUpdateCompanionBuilder,
    (
      DailyMiniTask,
      BaseReferences<_$AppDatabase, $DailyMiniTasksTable, DailyMiniTask>
    ),
    DailyMiniTask,
    PrefetchHooks Function()>;
typedef $$OnboardingDraftsTableCreateCompanionBuilder
    = OnboardingDraftsCompanion Function({
  Value<int> id,
  required String json,
  required String updatedAt,
});
typedef $$OnboardingDraftsTableUpdateCompanionBuilder
    = OnboardingDraftsCompanion Function({
  Value<int> id,
  Value<String> json,
  Value<String> updatedAt,
});

class $$OnboardingDraftsTableFilterComposer
    extends Composer<_$AppDatabase, $OnboardingDraftsTable> {
  $$OnboardingDraftsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$OnboardingDraftsTableOrderingComposer
    extends Composer<_$AppDatabase, $OnboardingDraftsTable> {
  $$OnboardingDraftsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$OnboardingDraftsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OnboardingDraftsTable> {
  $$OnboardingDraftsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OnboardingDraftsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OnboardingDraftsTable,
    OnboardingDraft,
    $$OnboardingDraftsTableFilterComposer,
    $$OnboardingDraftsTableOrderingComposer,
    $$OnboardingDraftsTableAnnotationComposer,
    $$OnboardingDraftsTableCreateCompanionBuilder,
    $$OnboardingDraftsTableUpdateCompanionBuilder,
    (
      OnboardingDraft,
      BaseReferences<_$AppDatabase, $OnboardingDraftsTable, OnboardingDraft>
    ),
    OnboardingDraft,
    PrefetchHooks Function()> {
  $$OnboardingDraftsTableTableManager(
      _$AppDatabase db, $OnboardingDraftsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OnboardingDraftsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OnboardingDraftsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OnboardingDraftsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
          }) =>
              OnboardingDraftsCompanion(
            id: id,
            json: json,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String json,
            required String updatedAt,
          }) =>
              OnboardingDraftsCompanion.insert(
            id: id,
            json: json,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OnboardingDraftsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OnboardingDraftsTable,
    OnboardingDraft,
    $$OnboardingDraftsTableFilterComposer,
    $$OnboardingDraftsTableOrderingComposer,
    $$OnboardingDraftsTableAnnotationComposer,
    $$OnboardingDraftsTableCreateCompanionBuilder,
    $$OnboardingDraftsTableUpdateCompanionBuilder,
    (
      OnboardingDraft,
      BaseReferences<_$AppDatabase, $OnboardingDraftsTable, OnboardingDraft>
    ),
    OnboardingDraft,
    PrefetchHooks Function()>;
typedef $$TrainingSessionsTableCreateCompanionBuilder
    = TrainingSessionsCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String id,
  required String dogId,
  required String userId,
  required String skillId,
  required int scriptPart,
  required String startedAt,
  required String endedAt,
  required int durationSec,
  required String score,
  Value<String?> noteText,
  Value<String?> noteVideoUrl,
  Value<String> skippedSteps,
  Value<int> clickerCount,
  Value<String?> syncedAt,
  Value<int> rowid,
});
typedef $$TrainingSessionsTableUpdateCompanionBuilder
    = TrainingSessionsCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> id,
  Value<String> dogId,
  Value<String> userId,
  Value<String> skillId,
  Value<int> scriptPart,
  Value<String> startedAt,
  Value<String> endedAt,
  Value<int> durationSec,
  Value<String> score,
  Value<String?> noteText,
  Value<String?> noteVideoUrl,
  Value<String> skippedSteps,
  Value<int> clickerCount,
  Value<String?> syncedAt,
  Value<int> rowid,
});

class $$TrainingSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $TrainingSessionsTable> {
  $$TrainingSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get scriptPart => $composableBuilder(
      column: $table.scriptPart, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get noteText => $composableBuilder(
      column: $table.noteText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get noteVideoUrl => $composableBuilder(
      column: $table.noteVideoUrl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get skippedSteps => $composableBuilder(
      column: $table.skippedSteps, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get clickerCount => $composableBuilder(
      column: $table.clickerCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));
}

class $$TrainingSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $TrainingSessionsTable> {
  $$TrainingSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get scriptPart => $composableBuilder(
      column: $table.scriptPart, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get score => $composableBuilder(
      column: $table.score, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get noteText => $composableBuilder(
      column: $table.noteText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get noteVideoUrl => $composableBuilder(
      column: $table.noteVideoUrl,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get skippedSteps => $composableBuilder(
      column: $table.skippedSteps,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get clickerCount => $composableBuilder(
      column: $table.clickerCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));
}

class $$TrainingSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TrainingSessionsTable> {
  $$TrainingSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<int> get scriptPart => $composableBuilder(
      column: $table.scriptPart, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => column);

  GeneratedColumn<String> get score =>
      $composableBuilder(column: $table.score, builder: (column) => column);

  GeneratedColumn<String> get noteText =>
      $composableBuilder(column: $table.noteText, builder: (column) => column);

  GeneratedColumn<String> get noteVideoUrl => $composableBuilder(
      column: $table.noteVideoUrl, builder: (column) => column);

  GeneratedColumn<String> get skippedSteps => $composableBuilder(
      column: $table.skippedSteps, builder: (column) => column);

  GeneratedColumn<int> get clickerCount => $composableBuilder(
      column: $table.clickerCount, builder: (column) => column);

  GeneratedColumn<String> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);
}

class $$TrainingSessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $TrainingSessionsTable,
    TrainingSession,
    $$TrainingSessionsTableFilterComposer,
    $$TrainingSessionsTableOrderingComposer,
    $$TrainingSessionsTableAnnotationComposer,
    $$TrainingSessionsTableCreateCompanionBuilder,
    $$TrainingSessionsTableUpdateCompanionBuilder,
    (
      TrainingSession,
      BaseReferences<_$AppDatabase, $TrainingSessionsTable, TrainingSession>
    ),
    TrainingSession,
    PrefetchHooks Function()> {
  $$TrainingSessionsTableTableManager(
      _$AppDatabase db, $TrainingSessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrainingSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrainingSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrainingSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> dogId = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> skillId = const Value.absent(),
            Value<int> scriptPart = const Value.absent(),
            Value<String> startedAt = const Value.absent(),
            Value<String> endedAt = const Value.absent(),
            Value<int> durationSec = const Value.absent(),
            Value<String> score = const Value.absent(),
            Value<String?> noteText = const Value.absent(),
            Value<String?> noteVideoUrl = const Value.absent(),
            Value<String> skippedSteps = const Value.absent(),
            Value<int> clickerCount = const Value.absent(),
            Value<String?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrainingSessionsCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            dogId: dogId,
            userId: userId,
            skillId: skillId,
            scriptPart: scriptPart,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSec: durationSec,
            score: score,
            noteText: noteText,
            noteVideoUrl: noteVideoUrl,
            skippedSteps: skippedSteps,
            clickerCount: clickerCount,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String id,
            required String dogId,
            required String userId,
            required String skillId,
            required int scriptPart,
            required String startedAt,
            required String endedAt,
            required int durationSec,
            required String score,
            Value<String?> noteText = const Value.absent(),
            Value<String?> noteVideoUrl = const Value.absent(),
            Value<String> skippedSteps = const Value.absent(),
            Value<int> clickerCount = const Value.absent(),
            Value<String?> syncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrainingSessionsCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            dogId: dogId,
            userId: userId,
            skillId: skillId,
            scriptPart: scriptPart,
            startedAt: startedAt,
            endedAt: endedAt,
            durationSec: durationSec,
            score: score,
            noteText: noteText,
            noteVideoUrl: noteVideoUrl,
            skippedSteps: skippedSteps,
            clickerCount: clickerCount,
            syncedAt: syncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TrainingSessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $TrainingSessionsTable,
    TrainingSession,
    $$TrainingSessionsTableFilterComposer,
    $$TrainingSessionsTableOrderingComposer,
    $$TrainingSessionsTableAnnotationComposer,
    $$TrainingSessionsTableCreateCompanionBuilder,
    $$TrainingSessionsTableUpdateCompanionBuilder,
    (
      TrainingSession,
      BaseReferences<_$AppDatabase, $TrainingSessionsTable, TrainingSession>
    ),
    TrainingSession,
    PrefetchHooks Function()>;
typedef $$StreaksTableCreateCompanionBuilder = StreaksCompanion Function({
  required String dogId,
  Value<int> currentDays,
  Value<int> longestDays,
  Value<String?> lastCheckinDate,
  Value<int> rowid,
});
typedef $$StreaksTableUpdateCompanionBuilder = StreaksCompanion Function({
  Value<String> dogId,
  Value<int> currentDays,
  Value<int> longestDays,
  Value<String?> lastCheckinDate,
  Value<int> rowid,
});

class $$StreaksTableFilterComposer
    extends Composer<_$AppDatabase, $StreaksTable> {
  $$StreaksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentDays => $composableBuilder(
      column: $table.currentDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get longestDays => $composableBuilder(
      column: $table.longestDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastCheckinDate => $composableBuilder(
      column: $table.lastCheckinDate,
      builder: (column) => ColumnFilters(column));
}

class $$StreaksTableOrderingComposer
    extends Composer<_$AppDatabase, $StreaksTable> {
  $$StreaksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentDays => $composableBuilder(
      column: $table.currentDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get longestDays => $composableBuilder(
      column: $table.longestDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastCheckinDate => $composableBuilder(
      column: $table.lastCheckinDate,
      builder: (column) => ColumnOrderings(column));
}

class $$StreaksTableAnnotationComposer
    extends Composer<_$AppDatabase, $StreaksTable> {
  $$StreaksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<int> get currentDays => $composableBuilder(
      column: $table.currentDays, builder: (column) => column);

  GeneratedColumn<int> get longestDays => $composableBuilder(
      column: $table.longestDays, builder: (column) => column);

  GeneratedColumn<String> get lastCheckinDate => $composableBuilder(
      column: $table.lastCheckinDate, builder: (column) => column);
}

class $$StreaksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StreaksTable,
    Streak,
    $$StreaksTableFilterComposer,
    $$StreaksTableOrderingComposer,
    $$StreaksTableAnnotationComposer,
    $$StreaksTableCreateCompanionBuilder,
    $$StreaksTableUpdateCompanionBuilder,
    (Streak, BaseReferences<_$AppDatabase, $StreaksTable, Streak>),
    Streak,
    PrefetchHooks Function()> {
  $$StreaksTableTableManager(_$AppDatabase db, $StreaksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreaksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreaksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreaksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> dogId = const Value.absent(),
            Value<int> currentDays = const Value.absent(),
            Value<int> longestDays = const Value.absent(),
            Value<String?> lastCheckinDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StreaksCompanion(
            dogId: dogId,
            currentDays: currentDays,
            longestDays: longestDays,
            lastCheckinDate: lastCheckinDate,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String dogId,
            Value<int> currentDays = const Value.absent(),
            Value<int> longestDays = const Value.absent(),
            Value<String?> lastCheckinDate = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StreaksCompanion.insert(
            dogId: dogId,
            currentDays: currentDays,
            longestDays: longestDays,
            lastCheckinDate: lastCheckinDate,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StreaksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StreaksTable,
    Streak,
    $$StreaksTableFilterComposer,
    $$StreaksTableOrderingComposer,
    $$StreaksTableAnnotationComposer,
    $$StreaksTableCreateCompanionBuilder,
    $$StreaksTableUpdateCompanionBuilder,
    (Streak, BaseReferences<_$AppDatabase, $StreaksTable, Streak>),
    Streak,
    PrefetchHooks Function()>;
typedef $$WeeklyReportsTableCreateCompanionBuilder = WeeklyReportsCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String id,
  required String dogId,
  required String planId,
  required String summaryJson,
  required String aiComment,
  Value<String?> nextPlanId,
  required String createdAt,
  Value<String?> readAt,
  Value<int> rowid,
});
typedef $$WeeklyReportsTableUpdateCompanionBuilder = WeeklyReportsCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> id,
  Value<String> dogId,
  Value<String> planId,
  Value<String> summaryJson,
  Value<String> aiComment,
  Value<String?> nextPlanId,
  Value<String> createdAt,
  Value<String?> readAt,
  Value<int> rowid,
});

class $$WeeklyReportsTableFilterComposer
    extends Composer<_$AppDatabase, $WeeklyReportsTable> {
  $$WeeklyReportsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get summaryJson => $composableBuilder(
      column: $table.summaryJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get aiComment => $composableBuilder(
      column: $table.aiComment, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get nextPlanId => $composableBuilder(
      column: $table.nextPlanId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnFilters(column));
}

class $$WeeklyReportsTableOrderingComposer
    extends Composer<_$AppDatabase, $WeeklyReportsTable> {
  $$WeeklyReportsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get planId => $composableBuilder(
      column: $table.planId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get summaryJson => $composableBuilder(
      column: $table.summaryJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get aiComment => $composableBuilder(
      column: $table.aiComment, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get nextPlanId => $composableBuilder(
      column: $table.nextPlanId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get readAt => $composableBuilder(
      column: $table.readAt, builder: (column) => ColumnOrderings(column));
}

class $$WeeklyReportsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeeklyReportsTable> {
  $$WeeklyReportsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get planId =>
      $composableBuilder(column: $table.planId, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
      column: $table.summaryJson, builder: (column) => column);

  GeneratedColumn<String> get aiComment =>
      $composableBuilder(column: $table.aiComment, builder: (column) => column);

  GeneratedColumn<String> get nextPlanId => $composableBuilder(
      column: $table.nextPlanId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get readAt =>
      $composableBuilder(column: $table.readAt, builder: (column) => column);
}

class $$WeeklyReportsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WeeklyReportsTable,
    WeeklyReport,
    $$WeeklyReportsTableFilterComposer,
    $$WeeklyReportsTableOrderingComposer,
    $$WeeklyReportsTableAnnotationComposer,
    $$WeeklyReportsTableCreateCompanionBuilder,
    $$WeeklyReportsTableUpdateCompanionBuilder,
    (
      WeeklyReport,
      BaseReferences<_$AppDatabase, $WeeklyReportsTable, WeeklyReport>
    ),
    WeeklyReport,
    PrefetchHooks Function()> {
  $$WeeklyReportsTableTableManager(_$AppDatabase db, $WeeklyReportsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeeklyReportsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeeklyReportsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeeklyReportsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> dogId = const Value.absent(),
            Value<String> planId = const Value.absent(),
            Value<String> summaryJson = const Value.absent(),
            Value<String> aiComment = const Value.absent(),
            Value<String?> nextPlanId = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<String?> readAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WeeklyReportsCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            dogId: dogId,
            planId: planId,
            summaryJson: summaryJson,
            aiComment: aiComment,
            nextPlanId: nextPlanId,
            createdAt: createdAt,
            readAt: readAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String id,
            required String dogId,
            required String planId,
            required String summaryJson,
            required String aiComment,
            Value<String?> nextPlanId = const Value.absent(),
            required String createdAt,
            Value<String?> readAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WeeklyReportsCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            dogId: dogId,
            planId: planId,
            summaryJson: summaryJson,
            aiComment: aiComment,
            nextPlanId: nextPlanId,
            createdAt: createdAt,
            readAt: readAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WeeklyReportsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WeeklyReportsTable,
    WeeklyReport,
    $$WeeklyReportsTableFilterComposer,
    $$WeeklyReportsTableOrderingComposer,
    $$WeeklyReportsTableAnnotationComposer,
    $$WeeklyReportsTableCreateCompanionBuilder,
    $$WeeklyReportsTableUpdateCompanionBuilder,
    (
      WeeklyReport,
      BaseReferences<_$AppDatabase, $WeeklyReportsTable, WeeklyReport>
    ),
    WeeklyReport,
    PrefetchHooks Function()>;
typedef $$AiConversationsTableCreateCompanionBuilder = AiConversationsCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String id,
  required String dogId,
  required String type,
  Value<String?> skillId,
  Value<String?> issueId,
  required String createdAt,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$AiConversationsTableUpdateCompanionBuilder = AiConversationsCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> id,
  Value<String> dogId,
  Value<String> type,
  Value<String?> skillId,
  Value<String?> issueId,
  Value<String> createdAt,
  Value<String> updatedAt,
  Value<int> rowid,
});

class $$AiConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get issueId => $composableBuilder(
      column: $table.issueId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$AiConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get skillId => $composableBuilder(
      column: $table.skillId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get issueId => $composableBuilder(
      column: $table.issueId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$AiConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiConversationsTable> {
  $$AiConversationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get skillId =>
      $composableBuilder(column: $table.skillId, builder: (column) => column);

  GeneratedColumn<String> get issueId =>
      $composableBuilder(column: $table.issueId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AiConversationsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AiConversationsTable,
    AiConversation,
    $$AiConversationsTableFilterComposer,
    $$AiConversationsTableOrderingComposer,
    $$AiConversationsTableAnnotationComposer,
    $$AiConversationsTableCreateCompanionBuilder,
    $$AiConversationsTableUpdateCompanionBuilder,
    (
      AiConversation,
      BaseReferences<_$AppDatabase, $AiConversationsTable, AiConversation>
    ),
    AiConversation,
    PrefetchHooks Function()> {
  $$AiConversationsTableTableManager(
      _$AppDatabase db, $AiConversationsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiConversationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> dogId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String?> skillId = const Value.absent(),
            Value<String?> issueId = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AiConversationsCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            dogId: dogId,
            type: type,
            skillId: skillId,
            issueId: issueId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String id,
            required String dogId,
            required String type,
            Value<String?> skillId = const Value.absent(),
            Value<String?> issueId = const Value.absent(),
            required String createdAt,
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AiConversationsCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            dogId: dogId,
            type: type,
            skillId: skillId,
            issueId: issueId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AiConversationsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AiConversationsTable,
    AiConversation,
    $$AiConversationsTableFilterComposer,
    $$AiConversationsTableOrderingComposer,
    $$AiConversationsTableAnnotationComposer,
    $$AiConversationsTableCreateCompanionBuilder,
    $$AiConversationsTableUpdateCompanionBuilder,
    (
      AiConversation,
      BaseReferences<_$AppDatabase, $AiConversationsTable, AiConversation>
    ),
    AiConversation,
    PrefetchHooks Function()>;
typedef $$AiMessagesTableCreateCompanionBuilder = AiMessagesCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String id,
  required String conversationId,
  required String role,
  required String content,
  Value<String> citedContentIds,
  required String kind,
  required String createdAt,
  Value<int> rowid,
});
typedef $$AiMessagesTableUpdateCompanionBuilder = AiMessagesCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> id,
  Value<String> conversationId,
  Value<String> role,
  Value<String> content,
  Value<String> citedContentIds,
  Value<String> kind,
  Value<String> createdAt,
  Value<int> rowid,
});

class $$AiMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get citedContentIds => $composableBuilder(
      column: $table.citedContentIds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AiMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get role => $composableBuilder(
      column: $table.role, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get content => $composableBuilder(
      column: $table.content, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get citedContentIds => $composableBuilder(
      column: $table.citedContentIds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AiMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $AiMessagesTable> {
  $$AiMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get citedContentIds => $composableBuilder(
      column: $table.citedContentIds, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AiMessagesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AiMessagesTable,
    AiMessage,
    $$AiMessagesTableFilterComposer,
    $$AiMessagesTableOrderingComposer,
    $$AiMessagesTableAnnotationComposer,
    $$AiMessagesTableCreateCompanionBuilder,
    $$AiMessagesTableUpdateCompanionBuilder,
    (AiMessage, BaseReferences<_$AppDatabase, $AiMessagesTable, AiMessage>),
    AiMessage,
    PrefetchHooks Function()> {
  $$AiMessagesTableTableManager(_$AppDatabase db, $AiMessagesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AiMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AiMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AiMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> role = const Value.absent(),
            Value<String> content = const Value.absent(),
            Value<String> citedContentIds = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AiMessagesCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            citedContentIds: citedContentIds,
            kind: kind,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String id,
            required String conversationId,
            required String role,
            required String content,
            Value<String> citedContentIds = const Value.absent(),
            required String kind,
            required String createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              AiMessagesCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            citedContentIds: citedContentIds,
            kind: kind,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AiMessagesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AiMessagesTable,
    AiMessage,
    $$AiMessagesTableFilterComposer,
    $$AiMessagesTableOrderingComposer,
    $$AiMessagesTableAnnotationComposer,
    $$AiMessagesTableCreateCompanionBuilder,
    $$AiMessagesTableUpdateCompanionBuilder,
    (AiMessage, BaseReferences<_$AppDatabase, $AiMessagesTable, AiMessage>),
    AiMessage,
    PrefetchHooks Function()>;
typedef $$DiagnosisResultsTableCreateCompanionBuilder
    = DiagnosisResultsCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String id,
  required String conversationId,
  required String dogId,
  required String issueId,
  required String resultKey,
  required String solutionSkillIds,
  Value<String?> addedToPlanId,
  Value<String?> userId,
  required String createdAt,
  Value<int> rowid,
});
typedef $$DiagnosisResultsTableUpdateCompanionBuilder
    = DiagnosisResultsCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> id,
  Value<String> conversationId,
  Value<String> dogId,
  Value<String> issueId,
  Value<String> resultKey,
  Value<String> solutionSkillIds,
  Value<String?> addedToPlanId,
  Value<String?> userId,
  Value<String> createdAt,
  Value<int> rowid,
});

class $$DiagnosisResultsTableFilterComposer
    extends Composer<_$AppDatabase, $DiagnosisResultsTable> {
  $$DiagnosisResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get issueId => $composableBuilder(
      column: $table.issueId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resultKey => $composableBuilder(
      column: $table.resultKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get solutionSkillIds => $composableBuilder(
      column: $table.solutionSkillIds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get addedToPlanId => $composableBuilder(
      column: $table.addedToPlanId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$DiagnosisResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $DiagnosisResultsTable> {
  $$DiagnosisResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get conversationId => $composableBuilder(
      column: $table.conversationId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get issueId => $composableBuilder(
      column: $table.issueId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resultKey => $composableBuilder(
      column: $table.resultKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get solutionSkillIds => $composableBuilder(
      column: $table.solutionSkillIds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get addedToPlanId => $composableBuilder(
      column: $table.addedToPlanId,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$DiagnosisResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DiagnosisResultsTable> {
  $$DiagnosisResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
      column: $table.conversationId, builder: (column) => column);

  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get issueId =>
      $composableBuilder(column: $table.issueId, builder: (column) => column);

  GeneratedColumn<String> get resultKey =>
      $composableBuilder(column: $table.resultKey, builder: (column) => column);

  GeneratedColumn<String> get solutionSkillIds => $composableBuilder(
      column: $table.solutionSkillIds, builder: (column) => column);

  GeneratedColumn<String> get addedToPlanId => $composableBuilder(
      column: $table.addedToPlanId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DiagnosisResultsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DiagnosisResultsTable,
    DiagnosisResult,
    $$DiagnosisResultsTableFilterComposer,
    $$DiagnosisResultsTableOrderingComposer,
    $$DiagnosisResultsTableAnnotationComposer,
    $$DiagnosisResultsTableCreateCompanionBuilder,
    $$DiagnosisResultsTableUpdateCompanionBuilder,
    (
      DiagnosisResult,
      BaseReferences<_$AppDatabase, $DiagnosisResultsTable, DiagnosisResult>
    ),
    DiagnosisResult,
    PrefetchHooks Function()> {
  $$DiagnosisResultsTableTableManager(
      _$AppDatabase db, $DiagnosisResultsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DiagnosisResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DiagnosisResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DiagnosisResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> conversationId = const Value.absent(),
            Value<String> dogId = const Value.absent(),
            Value<String> issueId = const Value.absent(),
            Value<String> resultKey = const Value.absent(),
            Value<String> solutionSkillIds = const Value.absent(),
            Value<String?> addedToPlanId = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DiagnosisResultsCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            conversationId: conversationId,
            dogId: dogId,
            issueId: issueId,
            resultKey: resultKey,
            solutionSkillIds: solutionSkillIds,
            addedToPlanId: addedToPlanId,
            userId: userId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String id,
            required String conversationId,
            required String dogId,
            required String issueId,
            required String resultKey,
            required String solutionSkillIds,
            Value<String?> addedToPlanId = const Value.absent(),
            Value<String?> userId = const Value.absent(),
            required String createdAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              DiagnosisResultsCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            conversationId: conversationId,
            dogId: dogId,
            issueId: issueId,
            resultKey: resultKey,
            solutionSkillIds: solutionSkillIds,
            addedToPlanId: addedToPlanId,
            userId: userId,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DiagnosisResultsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DiagnosisResultsTable,
    DiagnosisResult,
    $$DiagnosisResultsTableFilterComposer,
    $$DiagnosisResultsTableOrderingComposer,
    $$DiagnosisResultsTableAnnotationComposer,
    $$DiagnosisResultsTableCreateCompanionBuilder,
    $$DiagnosisResultsTableUpdateCompanionBuilder,
    (
      DiagnosisResult,
      BaseReferences<_$AppDatabase, $DiagnosisResultsTable, DiagnosisResult>
    ),
    DiagnosisResult,
    PrefetchHooks Function()>;
typedef $$ReminderSettingsTableCreateCompanionBuilder
    = ReminderSettingsCompanion Function({
  required String dogId,
  Value<bool> enabled,
  Value<int> hour,
  Value<int> minute,
  required String updatedAt,
  Value<int> rowid,
});
typedef $$ReminderSettingsTableUpdateCompanionBuilder
    = ReminderSettingsCompanion Function({
  Value<String> dogId,
  Value<bool> enabled,
  Value<int> hour,
  Value<int> minute,
  Value<String> updatedAt,
  Value<int> rowid,
});

class $$ReminderSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $ReminderSettingsTable> {
  $$ReminderSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hour => $composableBuilder(
      column: $table.hour, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get minute => $composableBuilder(
      column: $table.minute, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$ReminderSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $ReminderSettingsTable> {
  $$ReminderSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get enabled => $composableBuilder(
      column: $table.enabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hour => $composableBuilder(
      column: $table.hour, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get minute => $composableBuilder(
      column: $table.minute, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$ReminderSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReminderSettingsTable> {
  $$ReminderSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get minute =>
      $composableBuilder(column: $table.minute, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ReminderSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ReminderSettingsTable,
    ReminderSetting,
    $$ReminderSettingsTableFilterComposer,
    $$ReminderSettingsTableOrderingComposer,
    $$ReminderSettingsTableAnnotationComposer,
    $$ReminderSettingsTableCreateCompanionBuilder,
    $$ReminderSettingsTableUpdateCompanionBuilder,
    (
      ReminderSetting,
      BaseReferences<_$AppDatabase, $ReminderSettingsTable, ReminderSetting>
    ),
    ReminderSetting,
    PrefetchHooks Function()> {
  $$ReminderSettingsTableTableManager(
      _$AppDatabase db, $ReminderSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReminderSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> dogId = const Value.absent(),
            Value<bool> enabled = const Value.absent(),
            Value<int> hour = const Value.absent(),
            Value<int> minute = const Value.absent(),
            Value<String> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ReminderSettingsCompanion(
            dogId: dogId,
            enabled: enabled,
            hour: hour,
            minute: minute,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String dogId,
            Value<bool> enabled = const Value.absent(),
            Value<int> hour = const Value.absent(),
            Value<int> minute = const Value.absent(),
            required String updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ReminderSettingsCompanion.insert(
            dogId: dogId,
            enabled: enabled,
            hour: hour,
            minute: minute,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ReminderSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ReminderSettingsTable,
    ReminderSetting,
    $$ReminderSettingsTableFilterComposer,
    $$ReminderSettingsTableOrderingComposer,
    $$ReminderSettingsTableAnnotationComposer,
    $$ReminderSettingsTableCreateCompanionBuilder,
    $$ReminderSettingsTableUpdateCompanionBuilder,
    (
      ReminderSetting,
      BaseReferences<_$AppDatabase, $ReminderSettingsTable, ReminderSetting>
    ),
    ReminderSetting,
    PrefetchHooks Function()>;
typedef $$CareRemindersTableCreateCompanionBuilder = CareRemindersCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String id,
  required String dogId,
  Value<String?> templateId,
  required String type,
  required String title,
  Value<String> note,
  required String dueDate,
  Value<String?> doneAt,
  Value<bool> skipped,
  required String source,
  Value<int> rowid,
});
typedef $$CareRemindersTableUpdateCompanionBuilder = CareRemindersCompanion
    Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> id,
  Value<String> dogId,
  Value<String?> templateId,
  Value<String> type,
  Value<String> title,
  Value<String> note,
  Value<String> dueDate,
  Value<String?> doneAt,
  Value<bool> skipped,
  Value<String> source,
  Value<int> rowid,
});

class $$CareRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $CareRemindersTable> {
  $$CareRemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get doneAt => $composableBuilder(
      column: $table.doneAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get skipped => $composableBuilder(
      column: $table.skipped, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));
}

class $$CareRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $CareRemindersTable> {
  $$CareRemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dueDate => $composableBuilder(
      column: $table.dueDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get doneAt => $composableBuilder(
      column: $table.doneAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get skipped => $composableBuilder(
      column: $table.skipped, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));
}

class $$CareRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CareRemindersTable> {
  $$CareRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get templateId => $composableBuilder(
      column: $table.templateId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get dueDate =>
      $composableBuilder(column: $table.dueDate, builder: (column) => column);

  GeneratedColumn<String> get doneAt =>
      $composableBuilder(column: $table.doneAt, builder: (column) => column);

  GeneratedColumn<bool> get skipped =>
      $composableBuilder(column: $table.skipped, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$CareRemindersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $CareRemindersTable,
    CareReminder,
    $$CareRemindersTableFilterComposer,
    $$CareRemindersTableOrderingComposer,
    $$CareRemindersTableAnnotationComposer,
    $$CareRemindersTableCreateCompanionBuilder,
    $$CareRemindersTableUpdateCompanionBuilder,
    (
      CareReminder,
      BaseReferences<_$AppDatabase, $CareRemindersTable, CareReminder>
    ),
    CareReminder,
    PrefetchHooks Function()> {
  $$CareRemindersTableTableManager(_$AppDatabase db, $CareRemindersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CareRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CareRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CareRemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> id = const Value.absent(),
            Value<String> dogId = const Value.absent(),
            Value<String?> templateId = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> note = const Value.absent(),
            Value<String> dueDate = const Value.absent(),
            Value<String?> doneAt = const Value.absent(),
            Value<bool> skipped = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CareRemindersCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            dogId: dogId,
            templateId: templateId,
            type: type,
            title: title,
            note: note,
            dueDate: dueDate,
            doneAt: doneAt,
            skipped: skipped,
            source: source,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String id,
            required String dogId,
            Value<String?> templateId = const Value.absent(),
            required String type,
            required String title,
            Value<String> note = const Value.absent(),
            required String dueDate,
            Value<String?> doneAt = const Value.absent(),
            Value<bool> skipped = const Value.absent(),
            required String source,
            Value<int> rowid = const Value.absent(),
          }) =>
              CareRemindersCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            id: id,
            dogId: dogId,
            templateId: templateId,
            type: type,
            title: title,
            note: note,
            dueDate: dueDate,
            doneAt: doneAt,
            skipped: skipped,
            source: source,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CareRemindersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $CareRemindersTable,
    CareReminder,
    $$CareRemindersTableFilterComposer,
    $$CareRemindersTableOrderingComposer,
    $$CareRemindersTableAnnotationComposer,
    $$CareRemindersTableCreateCompanionBuilder,
    $$CareRemindersTableUpdateCompanionBuilder,
    (
      CareReminder,
      BaseReferences<_$AppDatabase, $CareRemindersTable, CareReminder>
    ),
    CareReminder,
    PrefetchHooks Function()>;
typedef $$DogBadgesTableCreateCompanionBuilder = DogBadgesCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  required String dogId,
  required String badgeId,
  required String earnedAt,
  required String earnedByUserId,
  Value<int> rowid,
});
typedef $$DogBadgesTableUpdateCompanionBuilder = DogBadgesCompanion Function({
  Value<String> clientUpdatedAt,
  Value<bool> deleted,
  Value<String> dogId,
  Value<String> badgeId,
  Value<String> earnedAt,
  Value<String> earnedByUserId,
  Value<int> rowid,
});

class $$DogBadgesTableFilterComposer
    extends Composer<_$AppDatabase, $DogBadgesTable> {
  $$DogBadgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get badgeId => $composableBuilder(
      column: $table.badgeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get earnedAt => $composableBuilder(
      column: $table.earnedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get earnedByUserId => $composableBuilder(
      column: $table.earnedByUserId,
      builder: (column) => ColumnFilters(column));
}

class $$DogBadgesTableOrderingComposer
    extends Composer<_$AppDatabase, $DogBadgesTable> {
  $$DogBadgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get badgeId => $composableBuilder(
      column: $table.badgeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get earnedAt => $composableBuilder(
      column: $table.earnedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get earnedByUserId => $composableBuilder(
      column: $table.earnedByUserId,
      builder: (column) => ColumnOrderings(column));
}

class $$DogBadgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DogBadgesTable> {
  $$DogBadgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get clientUpdatedAt => $composableBuilder(
      column: $table.clientUpdatedAt, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get badgeId =>
      $composableBuilder(column: $table.badgeId, builder: (column) => column);

  GeneratedColumn<String> get earnedAt =>
      $composableBuilder(column: $table.earnedAt, builder: (column) => column);

  GeneratedColumn<String> get earnedByUserId => $composableBuilder(
      column: $table.earnedByUserId, builder: (column) => column);
}

class $$DogBadgesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $DogBadgesTable,
    DogBadge,
    $$DogBadgesTableFilterComposer,
    $$DogBadgesTableOrderingComposer,
    $$DogBadgesTableAnnotationComposer,
    $$DogBadgesTableCreateCompanionBuilder,
    $$DogBadgesTableUpdateCompanionBuilder,
    (DogBadge, BaseReferences<_$AppDatabase, $DogBadgesTable, DogBadge>),
    DogBadge,
    PrefetchHooks Function()> {
  $$DogBadgesTableTableManager(_$AppDatabase db, $DogBadgesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DogBadgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DogBadgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DogBadgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<String> dogId = const Value.absent(),
            Value<String> badgeId = const Value.absent(),
            Value<String> earnedAt = const Value.absent(),
            Value<String> earnedByUserId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DogBadgesCompanion(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            dogId: dogId,
            badgeId: badgeId,
            earnedAt: earnedAt,
            earnedByUserId: earnedByUserId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            Value<String> clientUpdatedAt = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            required String dogId,
            required String badgeId,
            required String earnedAt,
            required String earnedByUserId,
            Value<int> rowid = const Value.absent(),
          }) =>
              DogBadgesCompanion.insert(
            clientUpdatedAt: clientUpdatedAt,
            deleted: deleted,
            dogId: dogId,
            badgeId: badgeId,
            earnedAt: earnedAt,
            earnedByUserId: earnedByUserId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DogBadgesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $DogBadgesTable,
    DogBadge,
    $$DogBadgesTableFilterComposer,
    $$DogBadgesTableOrderingComposer,
    $$DogBadgesTableAnnotationComposer,
    $$DogBadgesTableCreateCompanionBuilder,
    $$DogBadgesTableUpdateCompanionBuilder,
    (DogBadge, BaseReferences<_$AppDatabase, $DogBadgesTable, DogBadge>),
    DogBadge,
    PrefetchHooks Function()>;
typedef $$LocalAccountsTableCreateCompanionBuilder = LocalAccountsCompanion
    Function({
  Value<int> id,
  required String userId,
  required String token,
  required String createdAt,
});
typedef $$LocalAccountsTableUpdateCompanionBuilder = LocalAccountsCompanion
    Function({
  Value<int> id,
  Value<String> userId,
  Value<String> token,
  Value<String> createdAt,
});

class $$LocalAccountsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get token => $composableBuilder(
      column: $table.token, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$LocalAccountsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get token => $composableBuilder(
      column: $table.token, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalAccountsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAccountsTable> {
  $$LocalAccountsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get token =>
      $composableBuilder(column: $table.token, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$LocalAccountsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $LocalAccountsTable,
    LocalAccount,
    $$LocalAccountsTableFilterComposer,
    $$LocalAccountsTableOrderingComposer,
    $$LocalAccountsTableAnnotationComposer,
    $$LocalAccountsTableCreateCompanionBuilder,
    $$LocalAccountsTableUpdateCompanionBuilder,
    (
      LocalAccount,
      BaseReferences<_$AppDatabase, $LocalAccountsTable, LocalAccount>
    ),
    LocalAccount,
    PrefetchHooks Function()> {
  $$LocalAccountsTableTableManager(_$AppDatabase db, $LocalAccountsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAccountsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAccountsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAccountsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> token = const Value.absent(),
            Value<String> createdAt = const Value.absent(),
          }) =>
              LocalAccountsCompanion(
            id: id,
            userId: userId,
            token: token,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String userId,
            required String token,
            required String createdAt,
          }) =>
              LocalAccountsCompanion.insert(
            id: id,
            userId: userId,
            token: token,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$LocalAccountsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $LocalAccountsTable,
    LocalAccount,
    $$LocalAccountsTableFilterComposer,
    $$LocalAccountsTableOrderingComposer,
    $$LocalAccountsTableAnnotationComposer,
    $$LocalAccountsTableCreateCompanionBuilder,
    $$LocalAccountsTableUpdateCompanionBuilder,
    (
      LocalAccount,
      BaseReferences<_$AppDatabase, $LocalAccountsTable, LocalAccount>
    ),
    LocalAccount,
    PrefetchHooks Function()>;
typedef $$SyncStatesTableCreateCompanionBuilder = SyncStatesCompanion Function({
  required String householdId,
  Value<int> lastPullSeq,
  Value<String?> lastPushAt,
  Value<int> rowid,
});
typedef $$SyncStatesTableUpdateCompanionBuilder = SyncStatesCompanion Function({
  Value<String> householdId,
  Value<int> lastPullSeq,
  Value<String?> lastPushAt,
  Value<int> rowid,
});

class $$SyncStatesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastPullSeq => $composableBuilder(
      column: $table.lastPullSeq, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => ColumnFilters(column));
}

class $$SyncStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastPullSeq => $composableBuilder(
      column: $table.lastPullSeq, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStatesTable> {
  $$SyncStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get householdId => $composableBuilder(
      column: $table.householdId, builder: (column) => column);

  GeneratedColumn<int> get lastPullSeq => $composableBuilder(
      column: $table.lastPullSeq, builder: (column) => column);

  GeneratedColumn<String> get lastPushAt => $composableBuilder(
      column: $table.lastPushAt, builder: (column) => column);
}

class $$SyncStatesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncStatesTable,
    SyncState,
    $$SyncStatesTableFilterComposer,
    $$SyncStatesTableOrderingComposer,
    $$SyncStatesTableAnnotationComposer,
    $$SyncStatesTableCreateCompanionBuilder,
    $$SyncStatesTableUpdateCompanionBuilder,
    (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
    SyncState,
    PrefetchHooks Function()> {
  $$SyncStatesTableTableManager(_$AppDatabase db, $SyncStatesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> householdId = const Value.absent(),
            Value<int> lastPullSeq = const Value.absent(),
            Value<String?> lastPushAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStatesCompanion(
            householdId: householdId,
            lastPullSeq: lastPullSeq,
            lastPushAt: lastPushAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String householdId,
            Value<int> lastPullSeq = const Value.absent(),
            Value<String?> lastPushAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncStatesCompanion.insert(
            householdId: householdId,
            lastPullSeq: lastPullSeq,
            lastPushAt: lastPushAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncStatesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncStatesTable,
    SyncState,
    $$SyncStatesTableFilterComposer,
    $$SyncStatesTableOrderingComposer,
    $$SyncStatesTableAnnotationComposer,
    $$SyncStatesTableCreateCompanionBuilder,
    $$SyncStatesTableUpdateCompanionBuilder,
    (SyncState, BaseReferences<_$AppDatabase, $SyncStatesTable, SyncState>),
    SyncState,
    PrefetchHooks Function()>;
typedef $$SyncOutboxTableCreateCompanionBuilder = SyncOutboxCompanion Function({
  required String tbl,
  required String pk,
  Value<bool> deleted,
  Value<int> version,
  Value<String> changedAt,
  Value<int> rowid,
});
typedef $$SyncOutboxTableUpdateCompanionBuilder = SyncOutboxCompanion Function({
  Value<String> tbl,
  Value<String> pk,
  Value<bool> deleted,
  Value<int> version,
  Value<String> changedAt,
  Value<int> rowid,
});

class $$SyncOutboxTableFilterComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tbl => $composableBuilder(
      column: $table.tbl, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get pk => $composableBuilder(
      column: $table.pk, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get changedAt => $composableBuilder(
      column: $table.changedAt, builder: (column) => ColumnFilters(column));
}

class $$SyncOutboxTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tbl => $composableBuilder(
      column: $table.tbl, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get pk => $composableBuilder(
      column: $table.pk, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get deleted => $composableBuilder(
      column: $table.deleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get version => $composableBuilder(
      column: $table.version, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get changedAt => $composableBuilder(
      column: $table.changedAt, builder: (column) => ColumnOrderings(column));
}

class $$SyncOutboxTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncOutboxTable> {
  $$SyncOutboxTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tbl =>
      $composableBuilder(column: $table.tbl, builder: (column) => column);

  GeneratedColumn<String> get pk =>
      $composableBuilder(column: $table.pk, builder: (column) => column);

  GeneratedColumn<bool> get deleted =>
      $composableBuilder(column: $table.deleted, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);
}

class $$SyncOutboxTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncOutboxTable,
    SyncOutboxData,
    $$SyncOutboxTableFilterComposer,
    $$SyncOutboxTableOrderingComposer,
    $$SyncOutboxTableAnnotationComposer,
    $$SyncOutboxTableCreateCompanionBuilder,
    $$SyncOutboxTableUpdateCompanionBuilder,
    (
      SyncOutboxData,
      BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>
    ),
    SyncOutboxData,
    PrefetchHooks Function()> {
  $$SyncOutboxTableTableManager(_$AppDatabase db, $SyncOutboxTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncOutboxTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncOutboxTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncOutboxTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> tbl = const Value.absent(),
            Value<String> pk = const Value.absent(),
            Value<bool> deleted = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> changedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxCompanion(
            tbl: tbl,
            pk: pk,
            deleted: deleted,
            version: version,
            changedAt: changedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String tbl,
            required String pk,
            Value<bool> deleted = const Value.absent(),
            Value<int> version = const Value.absent(),
            Value<String> changedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SyncOutboxCompanion.insert(
            tbl: tbl,
            pk: pk,
            deleted: deleted,
            version: version,
            changedAt: changedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncOutboxTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncOutboxTable,
    SyncOutboxData,
    $$SyncOutboxTableFilterComposer,
    $$SyncOutboxTableOrderingComposer,
    $$SyncOutboxTableAnnotationComposer,
    $$SyncOutboxTableCreateCompanionBuilder,
    $$SyncOutboxTableUpdateCompanionBuilder,
    (
      SyncOutboxData,
      BaseReferences<_$AppDatabase, $SyncOutboxTable, SyncOutboxData>
    ),
    SyncOutboxData,
    PrefetchHooks Function()>;
typedef $$SyncFlagsTableCreateCompanionBuilder = SyncFlagsCompanion Function({
  Value<int> id,
  Value<bool> applying,
});
typedef $$SyncFlagsTableUpdateCompanionBuilder = SyncFlagsCompanion Function({
  Value<int> id,
  Value<bool> applying,
});

class $$SyncFlagsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncFlagsTable> {
  $$SyncFlagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get applying => $composableBuilder(
      column: $table.applying, builder: (column) => ColumnFilters(column));
}

class $$SyncFlagsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncFlagsTable> {
  $$SyncFlagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get applying => $composableBuilder(
      column: $table.applying, builder: (column) => ColumnOrderings(column));
}

class $$SyncFlagsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncFlagsTable> {
  $$SyncFlagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get applying =>
      $composableBuilder(column: $table.applying, builder: (column) => column);
}

class $$SyncFlagsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncFlagsTable,
    SyncFlag,
    $$SyncFlagsTableFilterComposer,
    $$SyncFlagsTableOrderingComposer,
    $$SyncFlagsTableAnnotationComposer,
    $$SyncFlagsTableCreateCompanionBuilder,
    $$SyncFlagsTableUpdateCompanionBuilder,
    (SyncFlag, BaseReferences<_$AppDatabase, $SyncFlagsTable, SyncFlag>),
    SyncFlag,
    PrefetchHooks Function()> {
  $$SyncFlagsTableTableManager(_$AppDatabase db, $SyncFlagsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncFlagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncFlagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncFlagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<bool> applying = const Value.absent(),
          }) =>
              SyncFlagsCompanion(
            id: id,
            applying: applying,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<bool> applying = const Value.absent(),
          }) =>
              SyncFlagsCompanion.insert(
            id: id,
            applying: applying,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncFlagsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncFlagsTable,
    SyncFlag,
    $$SyncFlagsTableFilterComposer,
    $$SyncFlagsTableOrderingComposer,
    $$SyncFlagsTableAnnotationComposer,
    $$SyncFlagsTableCreateCompanionBuilder,
    $$SyncFlagsTableUpdateCompanionBuilder,
    (SyncFlag, BaseReferences<_$AppDatabase, $SyncFlagsTable, SyncFlag>),
    SyncFlag,
    PrefetchHooks Function()>;
typedef $$BadgePopupsSeenTableCreateCompanionBuilder = BadgePopupsSeenCompanion
    Function({
  required String dogId,
  required String badgeId,
  required String seenAt,
  Value<int> rowid,
});
typedef $$BadgePopupsSeenTableUpdateCompanionBuilder = BadgePopupsSeenCompanion
    Function({
  Value<String> dogId,
  Value<String> badgeId,
  Value<String> seenAt,
  Value<int> rowid,
});

class $$BadgePopupsSeenTableFilterComposer
    extends Composer<_$AppDatabase, $BadgePopupsSeenTable> {
  $$BadgePopupsSeenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get badgeId => $composableBuilder(
      column: $table.badgeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get seenAt => $composableBuilder(
      column: $table.seenAt, builder: (column) => ColumnFilters(column));
}

class $$BadgePopupsSeenTableOrderingComposer
    extends Composer<_$AppDatabase, $BadgePopupsSeenTable> {
  $$BadgePopupsSeenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dogId => $composableBuilder(
      column: $table.dogId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get badgeId => $composableBuilder(
      column: $table.badgeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get seenAt => $composableBuilder(
      column: $table.seenAt, builder: (column) => ColumnOrderings(column));
}

class $$BadgePopupsSeenTableAnnotationComposer
    extends Composer<_$AppDatabase, $BadgePopupsSeenTable> {
  $$BadgePopupsSeenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dogId =>
      $composableBuilder(column: $table.dogId, builder: (column) => column);

  GeneratedColumn<String> get badgeId =>
      $composableBuilder(column: $table.badgeId, builder: (column) => column);

  GeneratedColumn<String> get seenAt =>
      $composableBuilder(column: $table.seenAt, builder: (column) => column);
}

class $$BadgePopupsSeenTableTableManager extends RootTableManager<
    _$AppDatabase,
    $BadgePopupsSeenTable,
    BadgePopupsSeenData,
    $$BadgePopupsSeenTableFilterComposer,
    $$BadgePopupsSeenTableOrderingComposer,
    $$BadgePopupsSeenTableAnnotationComposer,
    $$BadgePopupsSeenTableCreateCompanionBuilder,
    $$BadgePopupsSeenTableUpdateCompanionBuilder,
    (
      BadgePopupsSeenData,
      BaseReferences<_$AppDatabase, $BadgePopupsSeenTable, BadgePopupsSeenData>
    ),
    BadgePopupsSeenData,
    PrefetchHooks Function()> {
  $$BadgePopupsSeenTableTableManager(
      _$AppDatabase db, $BadgePopupsSeenTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BadgePopupsSeenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BadgePopupsSeenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BadgePopupsSeenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> dogId = const Value.absent(),
            Value<String> badgeId = const Value.absent(),
            Value<String> seenAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              BadgePopupsSeenCompanion(
            dogId: dogId,
            badgeId: badgeId,
            seenAt: seenAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String dogId,
            required String badgeId,
            required String seenAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              BadgePopupsSeenCompanion.insert(
            dogId: dogId,
            badgeId: badgeId,
            seenAt: seenAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$BadgePopupsSeenTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $BadgePopupsSeenTable,
    BadgePopupsSeenData,
    $$BadgePopupsSeenTableFilterComposer,
    $$BadgePopupsSeenTableOrderingComposer,
    $$BadgePopupsSeenTableAnnotationComposer,
    $$BadgePopupsSeenTableCreateCompanionBuilder,
    $$BadgePopupsSeenTableUpdateCompanionBuilder,
    (
      BadgePopupsSeenData,
      BaseReferences<_$AppDatabase, $BadgePopupsSeenTable, BadgePopupsSeenData>
    ),
    BadgePopupsSeenData,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ContentVersionsTableTableManager get contentVersions =>
      $$ContentVersionsTableTableManager(_db, _db.contentVersions);
  $$ContentSkillsTableTableManager get contentSkills =>
      $$ContentSkillsTableTableManager(_db, _db.contentSkills);
  $$ContentIssuesTableTableManager get contentIssues =>
      $$ContentIssuesTableTableManager(_db, _db.contentIssues);
  $$ContentBadgesTableTableManager get contentBadges =>
      $$ContentBadgesTableTableManager(_db, _db.contentBadges);
  $$ContentCareItemsTableTableManager get contentCareItems =>
      $$ContentCareItemsTableTableManager(_db, _db.contentCareItems);
  $$ContentAiLexiconsTableTableManager get contentAiLexicons =>
      $$ContentAiLexiconsTableTableManager(_db, _db.contentAiLexicons);
  $$UsersTableTableManager get users =>
      $$UsersTableTableManager(_db, _db.users);
  $$HouseholdsTableTableManager get households =>
      $$HouseholdsTableTableManager(_db, _db.households);
  $$HouseholdMembersTableTableManager get householdMembers =>
      $$HouseholdMembersTableTableManager(_db, _db.householdMembers);
  $$DogsTableTableManager get dogs => $$DogsTableTableManager(_db, _db.dogs);
  $$DogConcernsTableTableManager get dogConcerns =>
      $$DogConcernsTableTableManager(_db, _db.dogConcerns);
  $$DogCuesTableTableManager get dogCues =>
      $$DogCuesTableTableManager(_db, _db.dogCues);
  $$DogSkillStatusesTableTableManager get dogSkillStatuses =>
      $$DogSkillStatusesTableTableManager(_db, _db.dogSkillStatuses);
  $$WeeklyPlansTableTableManager get weeklyPlans =>
      $$WeeklyPlansTableTableManager(_db, _db.weeklyPlans);
  $$PlanGoalsTableTableManager get planGoals =>
      $$PlanGoalsTableTableManager(_db, _db.planGoals);
  $$DailyMiniTasksTableTableManager get dailyMiniTasks =>
      $$DailyMiniTasksTableTableManager(_db, _db.dailyMiniTasks);
  $$OnboardingDraftsTableTableManager get onboardingDrafts =>
      $$OnboardingDraftsTableTableManager(_db, _db.onboardingDrafts);
  $$TrainingSessionsTableTableManager get trainingSessions =>
      $$TrainingSessionsTableTableManager(_db, _db.trainingSessions);
  $$StreaksTableTableManager get streaks =>
      $$StreaksTableTableManager(_db, _db.streaks);
  $$WeeklyReportsTableTableManager get weeklyReports =>
      $$WeeklyReportsTableTableManager(_db, _db.weeklyReports);
  $$AiConversationsTableTableManager get aiConversations =>
      $$AiConversationsTableTableManager(_db, _db.aiConversations);
  $$AiMessagesTableTableManager get aiMessages =>
      $$AiMessagesTableTableManager(_db, _db.aiMessages);
  $$DiagnosisResultsTableTableManager get diagnosisResults =>
      $$DiagnosisResultsTableTableManager(_db, _db.diagnosisResults);
  $$ReminderSettingsTableTableManager get reminderSettings =>
      $$ReminderSettingsTableTableManager(_db, _db.reminderSettings);
  $$CareRemindersTableTableManager get careReminders =>
      $$CareRemindersTableTableManager(_db, _db.careReminders);
  $$DogBadgesTableTableManager get dogBadges =>
      $$DogBadgesTableTableManager(_db, _db.dogBadges);
  $$LocalAccountsTableTableManager get localAccounts =>
      $$LocalAccountsTableTableManager(_db, _db.localAccounts);
  $$SyncStatesTableTableManager get syncStates =>
      $$SyncStatesTableTableManager(_db, _db.syncStates);
  $$SyncOutboxTableTableManager get syncOutbox =>
      $$SyncOutboxTableTableManager(_db, _db.syncOutbox);
  $$SyncFlagsTableTableManager get syncFlags =>
      $$SyncFlagsTableTableManager(_db, _db.syncFlags);
  $$BadgePopupsSeenTableTableManager get badgePopupsSeen =>
      $$BadgePopupsSeenTableTableManager(_db, _db.badgePopupsSeen);
}
