import 'package:flutter/material.dart';
import 'services/database_service.dart';
import 'views/app_lock_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseService.instance.init();
  runApp(const RitalicousApp());
}

class RitalicousApp extends StatelessWidget {
  const RitalicousApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'RITALICIOUS FOOD SUPPLY',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Arial',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF205080)),
        scaffoldBackgroundColor: const Color(0xFFF4F2FA),
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const AppLockGate(),
    );
  }
}
