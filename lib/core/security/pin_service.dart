import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Servicio responsable de almacenar y verificar el PIN de acceso a la app.
///
/// El PIN se persiste cifrado por el sistema operativo (Keychain en iOS,
/// EncryptedSharedPreferences en Android) a través de `flutter_secure_storage`.
class PinService {
  PinService._();
  static final PinService instance = PinService._();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const _pinKey = 'app_lock_pin';

  Future<bool> isPinSet() async {
    try {
      final value = await _storage.read(key: _pinKey);
      return value != null && value.isNotEmpty;
    } catch (e, st) {
      debugPrint('PinService.isPinSet error: $e\n$st');
      return false;
    }
  }

  Future<void> setPin(String pin) async {
    try {
      await _storage.write(key: _pinKey, value: pin);
    } catch (e, st) {
      debugPrint('PinService.setPin error: $e\n$st');
      rethrow;
    }
  }

  Future<bool> verifyPin(String pin) async {
    try {
      final stored = await _storage.read(key: _pinKey);
      if (stored == null) return false;
      return stored == pin;
    } catch (e, st) {
      debugPrint('PinService.verifyPin error: $e\n$st');
      return false;
    }
  }

  Future<void> removePin() async {
    try {
      await _storage.delete(key: _pinKey);
    } catch (e, st) {
      debugPrint('PinService.removePin error: $e\n$st');
    }
  }
}
