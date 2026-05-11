import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../domain/entities/education_entities.dart';

const String _productionBackendApiUrl =
    'https://student-system-h7pi.onrender.com/api/v1';

class BackendTeacherAccountService {
  BackendTeacherAccountService({Dio? dio, String? baseUrl})
    : _dio = dio ?? Dio(),
      _baseUrl = _normalizeBaseUrl(baseUrl ?? _defaultBackendBaseUrl());

  final Dio _dio;
  final String _baseUrl;

  Future<TeacherAccount> createTeacherAccount({
    required String accessToken,
    required TeacherAccount teacher,
    required String password,
    required String schoolName,
    required String districtName,
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .post<Map<String, dynamic>>(
            '$_baseUrl/admin/teachers',
            data: <String, dynamic>{
              'name': teacher.name,
              'email': teacher.email.trim().toLowerCase(),
              'password': password,
              'subject': teacher.subject,
              'assigned_class': teacher.assignedClass,
              'subjects': teacher.subjects,
              'assigned_classes': teacher.assignedClasses,
              'can_upload_results': teacher.canUploadResults,
              'can_edit_results': teacher.canEditResults,
              'can_register_students': teacher.canRegisterStudents,
              'can_download_results': teacher.canDownloadResults,
              'is_active': teacher.isActive,
              'school_name': schoolName,
              'district_name': districtName,
            },
            options: _jsonAuthOptions(accessToken),
          );
      return _teacherFromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw StateError(_backendErrorMessage(error));
    }
  }

  Future<TeacherAccount> updateTeacherAccount({
    required String accessToken,
    required TeacherAccount teacher,
  }) async {
    try {
      final Response<Map<String, dynamic>> response = await _dio
          .patch<Map<String, dynamic>>(
            '$_baseUrl/admin/teachers/${teacher.id}',
            data: <String, dynamic>{
              'name': teacher.name,
              'email': teacher.email.trim().toLowerCase(),
              'subject': teacher.subject,
              'assigned_class': teacher.assignedClass,
              'subjects': teacher.subjects,
              'assigned_classes': teacher.assignedClasses,
              'can_upload_results': teacher.canUploadResults,
              'can_edit_results': teacher.canEditResults,
              'can_register_students': teacher.canRegisterStudents,
              'can_download_results': teacher.canDownloadResults,
              'is_active': teacher.isActive,
            },
            options: _jsonAuthOptions(accessToken),
          );
      return _teacherFromJson(response.data ?? <String, dynamic>{});
    } on DioException catch (error) {
      throw StateError(_backendErrorMessage(error));
    }
  }

  Options _jsonAuthOptions(String accessToken) {
    return Options(
      contentType: Headers.jsonContentType,
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
  }
}

String _defaultBackendBaseUrl() {
  final String configured = const String.fromEnvironment(
    'BACKEND_API_URL',
  ).trim();
  if (configured.isNotEmpty) {
    return configured;
  }

  if (!kIsWeb) {
    return 'http://localhost:8000/api/v1';
  }

  final String host = Uri.base.host.toLowerCase();
  if (host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0') {
    return 'http://localhost:8000/api/v1';
  }

  return _productionBackendApiUrl;
}

String _normalizeBaseUrl(String baseUrl) {
  final String trimmed = baseUrl.trim();
  if (trimmed.endsWith('/')) {
    return trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}

String _backendErrorMessage(DioException error) {
  final Object? data = error.response?.data;
  if (data is Map && data['detail'] != null) {
    return data['detail'].toString();
  }
  if (data is String && data.trim().isNotEmpty) {
    return data.trim();
  }
  return error.message ?? 'FastAPI teacher account backend is unavailable.';
}

TeacherAccount _teacherFromJson(Map<String, dynamic> json) {
  return TeacherAccount(
    id: _stringValue(json['id']),
    name: _stringValue(json['name']),
    email: _stringValue(json['email']),
    subject: _stringValue(json['subject']),
    assignedClass: _stringValue(json['assigned_class']),
    subjects: _stringList(json['subjects']),
    assignedClasses: _stringList(json['assigned_classes']),
    canUploadResults: _boolValue(json['can_upload_results'], fallback: true),
    canEditResults: _boolValue(json['can_edit_results'], fallback: true),
    canRegisterStudents: _boolValue(
      json['can_register_students'],
      fallback: true,
    ),
    canDownloadResults: _boolValue(
      json['can_download_results'],
      fallback: true,
    ),
    isActive: _boolValue(json['is_active'], fallback: true),
  );
}

String _stringValue(Object? value) => value?.toString() ?? '';

bool _boolValue(Object? value, {required bool fallback}) {
  return value is bool ? value : fallback;
}

List<String> _stringList(Object? value) {
  if (value is! List) {
    return const <String>[];
  }
  return value
      .whereType<String>()
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);
}
