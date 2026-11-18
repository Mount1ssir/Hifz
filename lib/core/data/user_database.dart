import 'package:drift/drift.dart';

import '../../domain/riwayah.dart';

part 'user_database.g.dart';

class MemorizedAyahs extends Table {
  TextColumn get riwayah => text()();
  TextColumn get numbering => text()();
  IntColumn get ayahId => integer()();
  DateTimeColumn get completedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {riwayah, numbering, ayahId};
}

@DriftDatabase(tables: [MemorizedAyahs])
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  Future<void> markMemorized(Riwayah riwayah, int ayahId, DateTime at) {
    riwayah.validateAyah(ayahId);
    return into(memorizedAyahs).insertOnConflictUpdate(
      MemorizedAyahsCompanion.insert(
        riwayah: riwayah.id,
        numbering: riwayah.numbering,
        ayahId: ayahId,
        completedAt: at.toUtc(),
      ),
    );
  }

  Future<List<MemorizedAyah>> progress(Riwayah riwayah) =>
      (select(memorizedAyahs)
            ..where(
              (row) =>
                  row.riwayah.equals(riwayah.id) &
                  row.numbering.equals(riwayah.numbering),
            )
            ..orderBy([(row) => OrderingTerm.asc(row.ayahId)]))
          .get();
}
