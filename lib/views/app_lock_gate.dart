import 'package:flutter/material.dart';
import '../services/pin_service.dart';
import 'app_shell.dart';
import 'pin_lock_view.dart';

/// Wraps the whole app. On first launch it asks the user to create a PIN.
/// After that, every time the app is opened (including returning from
/// being closed/minimized in the background) it must be unlocked with
/// that PIN before the actual app (AppShell) is shown.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  bool _checking = true;
  bool _hasPin = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _init() async {
    final has = await PinService.instance.hasPin();
    if (mounted) {
      setState(() {
        _hasPin = has;
        _checking = false;
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Once a PIN exists, re-lock the app whenever it leaves the
    // foreground (closed, minimized, switched away from), so it must be
    // unlocked again the next time it's opened.
    if (!_hasPin) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      if (_unlocked) {
        setState(() => _unlocked = false);
      }
    }
  }

  void _onUnlocked() {
    setState(() {
      _hasPin = true;
      _unlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_unlocked) {
      return const AppShell();
    }
    if (!_hasPin) {
      return SetPinView(onDone: _onUnlocked);
    }
    return EnterPinView(onSuccess: _onUnlocked);
  }
}
