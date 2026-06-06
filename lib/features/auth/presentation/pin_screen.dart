import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/app_logo.dart';
import '../providers/auth_providers.dart';

enum _Stage {
  // Setup (sin PIN previo)
  setupNew,
  setupConfirm,
  // Unlock (PIN ya configurado, al abrir la app)
  unlock,
  // Change PIN (desde perfil)
  changeCurrent,
  changeNew,
  changeConfirm,
}

class PinScreen extends ConsumerStatefulWidget {
  /// `true` cuando se abre desde el perfil para cambiar el PIN.
  /// `false` cuando se usa como pantalla de bloqueo al iniciar.
  const PinScreen({super.key, this.forChange = false});

  final bool forChange;

  @override
  ConsumerState<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends ConsumerState<PinScreen> {
  static const _pinLength = 6;
  static const _maxAttempts = 5;

  String _pin = '';
  _Stage _stage = _Stage.unlock;
  String? _firstEntry;
  String? _errorText;
  int _failedAttempts = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.forChange) {
      _stage = _Stage.changeCurrent;
    } else {
      final s = ref.read(authStateProvider);
      _stage = s.needsSetup ? _Stage.setupNew : _Stage.unlock;
    }
  }

  void _onDigit(String d) {
    if (_busy || _pin.length >= _pinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _errorText = null;
    });
    if (_pin.length == _pinLength) {
      _onComplete();
    }
  }

  void _onBackspace() {
    if (_busy || _pin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorText = null;
    });
  }

  Future<void> _onComplete() async {
    if (_busy) return;
    final pin = _pin;
    setState(() => _busy = true);
    try {
      switch (_stage) {
        case _Stage.setupNew:
          setState(() {
            _firstEntry = pin;
            _stage = _Stage.setupConfirm;
            _pin = '';
          });
          break;

        case _Stage.setupConfirm:
          if (pin == _firstEntry) {
            await ref.read(authControllerProvider.notifier).setupPin(pin);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN creado con éxito')),
              );
            }
          } else {
            setState(() {
              _stage = _Stage.setupNew;
              _firstEntry = null;
              _pin = '';
              _errorText = 'Los PINs no coinciden. Inténtalo de nuevo.';
            });
          }
          break;

        case _Stage.unlock:
          final ok = await ref.read(authControllerProvider.notifier).unlock(pin);
          if (!ok) {
            _failedAttempts++;
            if (_failedAttempts >= _maxAttempts) {
              setState(() {
                _pin = '';
                _errorText = 'Demasiados intentos. Cierra y abre la app para continuar.';
              });
              return;
            }
            setState(() {
              _pin = '';
              _errorText = 'PIN incorrecto (intento $_failedAttempts de $_maxAttempts)';
            });
          }
          break;

        case _Stage.changeCurrent:
          final valid = await ref
              .read(authControllerProvider.notifier)
              .verifyOnly(pin);
          if (valid) {
            setState(() {
              _stage = _Stage.changeNew;
              _pin = '';
            });
          } else {
            setState(() {
              _pin = '';
              _errorText = 'PIN actual incorrecto';
            });
          }
          break;

        case _Stage.changeNew:
          setState(() {
            _firstEntry = pin;
            _stage = _Stage.changeConfirm;
            _pin = '';
          });
          break;

        case _Stage.changeConfirm:
          if (pin == _firstEntry) {
            await ref.read(authControllerProvider.notifier).setPinDirect(pin);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN actualizado con éxito')),
              );
              Navigator.of(context).pop(true);
            }
          } else {
            setState(() {
              _stage = _Stage.changeNew;
              _firstEntry = null;
              _pin = '';
              _errorText = 'Los PINs no coinciden. Inténtalo de nuevo.';
            });
          }
          break;
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  (String, String) _headline() {
    switch (_stage) {
      case _Stage.setupNew:
        return ('Crea tu PIN', 'Elige 6 dígitos para proteger +Balance');
      case _Stage.setupConfirm:
        return ('Confirma tu PIN', 'Vuelve a escribir los 6 dígitos');
      case _Stage.unlock:
        return ('Bienvenido de vuelta', 'Ingresa tu PIN de 6 dígitos');
      case _Stage.changeCurrent:
        return ('Cambiar PIN', 'Ingresa tu PIN actual');
      case _Stage.changeNew:
        return ('Nuevo PIN', 'Elige los 6 dígitos');
      case _Stage.changeConfirm:
        return ('Confirma el nuevo PIN', 'Vuelve a escribir los 6 dígitos');
    }
  }

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _headline();
    final isLockScreen = !widget.forChange;

    return PopScope(
      canPop: !isLockScreen,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                if (isLockScreen) ...[
                  const Center(child: AppLogo(size: 72)),
                  const SizedBox(height: 24),
                ],
                Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey)),
                const SizedBox(height: 36),
                _PinDots(
                    length: _pinLength,
                    filled: _pin.length,
                    error: _errorText != null),
                const SizedBox(height: 16),
                SizedBox(
                  height: 20,
                  child: _errorText == null
                      ? const SizedBox.shrink()
                      : Text(_errorText!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),
                const Spacer(),
                _NumPad(onDigit: _onDigit, onBackspace: _onBackspace),
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.filled, required this.error});
  final int length;
  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(length, (i) {
        final filledDot = i < filled;
        return Container(
          width: 16,
          height: 16,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filledDot
                ? (error ? Colors.redAccent : color)
                : Colors.transparent,
            border: Border.all(
              color: error
                  ? Colors.redAccent
                  : (filledDot ? color : Colors.grey.shade400),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

class _NumPad extends StatelessWidget {
  const _NumPad({required this.onDigit, required this.onBackspace});
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    Widget padButton(Widget child, VoidCallback onTap) {
      final color = Theme.of(context).colorScheme.primary;
      return Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Center(child: child),
        ),
      );
    }

    Widget digit(String d) => padButton(
          Text(d, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600)),
          () => onDigit(d),
        );

    Widget backspace() => padButton(
          const Icon(Icons.backspace_outlined, size: 24),
          onBackspace,
        );

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 1.6,
      children: [
        digit('1'), digit('2'), digit('3'),
        digit('4'), digit('5'), digit('6'),
        digit('7'), digit('8'), digit('9'),
        const SizedBox.shrink(), digit('0'), backspace(),
      ],
    );
  }
}
