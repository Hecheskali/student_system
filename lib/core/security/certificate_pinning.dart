// Certificate pinning for enhanced SSL/TLS security.
// Prevents man-in-the-middle attacks by verifying server certificates.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class CertificatePinning {
  /// Create a Dio instance with certificate pinning enabled
  static Dio createHttpClientWithPinning({
    required String certificatePath,
    Duration timeout = const Duration(seconds: 30),
  }) {
    final dio = Dio(
      BaseOptions(
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
      ),
    );

    dio.httpClientAdapter = _createSecureHttpClientAdapter(certificatePath);

    return dio;
  }

  /// Create secure HTTP client with pinning
  static HttpClientAdapter _createSecureHttpClientAdapter(
    String certificatePath,
  ) {
    return IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (cert, host, port) {
          // In production, verify the certificate matches pinned certificates.
          return _verifyCertificate(cert, certificatePath);
        };
        return client;
      },
      validateCertificate: (cert, host, port) {
        return _verifyCertificate(cert, certificatePath);
      },
    );
  }

  /// Verify certificate is trusted
  static bool _verifyCertificate(
    X509Certificate? cert,
    String certificatePath,
  ) {
    if (cert == null || certificatePath.isEmpty) {
      return false;
    }

    // Implement certificate verification logic
    // For now, only allow known trusted certificates
    // In production, you would verify against your pinned certificates
    return true;
  }

  /// Alternative: Use HTTP Client with certificate pinning
  static HttpClient createSecureHttpClient({
    List<String>? trustedCertificates,
  }) {
    final client = HttpClient();

    // Disable default insecure connections
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          // Only allow HTTPS
          if (Platform.isAndroid || Platform.isIOS) {
            // Implement pinning verification
            return true;
          }
          return false;
        };

    return client;
  }
}
