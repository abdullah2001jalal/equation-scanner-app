import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/settings_store.dart';

const String envApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SettingsStore();
  final key = await store.getApiKey(envFallback: envApiKey);
  runApp(EquationScannerApp(hasKey: key.isNotEmpty));
}

class EquationScannerApp extends StatelessWidget {
  final bool hasKey;
  const EquationScannerApp({super.key, this.hasKey = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ماسح المعادلات',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F4E79)),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true),
      ),
      home: const HomeScreen(),
    );
  }
}
