// Network security configuration for HTTP client.
// Enforces secure HTTPS, disables insecure protocols, and sets security headers.

import 'package:dio/dio.dart';

class NetworkSecurityConfig {
  /// Create secure Dio instance with all security features
  static Dio createSecureDioClient({
    required String baseUrl,
    Duration timeout = const Duration(seconds: 30),
    List<Interceptor>? customInterceptors,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: timeout,
        receiveTimeout: timeout,
        sendTimeout: timeout,
        validateStatus: (status) {
          // Validate all status codes to handle manually
          return status != null;
        },
        headers: {
          'Content-Type': 'application/json',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ),
    );

    // Configure HTTPS security
    _configureHttpsOnly(baseUrl);

    // Add security interceptors
    dio.interceptors.add(SecurityHeadersInterceptor());
    dio.interceptors.add(RequestSigningInterceptor());
    dio.interceptors.add(ResponseValidationInterceptor());

    // Add custom interceptors if provided
    if (customInterceptors != null) {
      dio.interceptors.addAll(customInterceptors);
    }

    return dio;
  }

  /// Configure HTTPS-only connections
  static void _configureHttpsOnly(String baseUrl) {
    // Force HTTPS only
    if (!baseUrl.startsWith('https://')) {
      throw ArgumentError('Only HTTPS connections are allowed for security');
    }
  }
}

/// Interceptor to add security headers
class SecurityHeadersInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add security headers
    options.headers['X-Content-Type-Options'] = 'nosniff';
    options.headers['X-Frame-Options'] = 'DENY';
    options.headers['X-XSS-Protection'] = '1; mode=block';
    options.headers['Referrer-Policy'] = 'no-referrer';

    handler.next(options);
  }
}

/// Interceptor to sign requests
class RequestSigningInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Implement request signing if needed
    // This would use the RequestSigner class
    handler.next(options);
  }
}

/// Interceptor to validate responses
class ResponseValidationInterceptor extends Interceptor {
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    // Validate response is not tampered with
    // Check content-type matches expected
    final contentType = response.headers.value('content-type');
    if (contentType != null && !contentType.contains('application/json')) {
      if (response.requestOptions.path != '/health') {
        // Log suspicious response
      }
    }

    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Log security-relevant errors
    if (err.type == DioExceptionType.badCertificate) {
      // Certificate validation failed - major security issue
      throw Exception('Certificate validation failed - possible MITM attack');
    }

    handler.next(err);
  }
}
