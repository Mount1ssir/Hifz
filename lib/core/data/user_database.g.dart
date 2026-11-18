// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_database.dart';

// ignore_for_file: type=lint
class $MemorizedAyahsTable extends MemorizedAyahs
    with TableInfo<$MemorizedAyahsTable, MemorizedAyah> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemorizedAyahsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _riwayahMeta = const VerificationMeta(
    'riwayah',
  );
  @override
  late final GeneratedColumn<String> riwayah = GeneratedColumn<String>(
    'riwayah',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _numberingMeta = const VerificationMeta(
    'numbering',
  );
  @override
  late final GeneratedColumn<String> numbering = GeneratedColumn<String>(
    'numbering',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ayahIdMeta = const VerificationMeta('ayahId');
  @override
  late final GeneratedColumn<int> ayahId = GeneratedColumn<int>(
    'ayah_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtMeta = const VerificationMeta(
    'completedAt',
  );
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
    'completed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    riwayah,
    numbering,
    ayahId,
    completedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memorized_ayahs';
  @override
  VerificationContext validateIntegrity(
    Insertable<MemorizedAyah> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('riwayah')) {
      context.handle(
        _riwayahMeta,
        riwayah.isAcceptableOrUnknown(data['riwayah']!, _riwayahMeta),
      );
    } else if (isInserting) {
      context.missing(_riwayahMeta);
    }
    if (data.containsKey('numbering')) {
      context.handle(
        _numberingMeta,
        numbering.isAcceptableOrUnknown(data['numbering']!, _numberingMeta),
      );
    } else if (isInserting) {
      context.missing(_numberingMeta);
    }
    if (data.containsKey('ayah_id')) {
      context.handle(
        _ayahIdMeta,
        ayahId.isAcceptableOrUnknown(data['ayah_id']!, _ayahIdMeta),
      );
    } else if (isInserting) {
      context.missing(_ayahIdMeta);
    }
    if (data.containsKey('completed_at')) {
      context.handle(
        _completedAtMeta,
        completedAt.isAcceptableOrUnknown(
          data['completed_at']!,
          _completedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {riwayah, numbering, ayahId};
  @override
  MemorizedAyah map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemorizedAyah(
      riwayah: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}riwayah'],
      )!,
      numbering: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}numbering'],
      )!,
      ayahId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ayah_id'],
      )!,
      completedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}completed_at'],
      )!,
    );
  }

  @override
  $MemorizedAyahsTable createAlias(String alias) {
    return $MemorizedAyahsTable(attachedDatabase, alias);
  }
}

class MemorizedAyah extends DataClass implements Insertable<MemorizedAyah> {
  final String riwayah;
  final String numbering;
  final int ayahId;
  final DateTime completedAt;
  const MemorizedAyah({
    required this.riwayah,
    required this.numbering,
    required this.ayahId,
    required this.completedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['riwayah'] = Variable<String>(riwayah);
    map['numbering'] = Variable<String>(numbering);
    map['ayah_id'] = Variable<int>(ayahId);
    map['completed_at'] = Variable<DateTime>(completedAt);
    return map;
  }

  MemorizedAyahsCompanion toCompanion(bool nullToAbsent) {
    return MemorizedAyahsCompanion(
      riwayah: Value(riwayah),
      numbering: Value(numbering),
      ayahId: Value(ayahId),
      completedAt: Value(completedAt),
    );
  }

  factory MemorizedAyah.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemorizedAyah(
      riwayah: serializer.fromJson<String>(json['riwayah']),
      numbering: serializer.fromJson<String>(json['numbering']),
      ayahId: serializer.fromJson<int>(json['ayahId']),
      completedAt: serializer.fromJson<DateTime>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'riwayah': serializer.toJson<String>(riwayah),
      'numbering': serializer.toJson<String>(numbering),
      'ayahId': serializer.toJson<int>(ayahId),
      'completedAt': serializer.toJson<DateTime>(completedAt),
    };
  }

  MemorizedAyah copyWith({
    String? riwayah,
    String? numbering,
    int? ayahId,
    DateTime? completedAt,
  }) => MemorizedAyah(
    riwayah: riwayah ?? this.riwayah,
    numbering: numbering ?? this.numbering,
    ayahId: ayahId ?? this.ayahId,
    completedAt: completedAt ?? this.completedAt,
  );
  MemorizedAyah copyWithCompanion(MemorizedAyahsCompanion data) {
    return MemorizedAyah(
      riwayah: data.riwayah.present ? data.riwayah.value : this.riwayah,
      numbering: data.numbering.present ? data.numbering.value : this.numbering,
      ayahId: data.ayahId.present ? data.ayahId.value : this.ayahId,
      completedAt: data.completedAt.present
          ? data.completedAt.value
          : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemorizedAyah(')
          ..write('riwayah: $riwayah, ')
          ..write('numbering: $numbering, ')
          ..write('ayahId: $ayahId, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(riwayah, numbering, ayahId, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemorizedAyah &&
          other.riwayah == this.riwayah &&
          other.numbering == this.numbering &&
          other.ayahId == this.ayahId &&
          other.completedAt == this.completedAt);
}

class MemorizedAyahsCompanion extends UpdateCompanion<MemorizedAyah> {
  final Value<String> riwayah;
  final Value<String> numbering;
  final Value<int> ayahId;
  final Value<DateTime> completedAt;
  final Value<int> rowid;
  const MemorizedAyahsCompanion({
    this.riwayah = const Value.absent(),
    this.numbering = const Value.absent(),
    this.ayahId = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MemorizedAyahsCompanion.insert({
    required String riwayah,
    required String numbering,
    required int ayahId,
    required DateTime completedAt,
    this.rowid = const Value.absent(),
  }) : riwayah = Value(riwayah),
       numbering = Value(numbering),
       ayahId = Value(ayahId),
       completedAt = Value(completedAt);
  static Insertable<MemorizedAyah> custom({
    Expression<String>? riwayah,
    Expression<String>? numbering,
    Expression<int>? ayahId,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (riwayah != null) 'riwayah': riwayah,
      if (numbering != null) 'numbering': numbering,
      if (ayahId != null) 'ayah_id': ayahId,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MemorizedAyahsCompanion copyWith({
    Value<String>? riwayah,
    Value<String>? numbering,
    Value<int>? ayahId,
    Value<DateTime>? completedAt,
    Value<int>? rowid,
  }) {
    return MemorizedAyahsCompanion(
      riwayah: riwayah ?? this.riwayah,
      numbering: numbering ?? this.numbering,
      ayahId: ayahId ?? this.ayahId,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (riwayah.present) {
      map['riwayah'] = Variable<String>(riwayah.value);
    }
    if (numbering.present) {
      map['numbering'] = Variable<String>(numbering.value);
    }
    if (ayahId.present) {
      map['ayah_id'] = Variable<int>(ayahId.value);
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
    return (StringBuffer('MemorizedAyahsCompanion(')
          ..write('riwayah: $riwayah, ')
          ..write('numbering: $numbering, ')
          ..write('ayahId: $ayahId, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$UserDatabase extends GeneratedDatabase {
  _$UserDatabase(QueryExecutor e) : super(e);
  $UserDatabaseManager get managers => $UserDatabaseManager(this);
  late final $MemorizedAyahsTable memorizedAyahs = $MemorizedAyahsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [memorizedAyahs];
}

typedef $$MemorizedAyahsTableCreateCompanionBuilder =
    MemorizedAyahsCompanion Function({
      required String riwayah,
      required String numbering,
      required int ayahId,
      required DateTime completedAt,
      Value<int> rowid,
    });
typedef $$MemorizedAyahsTableUpdateCompanionBuilder =
    MemorizedAyahsCompanion Function({
      Value<String> riwayah,
      Value<String> numbering,
      Value<int> ayahId,
      Value<DateTime> completedAt,
      Value<int> rowid,
    });

class $$MemorizedAyahsTableFilterComposer
    extends Composer<_$UserDatabase, $MemorizedAyahsTable> {
  $$MemorizedAyahsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get riwayah => $composableBuilder(
    column: $table.riwayah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get numbering => $composableBuilder(
    column: $table.numbering,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ayahId => $composableBuilder(
    column: $table.ayahId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MemorizedAyahsTableOrderingComposer
    extends Composer<_$UserDatabase, $MemorizedAyahsTable> {
  $$MemorizedAyahsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get riwayah => $composableBuilder(
    column: $table.riwayah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get numbering => $composableBuilder(
    column: $table.numbering,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ayahId => $composableBuilder(
    column: $table.ayahId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MemorizedAyahsTableAnnotationComposer
    extends Composer<_$UserDatabase, $MemorizedAyahsTable> {
  $$MemorizedAyahsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get riwayah =>
      $composableBuilder(column: $table.riwayah, builder: (column) => column);

  GeneratedColumn<String> get numbering =>
      $composableBuilder(column: $table.numbering, builder: (column) => column);

  GeneratedColumn<int> get ayahId =>
      $composableBuilder(column: $table.ayahId, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
    column: $table.completedAt,
    builder: (column) => column,
  );
}

class $$MemorizedAyahsTableTableManager
    extends
        RootTableManager<
          _$UserDatabase,
          $MemorizedAyahsTable,
          MemorizedAyah,
          $$MemorizedAyahsTableFilterComposer,
          $$MemorizedAyahsTableOrderingComposer,
          $$MemorizedAyahsTableAnnotationComposer,
          $$MemorizedAyahsTableCreateCompanionBuilder,
          $$MemorizedAyahsTableUpdateCompanionBuilder,
          (
            MemorizedAyah,
            BaseReferences<_$UserDatabase, $MemorizedAyahsTable, MemorizedAyah>,
          ),
          MemorizedAyah,
          PrefetchHooks Function()
        > {
  $$MemorizedAyahsTableTableManager(
    _$UserDatabase db,
    $MemorizedAyahsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemorizedAyahsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemorizedAyahsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemorizedAyahsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> riwayah = const Value.absent(),
                Value<String> numbering = const Value.absent(),
                Value<int> ayahId = const Value.absent(),
                Value<DateTime> completedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MemorizedAyahsCompanion(
                riwayah: riwayah,
                numbering: numbering,
                ayahId: ayahId,
                completedAt: completedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String riwayah,
                required String numbering,
                required int ayahId,
                required DateTime completedAt,
                Value<int> rowid = const Value.absent(),
              }) => MemorizedAyahsCompanion.insert(
                riwayah: riwayah,
                numbering: numbering,
                ayahId: ayahId,
                completedAt: completedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$MemorizedAyahsTable, MemorizedAyah>(table),
                  BaseReferences<
                    _$UserDatabase,
                    $MemorizedAyahsTable,
                    MemorizedAyah
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MemorizedAyahsTableProcessedTableManager =
    ProcessedTableManager<
      _$UserDatabase,
      $MemorizedAyahsTable,
      MemorizedAyah,
      $$MemorizedAyahsTableFilterComposer,
      $$MemorizedAyahsTableOrderingComposer,
      $$MemorizedAyahsTableAnnotationComposer,
      $$MemorizedAyahsTableCreateCompanionBuilder,
      $$MemorizedAyahsTableUpdateCompanionBuilder,
      (
        MemorizedAyah,
        BaseReferences<_$UserDatabase, $MemorizedAyahsTable, MemorizedAyah>,
      ),
      MemorizedAyah,
      PrefetchHooks Function()
    >;

class $UserDatabaseManager {
  final _$UserDatabase _db;
  $UserDatabaseManager(this._db);
  $$MemorizedAyahsTableTableManager get memorizedAyahs =>
      $$MemorizedAyahsTableTableManager(_db, _db.memorizedAyahs);
}
