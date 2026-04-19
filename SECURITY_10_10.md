# 10/10 Security & Authentication Implementation Guide

## Overview

This guide covers the comprehensive security implementation for the Student System app, protecting against common hacker attacks with advanced features.

---

## Backend Security (FastAPI + Python)

### 1. **Authentication & Authorization** ✅

- **Password Hashing**: Argon2 via `pwdlib` (industry-standard)
- **JWT Tokens**: HS512 algorithm with secure expiration
- **Refresh Tokens**: 7-day rotation for access tokens
- **2FA Support**: TOTP, Email OTP, SMS OTP, Backup codes
- **Role-Based Access Control (RBAC)**: Admin, Academic Master, Teacher

**Location**: `backend/app/core/security.py`, `backend/app/core/refresh_tokens.py`

### 2. **Advanced Encryption** ✅

- **At-Rest Encryption**: Fernet cipher with PBKDF2 key derivation
- **Sensitive Data**: Phone numbers, personal IDs encrypted in database
- **Compliance**: AES-256-equivalent security

**Location**: `backend/app/core/encryption.py`

**Usage**:

```python
from app.core.encryption import encryption_manager

encrypted = encryption_manager.encrypt("sensitive_data")
decrypted = encryption_manager.decrypt(encrypted)
```

### 3. **CSRF/XSRF Protection** ✅

- **Double-Submit Cookie Pattern**: Token + Cookie validation
- **Session Binding**: Tokens bound to specific sessions
- **Constant-Time Comparison**: Prevents timing attacks

**Location**: `backend/app/core/csrf.py`

### 4. **Input Validation & Sanitization** ✅ **Protects Against**

- **SQL Injection**: Regex patterns detect common SQLi attempts
- **XSS Attacks**: HTML/JavaScript injection detection
- **Command Injection**: Shell metacharacter detection
- **Unicode Attacks**: Normalized input validation

**Location**: `backend/app/middleware/input_validation.py`

### 5. **Rate Limiting** ✅

- **Login Attempts**: 5 attempts per 5 minutes (configurable)
- **Account Lockout**: 15-minute lockout after failed attempts
- **Per-IP Throttling**: Prevents brute force attacks
- **Configurable Windows**: Adjust limits per endpoint

**Location**: `backend/app/core/rate_limit.py`

### 6. **Security Headers** ✅

| Header | Value | Protection |
| --- | --- | --- |
| X-Content-Type-Options | nosniff | MIME sniffing attacks |
| X-Frame-Options | DENY | Clickjacking attacks |
| Content-Security-Policy | strict | XSS and data injection |
| Strict-Transport-Security | 2 years | SSL/TLS downgrade attacks |
| Referrer-Policy | no-referrer | Information leakage |
| Permissions-Policy | restrictive | Unauthorized API access |

**Location**: `backend/app/middleware/security_headers.py`

### 7. **CORS Security** ✅

- **Allowlist**: Only specified origins allowed
- **Credentials**: Disabled by default
- **Methods**: Restricted to essential operations
- **Headers**: Whitelisted for authorization

### 8. **Password Policy** ✅

- **Minimum Length**: 12 characters
- **Complexity**: Requires uppercase, numbers, special characters
- **Pattern Detection**: Blocks sequential/repeated characters
- **Common Words**: Prevents dictionary attacks
- **Expiration**: 90-day rotation (configurable)

**Location**: `backend/app/core/password_policy.py`

### 9. **Device Fingerprinting & Anomaly Detection** ✅

- **Fingerprinting**: User-Agent, language, encoding hashing
- **Impossible Travel**: Detects geographically impossible logins
- **New Device Detection**: Flags unknown devices
- **Session Binding**: Prevents token theft

**Location**: `backend/app/core/device_fingerprint.py`

### 10. **Audit Logging** ✅

- **All Access**: Logged with IP, timestamp, action
- **Failed Attempts**: Tracked for security analysis
- **Admin Actions**: Complete audit trail
- **Retention**: Long-term storage for compliance

**Location**: `backend/app/services/audit.py`

---

## Frontend Security (Flutter/Dart)

### 1. **Secure Token Storage** ✅

- **Platform Integration**:
  - **iOS**: Keychain with device-only accessibility
  - **Android**: Keystore with AES-GCM encryption
- **No SharedPreferences**: Tokens never in plain text
- **Automatic Cleanup**: Tokens cleared on logout

**Location**: `lib/core/security/secure_storage.dart`

**Usage**:

```dart
await SecureTokenStorage.saveAccessToken(token);
final token = await SecureTokenStorage.getAccessToken();
```

### 2. **Certificate Pinning** ✅

- **SSL/TLS Validation**: Custom certificate verification
- **MITM Prevention**: Only accept pinned certificates
- **Dynamic Updates**: Support for certificate rotation

**Location**: `lib/core/security/certificate_pinning.dart`

### 3. **Biometric Authentication** ✅

- **Fingerprint Support**: iOS/Android
- **Face Recognition**: iPhone X+ support
- **Fallback**: Device PIN/pattern as backup
- **Secure Enclave**: Hardware-backed authentication

**Location**: `lib/core/security/biometric_auth.dart`

**Usage**:

```dart
if (await BiometricAuth.canUseBiometrics()) {
  final result = await BiometricAuth.authenticate(
    reason: 'Authenticate to access your account',
  );
}
```

### 4. **Request Signing** ✅

- **HMAC-SHA256**: Sign all requests
- **Timestamp**: Prevents replay attacks
- **Body Hashing**: Detects tampering
- **API Key Rotation**: Support for key management

**Location**: `lib/core/security/request_signer.dart`

### 5. **Network Security** ✅

- **HTTPS Only**: No fallback to HTTP
- **Security Interceptors**: Validate all responses
- **Header Validation**: Detect suspicious responses
- **Certificate Errors**: Proper error handling

**Location**: `lib/core/security/network_security.dart`

**Usage**:

```dart
final dio = NetworkSecurityConfig.createSecureDioClient(
  baseUrl: 'https://api.yourdomain.com',
);
```

### 6. **SQL Injection Prevention** ✅

- **Parameterized Queries**: SQLite only accepts parameterized queries
- **Input Validation**: All user input validated before DB queries
- **Type Safety**: Dart type system prevents injection

### 7. **XSS Prevention** ✅

- **N/A for Flutter**: Not vulnerable to XSS (not HTML-based)
- **WebView Security**: If web components used, proper escaping

### 8. **Code Obfuscation** ✅

- **Dart Obfuscation**: Enable in release builds
- **String Encryption**: Sensitive strings can be encrypted
- **Symbol Stripping**: Remove debugging information

**Build Command**:

```bash
flutter build apk --obfuscate --split-debug-info=./debug_info
flutter build ios --obfuscate --split-debug-info=./debug_info
```

### 9. **Secure Logging** ✅

- **No Sensitive Data**: Never log passwords, tokens, PII
- **Log Level**: Debug logs disabled in production
- **Log Rotation**: Prevent excessive disk usage

### 10. **Deep Linking Security** ✅

- **URL Validation**: Verify deep links are from trusted sources
- **Parameter Validation**: All parameters validated
- **Redirect Prevention**: No arbitrary redirects

---

## Environment Setup

### Backend (.env Configuration)

```sh
# Basic
APP_NAME="Student System API"
APP_ENV=production
APP_DEBUG=false

# Security
JWT_SECRET_KEY="<random-64-char-key>"
ENABLE_HTTPS_REDIRECT=true
ENABLE_HSTS=true
ENABLE_2FA=true
REQUIRE_2FA_FOR_ADMINS=true

# Password Policy
PASSWORD_MIN_LENGTH=12
PASSWORD_REQUIRE_SPECIAL=true
PASSWORD_REQUIRE_NUMBERS=true
PASSWORD_REQUIRE_UPPERCASE=true
PASSWORD_EXPIRY_DAYS=90

# Rate Limiting
LOGIN_RATE_LIMIT_ATTEMPTS=5
LOGIN_RATE_LIMIT_WINDOW_SECONDS=300
ACCOUNT_LOCKOUT_MINUTES=15

# CORS
ALLOWED_ORIGINS="https://yourdomain.com"
TRUSTED_HOSTS="yourdomain.com"

# Audit & Detection
ENABLE_AUDIT_LOGGING=true
ENABLE_ANOMALY_DETECTION=true
ENABLE_DEVICE_FINGERPRINTING=true
```

### Dependencies

**Backend**:

```toml
cryptography>=41.0.0       # Encryption
pyotp>=2.9.0              # 2FA/TOTP
pwdlib[argon2]>=0.3.0     # Password hashing
pyjwt[crypto]>=2.10.1     # JWT tokens
```

**Frontend (add to pubspec.yaml)**:

```yaml
dependencies:
  flutter_secure_storage: ^9.0.0
  local_auth: ^2.1.0
  dio: ^5.7.0
  crypto: ^3.0.0
```

---

## Common Attack Prevention Matrix

| Attack Type | Backend Protection | Frontend Protection | Status |
| --- | --- | --- | --- |
| SQL Injection | Input sanitization, parameterized queries | Parameterized DB | ✅ |
| XSS | CSP headers, input validation | N/A (Flutter) | ✅ |
| CSRF | CSRF tokens, SameSite cookies | Request signing | ✅ |
| Brute Force | Rate limiting, account lockout | Biometric 2FA | ✅ |
| Man-in-the-Middle | HTTPS/TLS, HSTS | Certificate pinning | ✅ |
| Session Hijacking | JWT expiration, refresh tokens | Secure storage | ✅ |
| Replay Attack | Timestamps, request signing | Nonce validation | ✅ |
| Privilege Escalation | RBAC, JWT validation | Token verification | ✅ |
| DDoS | Rate limiting, timeout | exponential backoff | ✅ |
| Data Breach | Encryption at rest | Secure storage | ✅ |

---

## Deployment Checklist

- [ ] Generate 64-character random JWT_SECRET_KEY
- [ ] Set `APP_ENV=production` and `APP_DEBUG=false`
- [ ] Enable HTTPS redirect and HSTS
- [ ] Configure valid ALLOWED_ORIGINS
- [ ] Set strong password policy in config
- [ ] Enable 2FA for all admin accounts
- [ ] Configure email/SMS for OTP delivery
- [ ] Enable audit logging
- [ ] Set up log rotation and monitoring
- [ ] Configure database backups with encryption
- [ ] Update Flutter app with production API URL
- [ ] Enable code obfuscation in release builds
- [ ] Set up SSL certificate monitoring

---

## Testing Security

### Backend Security Tests

```bash
# Test SQL injection prevention
curl -X POST http://localhost:8000/api/v1/admin/users \
  -H "Content-Type: application/json" \
  -d '{"email": "test@test.com\"; DROP TABLE users; --"}'

# Test rate limiting
for i in {1..10}; do curl -X POST http://localhost:8000/api/v1/auth/login; done

# Test password policy
curl -X POST http://localhost:8000/api/v1/admin/users \
  -H "Content-Type: application/json" \
  -d '{"password": "weak"}'
```

### Frontend Security Tests

- [ ] Test secure storage (tokens not in SharedPreferences)
- [ ] Test biometric authentication
- [ ] Test certificate pinning rejection of invalid certs
- [ ] Test HTTPS-only enforcement
- [ ] Test token refresh flow
- [ ] Test logout clears all tokens
- [ ] Test deep link validation

---

## Monitoring & Alerts

Set up alerts for:

- Multiple failed login attempts from same IP
- Impossible travel detection
- New device access
- Admin action audit logs
- Rate limit triggers
- Password policy violations
- Certificate errors
- Unusual data access patterns

---

## Support & Resources

- **OWASP Top 10**: <https://owasp.org/www-project-top-ten/>
- **NIST Cybersecurity**: <https://www.nist.gov/cybersecurity>
- **Flutter Security**: <https://flutter.dev/docs/testing/security>
- **FastAPI Security**: <https://fastapi.tiangolo.com/advanced/security/>

---

## Compliance

This security implementation helps meet requirements for:

- **GDPR**: Data protection and encryption
- **HIPAA**: Access controls and audit logging
- **SOC 2**: Security controls and monitoring
- **ISO 27001**: Information security management

---

**Last Updated**: April 2026  
**Security Level**: 10/10
