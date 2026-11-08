import 'package:flutter/material.dart';
import '../services/update_service.dart';

/// Wraps the app: on start it silently checks for a newer version and, when
/// one exists, downloads and installs it automatically.
class UpdateGate extends StatefulWidget {
  final Widget child;
  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate> {
  bool _busy = false;
  double? _progress;
  String _status = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final info = await UpdateService.check();
    if (info == null || !mounted) return;
    setState(() {
      _busy = true;
      _status = 'Toleo jipya ${info.version} linapakuliwa...';
    });
    try {
      final file = await UpdateService.download(info, (v) {
        if (mounted) setState(() => _progress = v);
      });
      if (!mounted) return;
      setState(() {
        _progress = null;
        _status = 'Inasakinisha toleo jipya...';
      });
      final ok = await UpdateService.install(file);
      if (!ok && mounted) {
        setState(() => _status =
            'Washa "Ruhusu kusakinisha programu" kwa mfumo huu, kisha ufungue tena.');
        await Future.delayed(const Duration(seconds: 6));
      } else {
        await Future.delayed(const Duration(seconds: 4));
      }
    } catch (_) {
      // Offline or download failed: continue using the current version.
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_busy)
          Positioned.fill(
            child: Material(
              color: Colors.black54,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SizedBox(
                      width: 320,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('SASISHA YA MFUMO',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 12),
                          Text(_status, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          LinearProgressIndicator(value: _progress),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
