import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../services/biometric_service.dart';

enum UnlockMethod { password, biometric }

final biometricAvailableProvider = FutureProvider<bool>((ref) async {
  return BiometricService().isBiometricAvailable();
});

final unlockMethodProvider = StateNotifierProvider<UnlockMethodNotifier, UnlockMethod>((ref) {
  return UnlockMethodNotifier();
});

class UnlockMethodNotifier extends StateNotifier<UnlockMethod> {
  UnlockMethodNotifier() : super(UnlockMethod.password) {
    _load();
  }

  Future<void> _load() async {
    final enabled = await BiometricService().isBiometricEnabled();
    state = enabled ? UnlockMethod.biometric : UnlockMethod.password;
  }

  Future<void> setMethod(UnlockMethod method) async {
    await BiometricService().setBiometricEnabled(method == UnlockMethod.biometric);
    state = method;
  }
}

/// Convenience provider: true when biometric is the selected unlock method.
final biometricEnabledProvider = Provider<bool>((ref) {
  return ref.watch(unlockMethodProvider) == UnlockMethod.biometric;
});
