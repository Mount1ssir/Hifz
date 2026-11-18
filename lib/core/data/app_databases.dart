import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/riwayah.dart';
import 'quran_repository.dart';
import 'user_database.dart';

class AppDatabases {
  AppDatabases._(this.quran, this.user, this.openTime);

  final QuranRepository quran;
  final UserDatabase user;
  final Duration openTime;

  static Future<AppDatabases>? _opening;

  /// One shared connection set per app isolate. Failed opens can be retried.
  static Future<AppDatabases> open({required Riwayah riwayah}) {
    return _opening ??= _open(riwayah).catchError((Object error) {
      _opening = null;
      throw error;
    });
  }

  static Future<AppDatabases> _open(Riwayah riwayah) async {
    final timer = Stopwatch()..start();
    final directory = await getApplicationSupportDirectory();
    final expected = (await rootBundle.loadString(
      'assets/data/quran.db.sha256',
    )).trim();
    final file = File(p.join(directory.path, 'quran-$expected.db'));
    if (!await file.exists() ||
        sha256.convert(await file.readAsBytes()).toString() != expected) {
      final asset = await rootBundle.load('assets/data/quran.db');
      final bytes = asset.buffer.asUint8List(
        asset.offsetInBytes,
        asset.lengthInBytes,
      );
      if (sha256.convert(bytes).toString() != expected) {
        throw StateError('Bundled Quran checksum mismatch.');
      }
      final temporary = File('${file.path}.tmp');
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
    }
    final quran = QuranRepository.open(file, riwayah: riwayah);
    final user = UserDatabase(
      NativeDatabase.createInBackground(
        File(p.join(directory.path, 'user.db')),
      ),
    );
    try {
      await user.customSelect('SELECT 1').get();
      timer.stop();
      return AppDatabases._(quran, user, timer.elapsed);
    } catch (_) {
      quran.close();
      await user.close();
      rethrow;
    }
  }

  Future<void> close() async {
    quran.close();
    await user.close();
    _opening = null;
  }
}
