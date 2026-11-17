import 'package:material_ui/material_ui.dart';

class HifzApp extends StatelessWidget {
  const HifzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hifz',
      home: Scaffold(appBar: AppBar(title: const Text('Hifz'))),
    );
  }
}
