import 'package:flutter/material.dart';
import '../services/pin_service.dart';

const _kBrandColor = Color(0xFF205080);
const _kBg = Color(0xFFF4F2FA);

/// Shown the very first time the app is opened: the user chooses a PIN
/// that will be required every time they open the app afterwards.
class SetPinView extends StatefulWidget {
  final VoidCallback onDone;
  const SetPinView({super.key, required this.onDone});

  @override
  State<SetPinView> createState() => _SetPinViewState();
}

class _SetPinViewState extends State<SetPinView> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pin = _pinCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();
    if (pin.length < 4) {
      setState(() => _error = 'Weka PIN yenye tarakimu 4 angalau.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PIN hazifanani. Jaribu tena.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    await PinService.instance.setPin(pin);
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: _kBrandColor),
                const SizedBox(height: 16),
                const Text('Weka PIN ya Usalama', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('PIN hii itakuwa ikiombwa kila utakapofungua app.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'PIN Mpya', counterText: ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Thibitisha PIN', counterText: ''),
                  onSubmitted: (_) => _save(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('WEKA PIN')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown every time the app is (re)opened once a PIN already exists.
class EnterPinView extends StatefulWidget {
  final VoidCallback onSuccess;
  const EnterPinView({super.key, required this.onSuccess});

  @override
  State<EnterPinView> createState() => _EnterPinViewState();
}

class _EnterPinViewState extends State<EnterPinView> {
  final _pinCtrl = TextEditingController();
  String? _error;
  bool _checking = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pinCtrl.text.trim().isEmpty) return;
    setState(() { _checking = true; _error = null; });
    final ok = await PinService.instance.verifyPin(_pinCtrl.text.trim());
    if (!mounted) return;
    if (ok) {
      widget.onSuccess();
    } else {
      setState(() { _checking = false; _error = 'PIN si sahihi. Jaribu tena.'; });
      _pinCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 64, color: _kBrandColor),
                const SizedBox(height: 16),
                const Text('Weka PIN Kuingia', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'PIN', counterText: ''),
                  onSubmitted: (_) => _submit(),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _checking ? null : _submit,
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('INGIA')),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
