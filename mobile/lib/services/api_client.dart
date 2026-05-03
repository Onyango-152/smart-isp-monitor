import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import '../data/models/alert_model.dart';
import '../data/models/device_model.dart';
import '../data/models/metric_model.dart';
import '../data/models/metric_type_model.dart';
import '../data/models/metric_threshold_model.dart';
import '../data/models/metric_prediction_model.dart';
import '../data/models/task_model.dart';
import '../data/models/user_model.dart';
import '../data/models/organisation_model.dart';
import '../data/models/invitation_model.dart';

/// ApiClient is the single Dio instance used for all authenticated requests.
class ApiClient {
  ApiClient._();

  static final Dio _dio = _buildDio();
  static bool _isRefreshing = false;
  static Completer<void>? _refreshCompleter;

  // ── Dio setup ───────────────────────────────────────────────────────────

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
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
          if (error.response?.statusCode == 401) {
            if (_isRefreshing) {
              try {
                await _refreshCompleter?.future;
                final opts = error.requestOptions;
                final newToken = await _getAccessToken();
                if (newToken != null) {
                  opts.headers['Authorization'] = 'Bearer $newToken';
                }
                final response = await _dio.fetch(opts);
                return handler.resolve(response);
              } catch (_) {
                // Refresh failed — fall through to propagate error.
              }
            } else {
              _isRefreshing = true;
              _refreshCompleter = Completer<void>();
              try {
                final refreshed = await _refreshToken();
                if (refreshed) {
                  _refreshCompleter?.complete();
                  final opts = error.requestOptions;
                  final newToken = await _getAccessToken();
                  if (newToken != null) {
                    opts.headers['Authorization'] = 'Bearer $newToken';
                  }
                  final response = await _dio.fetch(opts);
                  return handler.resolve(response);
                }
                _refreshCompleter?.completeError(Exception('Token refresh failed'));
              } catch (_) {
                _refreshCompleter?.completeError(Exception('Token refresh failed'));
                // Refresh failed — fall through to propagate error.
              } finally {
                _isRefreshing = false;
              }
            }
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

  // ── Auth helpers ─────────────────────────────────────────────────────────

  static Future<String?> _getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<bool> _refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(AppConstants.refreshTokenKey);
    if (refresh == null) return false;

    try {
      final plain = Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
      final res = await plain.post(
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

  // ── Generic helpers ──────────────────────────────────────────────────────

  static List<dynamic> _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map && data.containsKey('results')) {
      return data['results'] as List<dynamic>;
    }
    throw ApiException('Unexpected response shape: $data');
  }

  static Never _handleDioError(DioException e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;

    String message;
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      message = 'Request timed out. Check your connection.';
    } else if (e.type == DioExceptionType.connectionError) {
      message = 'Cannot reach the server. Are you online?';
    } else if (status == 400) {
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

  static String _normalizeStatus(String status) {
    if (status == AppConstants.statusUnknown) {
      return AppConstants.statusOffline;
    }
    if (status == AppConstants.statusDegraded) {
      return 'unreachable';
    }
    return status;
  }

  // ── Devices ──────────────────────────────────────────────────────────────

  static Future<List<DeviceModel>> getDevices() async {
    try {
      final res = await _dio.get(AppConstants.devicesEndpoint);
      return _asList(res.data)
          .map((j) => DeviceModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<List<DeviceModel>> getMyDevices() async {
    try {
      final res = await _dio.get(AppConstants.myDevicesEndpoint);
      return _asList(res.data)
          .map((j) => DeviceModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<DeviceModel> createDevice(DeviceModel device) async {
    try {
      final res = await _dio.post(
        AppConstants.devicesEndpoint,
        data: {
          'name':             device.name,
          'ip_address':       device.ipAddress,
          'location':         device.location,
          'status':           _normalizeStatus(device.status),
          'snmp_community':   device.snmpCommunity,
          'device_type_name': device.deviceType,
          if (device.organisationId != null) 'organisation': device.organisationId,
        },
      );
      return DeviceModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<DeviceModel> updateDevice(DeviceModel device) async {
    try {
      final res = await _dio.patch(
        '${AppConstants.devicesEndpoint}${device.id}/',
        data: {
          'name':             device.name,
          'ip_address':       device.ipAddress,
          'location':         device.location,
          'status':           _normalizeStatus(device.status),
          'snmp_community':   device.snmpCommunity,
          'device_type_name': device.deviceType,
          if (device.organisationId != null) 'organisation': device.organisationId,
        },
      );
      return DeviceModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<void> deleteDevice(int id) async {
    try {
      await _dio.delete('${AppConstants.devicesEndpoint}$id/');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Alerts ───────────────────────────────────────────────────────────────

  static Future<List<AlertModel>> getAlerts() async {
    try {
      final res = await _dio.get(AppConstants.alertsEndpoint);
      return _asList(res.data)
          .map((j) => AlertModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<List<AlertModel>> getMyAlerts() async {
    try {
      final res = await _dio.get(AppConstants.myAlertsEndpoint);
      return _asList(res.data)
          .map((j) => AlertModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<void> acknowledgeAlert(int id) async {
    try {
      await _dio.post('${AppConstants.alertsEndpoint}$id/acknowledge/');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<void> resolveAlert(int id) async {
    try {
      await _dio.post('${AppConstants.alertsEndpoint}$id/resolve/');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<AlertModel> reportIssue({
    required String message,
    int? deviceId,
  }) async {
    try {
      final res = await _dio.post(
        AppConstants.reportIssueEndpoint,
        data: {
          'message': message,
          if (deviceId != null) 'device': deviceId,
        },
      );
      return AlertModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Metrics ──────────────────────────────────────────────────────────────

  static Future<List<MetricTypeModel>> getMetricTypes() async {
    try {
      final res = await _dio.get('${AppConstants.metricsEndpoint}types/');
      return _asList(res.data)
          .map((j) => MetricTypeModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<List<MetricModel>> getMetrics({int? deviceId}) async {
    try {
      final res = await _dio.get(
        AppConstants.metricsEndpoint,
        queryParameters: deviceId != null ? {'device': deviceId} : null,
      );
      return _asList(res.data)
          .map((j) => MetricModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<List<MetricThresholdModel>> getMetricThresholds({int? deviceId}) async {
    try {
      final res = await _dio.get(
        '${AppConstants.metricsEndpoint}thresholds/',
        queryParameters: deviceId != null ? {'device': deviceId} : null,
      );
      return _asList(res.data)
          .map((j) => MetricThresholdModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<List<MetricPredictionModel>> getMetricPredictions({int? deviceId}) async {
    try {
      final res = await _dio.get(
        '${AppConstants.metricsEndpoint}predictions/',
        queryParameters: deviceId != null ? {'device': deviceId} : null,
      );
      return _asList(res.data)
          .map((j) => MetricPredictionModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<MetricThresholdModel> createMetricThreshold({
    required int deviceId,
    required int metricId,
    double? warningThreshold,
    double? criticalThreshold,
    bool isActive = true,
  }) async {
    try {
      final res = await _dio.post(
        '${AppConstants.metricsEndpoint}thresholds/',
        data: {
          'device': deviceId,
          'metric': metricId,
          'warning_threshold': warningThreshold,
          'critical_threshold': criticalThreshold,
          'is_active': isActive,
        },
      );
      return MetricThresholdModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<MetricThresholdModel> updateMetricThreshold({
    required int id,
    double? warningThreshold,
    double? criticalThreshold,
    bool? isActive,
  }) async {
    try {
      final res = await _dio.patch(
        '${AppConstants.metricsEndpoint}thresholds/$id/',
        data: {
          if (warningThreshold != null) 'warning_threshold': warningThreshold,
          if (criticalThreshold != null) 'critical_threshold': criticalThreshold,
          if (isActive != null) 'is_active': isActive,
        },
      );
      return MetricThresholdModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Tasks ────────────────────────────────────────────────────────────────

  static Future<List<TaskModel>> getTasks() async {
    try {
      final res = await _dio.get(AppConstants.tasksEndpoint);
      return _asList(res.data)
          .map((j) => TaskModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Clients ──────────────────────────────────────────────────────────────

  static Future<List<UserModel>> getClients() async {
    try {
      final res = await _dio.get(AppConstants.clientsEndpoint);
      return _asList(res.data)
          .map((j) => UserModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Dashboard ────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getDashboardSummary() async {
    try {
      final res = await _dio.get(AppConstants.dashboardEndpoint);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Generic HTTP helpers ─────────────────────────────────────────────────

  static Future<dynamic> get(String path,
      {Map<String, dynamic>? query}) async {
    try {
      final res = await _dio.get(path, queryParameters: query);
      return res.data;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<dynamic> post(String path, {dynamic data}) async {
    try {
      final res = await _dio.post(path, data: data);
      return res.data;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<dynamic> patch(String path, {dynamic data}) async {
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

  // ── Organisations ────────────────────────────────────────────────────────

  static Future<List<OrganisationModel>> getMyOrganisations() async {
    try {
      final res = await _dio.get('${AppConstants.organisationsEndpoint}mine/');
      return _asList(res.data)
          .map((j) => OrganisationModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<OrganisationModel> createOrganisation({
    required String name,
    String? description,
  }) async {
    try {
      final res = await _dio.post(
        AppConstants.organisationsEndpoint,
        data: {'name': name, if (description != null) 'description': description},
      );
      return OrganisationModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<List<MembershipModel>> getOrgMembers(int orgId) async {
    try {
      final res = await _dio.get(
          '${AppConstants.organisationsEndpoint}$orgId/members/');
      return _asList(res.data)
          .map((j) => MembershipModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<MembershipModel> addOrgMember({
    required int orgId,
    required int userId,
    required String role,
  }) async {
    try {
      final res = await _dio.post(
        '${AppConstants.organisationsEndpoint}$orgId/members/add/',
        data: {'user_id': userId, 'role': role},
      );
      return MembershipModel.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<void> removeOrgMember({
    required int orgId,
    required int userId,
  }) async {
    try {
      await _dio.delete(
          '${AppConstants.organisationsEndpoint}$orgId/members/$userId/');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Invitations ──────────────────────────────────────────────────────────

  static Future<List<InvitationModel>> getOrgInvitations(int orgId) async {
    try {
      final res = await _dio.get(
          '${AppConstants.organisationsEndpoint}$orgId/invitations/');
      return _asList(res.data)
          .map((j) => InvitationModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<InvitationModel> sendInvitation({
    required int    orgId,
    required String email,
    required String role,
  }) async {
    try {
      final res = await _dio.post(
        '${AppConstants.organisationsEndpoint}$orgId/invitations/send/',
        data: {'email': email, 'role': role},
      );
      return InvitationModel.fromJson(
          res.data['invitation'] as Map<String, dynamic>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<Map<String, dynamic>> bulkInvite({
    required int         orgId,
    required List<String> emails,
    required String      role,
  }) async {
    try {
      final res = await _dio.post(
        '${AppConstants.organisationsEndpoint}$orgId/invitations/bulk/',
        data: {'emails': emails, 'role': role},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<void> cancelInvitation({
    required int orgId,
    required int invitationId,
  }) async {
    try {
      await _dio.delete(
          '${AppConstants.organisationsEndpoint}$orgId/invitations/$invitationId/');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<List<InvitationModel>> getMyInvitations() async {
    try {
      final res = await _dio.get('/invitations/');
      return _asList(res.data)
          .map((j) => InvitationModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<Map<String, dynamic>> acceptInvitation(String invitationId) async {
    try {
      final res = await _dio.post('/invitations/$invitationId/accept/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<void> declineInvitation(String invitationId) async {
    try {
      await _dio.post('/invitations/$invitationId/decline/');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── Reports export ───────────────────────────────────────────────────────

  static Future<Uint8List> exportReport({
    required DateTime start,
    required DateTime end,
    String format = 'csv',
  }) async {
    try {
      final res = await _dio.get(
        AppConstants.reportsExportEndpoint,
        queryParameters: {
          'format': format,
          'start': '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}',
          'end': '${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}',
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data as List<int>);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  // ── AI Assistant ─────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAIStatus() async {
    try {
      final res = await _dio.get(AppConstants.aiStatusEndpoint);
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<List<dynamic>> getAIConversations() async {
    try {
      final res = await _dio.get(AppConstants.aiConversationsEndpoint);
      return _asList(res.data);
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<Map<String, dynamic>> createAIConversation({String? title}) async {
    try {
      final res = await _dio.post(
        AppConstants.aiConversationsEndpoint,
        data: {'title': title ?? 'New Conversation'},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<Map<String, dynamic>> getAIConversation(int id) async {
    try {
      final res = await _dio.get('${AppConstants.aiConversationsEndpoint}$id/');
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<Map<String, dynamic>> sendAIMessage(int conversationId, String message) async {
    try {
      final res = await _dio.post(
        '${AppConstants.aiConversationsEndpoint}$conversationId/send/',
        data: {'message': message},
      );
      return res.data as Map<String, dynamic>;
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  static Future<void> deleteAIConversation(int id) async {
    try {
      await _dio.delete('${AppConstants.aiConversationsEndpoint}$id/');
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }
}

/// Thrown by [ApiClient] when a request fails.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => 'ApiException($statusCode): $message';
}
