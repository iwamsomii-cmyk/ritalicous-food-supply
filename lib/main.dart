import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'services/cloud_service.dart';
import 'services/database_service.dart';
import 'views/app_lock_gate.dart';
import 'views/update_gate.dart';

Future<void> _toggleFullScreen() async {
  final full = await windowManager.isFullScreen();
  await windowManager.setFullScreen(!full);
}

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      title: 'RITALICIOUS FOOD SUPPLY',
      minimumSize: Size(900, 600),
      center: true,
    );
    // The desktop shortcut created by the installer starts the app with
    // --fullscreen. Without it the app simply opens maximized.
    final startFullScreen = args.contains('--fullscreen');
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      if (startFullScreen) {
        await windowManager.setFullScreen(true);
      } else {
        await windowManager.maximize();
      }
      await windowManager.focus();
    });
  }
  await DatabaseService.instance.init();
  try {
    await CloudService.initialize(); // vifaa vilivyounganishwa (real time)
  } catch (_) {}
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
      // F11 toggles full screen on Windows.
      builder: (context, child) {
        if (!Platform.isWindows || child == null) return child ?? const SizedBox.shrink();
        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.f11): () => _toggleFullScreen(),
          },
          child: Focus(autofocus: true, child: child),
        );
      },
      home: const UpdateGate(child: AppLockGate()),
    );
  }
}
