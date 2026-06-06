import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/pin_service.dart';

/// Estados posibles del candeo de la app.
enum AuthStatus { loading, needsSetup, locked, unlocked }

@immutable
class AuthState {
  final AuthStatus status;
  const AuthState(this.status);

  bool get isLoading => status == AuthStatus.loading;
  bool get isAuthenticated => status == AuthStatus.unlocked;
  bool get isPinSet => status == AuthStatus.locked;
  bool get needsSetup => status == AuthStatus.needsSetup;
}

class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Disparamos la carga del estado del PIN en background
    Future.microtask(_bootstrap);
    return const AuthState(AuthStatus.loading);
  }

  Future<void> _bootstrap() async {
    final hasPin = await PinService.instance.isPinSet();
    state = AuthState(hasPin ? AuthStatus.locked : AuthStatus.needsSetup);
  }

  Future<bool> setupPin(String pin) async {
    await PinService.instance.setPin(pin);
    state = const AuthState(AuthStatus.unlocked);
    return true;
  }

  Future<bool> unlock(String pin) async {
    final ok = await PinService.instance.verifyPin(pin);
    if (ok) {
      state = const AuthState(AuthStatus.unlocked);
    }
    return ok;
  }

  Future<void> lock() async {
    final hasPin = await PinService.instance.isPinSet();
    state = AuthState(hasPin ? AuthStatus.locked : AuthStatus.needsSetup);
  }

  /// Verifica un PIN contra el almacenado sin cambiar el estado de auth.
  Future<bool> verifyOnly(String pin) async {
    return PinService.instance.verifyPin(pin);
  }

  /// Reemplaza el PIN actual directamente, sin requerir el actual.
  Future<void> setPinDirect(String pin) async {
    await PinService.instance.setPin(pin);
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

final authStateProvider = Provider<AuthState>((ref) {
  return ref.watch(authControllerProvider);
});
