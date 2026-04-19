// Request signing and validation for added security.
// Signs requests with HMAC to ensure integrity and authenticity.

import 'dart:convert';
import 'package:crypto/crypto.dart';

class RequestSigner {
  final String _apiKey;
  final String _apiSecret;

  RequestSigner({required String apiKey, required String apiSecret})
    : _apiKey = apiKey,
      _apiSecret = apiSecret;

  /// Generate HMAC signature for request
  static String generateHmacSignature({
    required String method,
    required String path,
    required String secret,
    String? body,
    String? timestamp,
  }) {
    timestamp ??= DateTime.now().millisecondsSinceEpoch.toString();

    // Create canonical request string
    final canonicalRequest = '$method\n$path\n$timestamp';

    if (body != null && body.isNotEmpty) {
      final bodyHash = sha256.convert(utf8.encode(body)).toString();
      final signature = '$canonicalRequest\n$bodyHash';
      return _hmacSha256(signature, secret);
    }

    return _hmacSha256(canonicalRequest, secret);
  }

  /// Generate HMAC-SHA256 signature
  static String _hmacSha256(String message, String key) {
    // Convert key to bytes
    final keyBytes = utf8.encode(key);

    // Create HMAC using SHA256
    final hmac = Hmac(sha256, keyBytes);
    final digest = hmac.convert(utf8.encode(message));

    return digest.toString();
  }

  /// Add signature to request headers
  Map<String, String> signRequest({
    required String method,
    required String path,
    String? body,
    Map<String, String>? existingHeaders,
  }) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();

    final signature = generateHmacSignature(
      method: method,
      path: path,
      secret: _apiSecret,
      body: body,
      timestamp: timestamp,
    );

    final headers = existingHeaders ?? <String, String>{};
    headers['X-Request-Signature'] = signature;
    headers['X-Request-Timestamp'] = timestamp;
    headers['X-API-Key'] = _apiKey;

    return headers;
  }
}
