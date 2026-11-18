import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_modules.dart';
import 'core/data/app_databases.dart';
import 'domain/riwayah.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Tanzil Quran text — https://tanzil.net',
    ], await rootBundle.loadString('assets/data/TANZIL-NOTICE.txt'));
  });
  final databases = await AppDatabases.open(riwayah: Riwayah.hafs);
  debugPrint('Hifz database open: ${databases.openTime.inMilliseconds} ms');
  runApp(const HifzApp());
}
