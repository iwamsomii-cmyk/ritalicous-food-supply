import 'package:shared_preferences/shared_preferences.dart';

/// Handles saving and checking the app's security PIN.
/// The PIN itself is never stored in plain text - only a hash of it -
/// so it stays private even inside the device's local storage.
class PinService {
  PinService._();
  static final instance = PinService._();

  static const _pinHashKey = 'app_pin_hash';

  int _hash(String input) {
    int hash = 7;
    for (final codeUnit in input.codeUnits) {
      hash = (hash * 31 + codeUnit) & 0x7fffffff;
    }
    return hash;
  }

  /// Whether a PIN has already been set up on this device.
  Future<bool> hasPin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_pinHashKey);
  }

  /// Saves a new PIN (first-time setup, or a future PIN change).
  Future<void> setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_pinHashKey, _hash(pin));
  }

  /// Checks whether [pin] matches the one saved on this device.
  Future<bool> verifyPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_pinHashKey);
    if (stored == null) return false;
    return stored == _hash(pin);
  }
}
