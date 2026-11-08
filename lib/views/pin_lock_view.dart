import 'package:flutter/material.dart';
import '../services/pin_service.dart';

const _kBrandColor = Color(0xFF205080);
const _kBg = Color(0xFFF4F2FA);
const _kLogoGradientStart = Color(0xFF4CE58F);
const _kLogoGradientEnd = Color(0xFF1E9BA8);
const _kElapsLogoAsset = 'assets/elaps_logo.png';

/// Brand mark shown at the top of the PIN screens: a lock silhouette
/// "painted" with the e-LAPS logo, on a soft rounded backing that echoes
/// the logo's own green-to-teal gradient.
class _BrandLockMark extends StatelessWidget {
  const _BrandLockMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [_kLogoGradientStart, _kLogoGradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: _kLogoGradientEnd.withOpacity(0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(_kElapsLogoAsset, height: 46, fit: BoxFit.contain),
          const SizedBox(height: 6),
          const Icon(Icons.lock, size: 22, color: Colors.white),
        ],
      ),
    );
  }
}

/// Subtle "Powered by e-LAPS" watermark, tucked under the primary action
/// button so it reads as a brand credit rather than another button.
class _PoweredByBadge extends StatelessWidget {
  const _PoweredByBadge();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.45,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'powered by ',
            style: TextStyle(fontSize: 11, color: _kBrandColor.withOpacity(0.8), letterSpacing: 0.3),
          ),
          Text(
            'e-LAPS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kLogoGradientEnd,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

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
      setState(() => _error = 'Enter a PIN with at least 4 digits.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match. Try again.');
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
                const _BrandLockMark(),
                const SizedBox(height: 16),
                const Text('Set Security PIN', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 8),
                const Text('This PIN will be required every time you open the app.', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'New PIN', counterText: ''),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(labelText: 'Confirm PIN', counterText: ''),
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
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('SET PIN')),
                  ),
                ),
                const SizedBox(height: 16),
                const _PoweredByBadge(),
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
      setState(() { _checking = false; _error = 'Incorrect PIN. Try again.'; });
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
                const _BrandLockMark(),
                const SizedBox(height: 16),
                const Text('Enter PIN to Continue', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    child: const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('ENTER')),
                  ),
                ),
                const SizedBox(height: 16),
                const _PoweredByBadge(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
