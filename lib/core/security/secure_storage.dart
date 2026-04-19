// Secure token storage for Flutter using flutter_secure_storage.
// Ensures tokens are stored in the device's secure storage.

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const String _accessTokenKey = 'auth_access_token';
const String _refreshTokenKey = 'auth_refresh_token';
const String _deviceIdKey = 'device_identifier';

class SecureTokenStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm:
          KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
      resetOnError: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  /// Save access token to secure storage
  static Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  /// Retrieve access token from secure storage
  static Future<String?> getAccessToken() async {
    return await _storage.read(key: _accessTokenKey);
  }

  /// Save refresh token to secure storage
  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  /// Retrieve refresh token from secure storage
  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  /// Save device identifier
  static Future<void> saveDeviceId(String deviceId) async {
    await _storage.write(key: _deviceIdKey, value: deviceId);
  }

  /// Retrieve device identifier
  static Future<String?> getDeviceId() async {
    return await _storage.read(key: _deviceIdKey);
  }

  /// Clear all tokens (logout)
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Clear only tokens
  static Future<void> clearTokens() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
