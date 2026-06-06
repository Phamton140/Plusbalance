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
    final value = await _storage.read(key: _pinKey);
    return value != null && value.isNotEmpty;
  }

  Future<void> setPin(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  Future<bool> verifyPin(String pin) async {
    final stored = await _storage.read(key: _pinKey);
    if (stored == null) return false;
    return stored == pin;
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinKey);
  }
}
