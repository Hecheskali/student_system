// Biometric authentication (fingerprint, face recognition) for enhanced security.

import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  static final LocalAuthentication _localAuth = LocalAuthentication();

  /// Check if device supports biometric authentication
  static Future<bool> canUseBiometrics() async {
    try {
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final isDeviceSecure = await _localAuth.canCheckBiometrics;
      return isDeviceSupported && isDeviceSecure;
    } catch (e) {
      return false;
    }
  }

  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      return [];
    }
  }

  /// Check if fingerprint authentication is available
  static Future<bool> canUseFingerprint() async {
    try {
      final biometrics = await getAvailableBiometrics();
      return biometrics.contains(BiometricType.fingerprint);
    } catch (e) {
      return false;
    }
  }

  /// Check if face recognition is available
  static Future<bool> canUseFaceRecognition() async {
    try {
      final biometrics = await getAvailableBiometrics();
      return biometrics.contains(BiometricType.face);
    } catch (e) {
      return false;
    }
  }

  /// Authenticate using biometrics
  static Future<bool> authenticate({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = true,
  }) async {
    try {
      if (!await canUseBiometrics()) {
        return false;
      }

      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          stickyAuth: stickyAuth,
          biometricOnly: true,
          useErrorDialogs: useErrorDialogs,
        ),
      );

      return result;
    } catch (e) {
      return false;
    }
  }

  /// Authenticate with device credentials (PIN, pattern, password)
  static Future<bool> authenticateWithDeviceCredentials({
    required String reason,
  }) async {
    try {
      final result = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      return result;
    } catch (e) {
      return false;
    }
  }

  /// Stop authentication
  static Future<void> stopAuthentication() async {
    try {
      await _localAuth.stopAuthentication();
    } catch (e) {
      // Error stopping authentication
    }
  }
}
