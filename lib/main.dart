import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app_modules.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Tanzil Quran text — https://tanzil.net',
    ], await rootBundle.loadString('assets/data/TANZIL-NOTICE.txt'));
  });
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'QUL — Quranic Universal Library',
    ], await rootBundle.loadString('assets/data/QUL-SOURCES.txt'));
  });
  runApp(const HifzApp());
}
