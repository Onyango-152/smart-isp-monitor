import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../data/models/user_model.dart';

/// AuthService is the single point of contact for all authentication
/// HTTP calls and session persistence.  It is purely static / stateless;
/// [AuthProvider] owns the in-memory user state.
class AuthService {
  static final Dio _dio = _buildDio();

  static Dio _buildDio() {
    final dio = Dio(
      BaseOptions(
        baseUrl:        AppConstants.baseUrl,
        connectTimeout: Duration(milliseconds: AppConstants.connectTimeout),
        receiveTimeout: Duration(milliseconds: AppConstants.receiveTimeout),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    // ── Request interceptor: attach saved access token ─────────────────────
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuth = options.extra['skipAuth'] == true;
          if (!skipAuth) {
            final token = await _readToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          debugPrint('[API] ${options.method} ${options.path}');
          handler.next(options);
        },
        onError: (error, handler) {
          debugPrint(
            '[API] ERROR ${error.response?.statusCode} '
            '${error.requestOptions.path}: ${error.response?.data}',
          );
          handler.next(error);
        },
      ),
    );

    return dio;
  }

  // ── Register ─────────────────────────────────────────────────────────────
  /// Creates a new account.  Returns `{'user': {...}, 'tokens': {...}}`.
  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String role,
    String firstName = '',
    String lastName  = '',
    String phone     = '',
  }) async {
    final response = await _dio.post(
      AppConstants.registerEndpoint,
      data: {
        'username':         username,
        'email':            email,
        'password':         password,
        'password_confirm': passwordConfirm,
        'role':             role,
        if (firstName.isNotEmpty) 'first_name': firstName,
        if (lastName.isNotEmpty)  'last_name':  lastName,
        if (phone.isNotEmpty)     'phone':      phone,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  /// Authenticates with username or email + password.
  /// Returns `{'user': {...}, 'tokens': {...}}`.
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post(
      AppConstants.loginEndpoint,
      data: {'username': username, 'password': password},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── Email verification ─────────────────────────────────────────────────-
  static Future<Map<String, dynamic>> verifyEmail({
    required String email,
    required String otp,
  }) async {
    final response = await _dio.post(
      AppConstants.verifyEmailEndpoint,
      data: {'email': email, 'otp': otp},
    );
    return response.data as Map<String, dynamic>;
  }

  static Future<void> resendOtp({
    required String email,
  }) async {
    await _dio.post(
      AppConstants.resendOtpEndpoint,
      data: {'email': email},
    );
  }

  // ── Password reset ──────────────────────────────────────────────────────────
  /// Step 1: Request a password reset OTP via email
  static Future<void> forgotPassword({
    required String email,
  }) async {
    await _dio.post(
      AppConstants.forgotPasswordEndpoint,
      data: {'email': email},
    );
  }

  /// Step 2: Reset password using OTP and new password
  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _dio.post(
      AppConstants.resetPasswordEndpoint,
      data: {
        'email': email,
        'otp': otp,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
    return response.data as Map<String, dynamic>;
  }
  static Future<void> revokeToken(String refreshToken) async {
    try {
      debugPrint('[AUTH] Attempting to revoke token on server');
      await _dio.post(
        AppConstants.logoutEndpoint,
        data: {'refresh': refreshToken},
        options: Options(
          extra: {'skipAuth': true},
        ),
      );
      debugPrint('[AUTH] Token revoked successfully');
    } catch (e) {
      debugPrint('[AUTH] Token revocation failed: $e (continuing with local logout)');
      // Best-effort: always proceed with local logout even if API fails.
    }
  }

  // ── Session persistence ───────────────────────────────────────────────────
  static Future<void> saveSession({
    required String    accessToken,
    required String    refreshToken,
    required UserModel user,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.setString(AppConstants.tokenKey,        accessToken),
      prefs.setString(AppConstants.refreshTokenKey, refreshToken),
      prefs.setString(AppConstants.userKey,         jsonEncode(user.toJson())),
    ]);
  }

  /// Loads the last-saved user from SharedPreferences.
  /// Returns `null` if no session is stored or data is corrupt.
  static Future<UserModel?> loadSession() async {
    final prefs    = await SharedPreferences.getInstance();
    final token    = prefs.getString(AppConstants.tokenKey);
    final userJson = prefs.getString(AppConstants.userKey);
    if (token == null || userJson == null) return null;
    try {
      return UserModel.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(AppConstants.tokenKey),
      prefs.remove(AppConstants.refreshTokenKey),
      prefs.remove(AppConstants.userKey),
    ]);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.refreshTokenKey);
  }

  // ── Internal helper used by the interceptor ───────────────────────────────
  static Future<String?> _readToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }
}
