/// Report generation configuration
abstract class ReportConfig {
  /// Whether to use backend for report generation
  ///
  /// When true, reports are generated via the backend API.
  /// When false, reports are generated locally in the frontend.
  static const bool useBackendForReports = false;

  /// Backend API base URL for report generation
  ///
  /// Only used if useBackendForReports is true
  static const String backendReportApiUrl = 'http://localhost:8000/api/v1';

  /// Timeout duration for backend report requests (in seconds)
  static const int reportRequestTimeout = 60;
}
