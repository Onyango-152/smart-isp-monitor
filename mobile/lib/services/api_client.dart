import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../data/models/alert_model.dart';
import '../data/models/device_model.dart';
import '../data/models/metric_model.dart';
import '../data/models/task_model.dart';
import '../data/models/user_model.dart';

/// ApiClient is the single Dio instance used for all authenticated requests
/// after login.  It:
///   - Attaches the JWT access token on every request.
///   - Automatically refreshes the token on a 401 and retries once.
///   - Parses both plain lists and DRF-paginated `{count, results}` shapes.
///   - Throws [ApiException] with a human-readable message on failures.
class ApiClient {
  ApiClient._();

  static final Dio _dio = _buildDio();
  // Guard against concurrent refresh attempts
  static bool _isRefreshing = false;

  // ── Dio setup ─────────────────────────────────────────────────────────────

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl:        AppConstants.baseUrl,
        connectTimeout: Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          debugPrint('[API] ${options.method} ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          debugPrint('[API] ${response.statusCode} ${response.requestOptions.uri}');
          handler.next(response);
        },
        onError: (DioException error, handler) async {
          // Attempt token refresh on 401, then retry original request once.
          if (error.response?.statusCode == 401 && !_isRefreshing) {
            _isRefreshing = true;
            try {
              final refreshed = await _refreshToken();
              if (refreshed) {
                // Retry the original request with the new token.
                final opts = error.requestOptions;
                final newToken = await _getAccessToken();
                opts.headers['Authorization'] = 'Bearer $newToken';
                final response = await _dio.fetch(opts);
                _isRefreshing = false;
                return handler.resolve(response);
              }
            } catch (_) {
              // Refresh failed — fall through to propagate the original error.
            }
            _isRefreshing = false;
          }
          debugPrint(
            '[API] ERROR ${error.response?.statusCode} '
            '${error.requestOptions.uri}: ${error.response?.data}',
          );
          handler.next(error);
        },
      ),
    );

    return dio;
  }

  // ── Auth helpers ──────────────────────────────────────────────────────────

  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<bool> _refreshToken() async {
    final prefs  = await SharedPreferences.getInstance();
    final refresh = prefs.getString(AppConstants.refreshTokenKey);
    if (refresh == null) return false;

    try {
      // Use a plain Dio (no interceptors) to avoid recursive loops.
      final plain = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
      final res   = await plain.post(
        AppConstants.tokenRefreshEndpoint,
        data: {'refresh': refresh},
      );
      final newAccess = res.data['access'] as String?;
      if (newAccess == null) return false;
      await prefs.setString(AppConstants.tokenKey, newAccess);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Generic helpers ───────────────────────────────────────────────────────

  /// Parses a DRF response that is either a plain list or a paginated object.
  static List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data.containsKey('results')) {
      return data['results'] as List<dynamic>;
    }
    throw ApiException('Unexpected response shape: $data');
  }

  static Never _handleDioError(DioException e) {
    final status = e.response?.statusCode;
    final body   = e.response?.data;

    String message;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Request timed out. Check your connection.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Cannot reach the server. Are you online?';
    } else if (status == 400) {
      // Try to extract first validation message from DRF error body.
      if (body is Map) {
        final first = body.values.first;
        message = first is List ? first.first.toString() : first.toString();
      } else {
        message = 'Invalid request.';
      }
    } else if (status == 401) {
      message = 'Session expired. Please log in again.';
    } else if (status == 403) {
      message = 'You do not have permission to perform this action.';
    } else if (status == 404) {
      message = 'Resource not found.';
    } else {
      message = 'Server error ($status). Please try again.';
    }
    throw ApiException(message, statusCode: status);
  }

  // ── Devices ───────────────────────────────────────────────────────────────

  /// Returns all devices (admin / technician / manager).
  static Future<List<DeviceModel>> getDevices() async {
    try {
      final res  = await _dio.get(AppConstants.devicesEndpoint);
      return _asList(res.data).map((j) => DeviceModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  /// Returns only the devices assigned to the current customer.
  static Future<List<DeviceModel>> getMyDevices() async {
    try {
      final res = await _dio.get(AppConstants.myDevicesEndpoint);
      return _asList(res.data).map((j) => DeviceModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Metrics ───────────────────────────────────────────────────────────────

  /// Returns metrics, optionally filtered to one device.
  static Future<List<MetricModel>> getMetrics({int? deviceId}) async {
    try {
      final res = await _dio.get(
        AppConstants.metricsEndpoint,
        queryParameters: deviceId != null ? {'device': deviceId} : null,
      );
      return _asList(res.data).map((j) => MetricModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Alerts ────────────────────────────────────────────────────────────────

  /// Returns all alerts (admin / technician / manager).
  static Future<List<AlertModel>> getAlerts() async {
    try {
      final res  = await _dio.get(AppConstants.alertsEndpoint);
      return _asList(res.data).map((j) => AlertModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  /// Returns only alerts for the current customer's devices.
  static Future<List<AlertModel>> getMyAlerts() async {
    try {
      final res = await _dio.get(AppConstants.myAlertsEndpoint);
      return _asList(res.data).map((j) => AlertModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  /// Acknowledges an alert by ID.
  static Future<void> acknowledgeAlert(int id) async {
    try {
      await _dio.post('${AppConstants.alertsEndpoint}$id/acknowledge/');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  /// Resolves an alert by ID.
  static Future<void> resolveAlert(int id) async {
    try {
      await _dio.post('${AppConstants.alertsEndpoint}$id/resolve/');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Tasks ─────────────────────────────────────────────────────────────────

  /// Returns all monitoring tasks.
  static Future<List<TaskModel>> getTasks() async {
    try {
      final res  = await _dio.get(AppConstants.tasksEndpoint);
      return _asList(res.data).map((j) => TaskModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Clients ───────────────────────────────────────────────────────────────

  /// Returns the list of customer accounts (admin / manager only).
  static Future<List<UserModel>> getClients() async {
    try {
      final res  = await _dio.get(AppConstants.clientsEndpoint);
      return _asList(res.data).map((j) => UserModel.fromJson(j as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Dashboard ─────────────────────────────────────────────────────────────

  /// Returns the admin/manager dashboard summary.
  static Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final res = await _dio.get(AppConstants.dashboardEndpoint);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  /// Returns the simplified customer dashboard.
  static Future<Map<String, dynamic>> getCustomerDashboard() async {
    try {
      final res = await _dio.get(AppConstants.customerDashboardEndpoint);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Generic GET (for ad-hoc calls) ────────────────────────────────────────

  static Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await _dio.get(path, queryParameters: queryParameters);
      return res.data;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<dynamic> post(
    String path, {
    dynamic data,
  }) async {
    try {
      final res = await _dio.post(path, data: data);
      return res.data;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<dynamic> patch(
    String path, {
    dynamic data,
  }) async {
    try {
      final res = await _dio.patch(path, data: data);
      return res.data;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<void> delete(String path) async {
    try {
      await _dio.delete(path);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }
}

/// Thrown by [ApiClient] when a request fails.
class ApiException implements Exception {
  final String message;
  final int?   statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
