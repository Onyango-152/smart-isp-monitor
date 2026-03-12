import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../../data/models/user_model.dart';
import '../../services/database_helper.dart';
import 'auth_service.dart';

/// AuthProvider owns the in-memory authentication state for the whole app.
/// It delegates all I/O to [AuthService] and only handles state + errors.
///
/// Demo / development mode:
///   When [_useDummyLogin] is true (see below), login bypasses the network
///   and accepts the three dummy accounts:
///     technician@isp.co.ke / password123  → technician portal
///     manager@isp.co.ke    / password123  → manager portal
///     customer@isp.co.ke   / password123  → customer portal
///
///   Set [_useDummyLogin = false] on integration day to switch to real API.
class AuthProvider extends ChangeNotifier {

  // ── Demo mode toggle ──────────────────────────────────────────────────────
  /// Set to false on integration day to use the real Django backend.
  static const bool _useDummyLogin = true;

  // ── State ─────────────────────────────────────────────────────────────────
  UserModel? _currentUser;
  bool       _isLoading    = false;
  String?    _errorMessage;
  String?    _refreshToken;

  // ── Getters ───────────────────────────────────────────────────────────────
  UserModel? get currentUser     => _currentUser;
  bool       get isLoading       => _isLoading;
  String?    get errorMessage    => _errorMessage;
  bool       get isAuthenticated => _currentUser != null;
  String     get userRole        => _currentUser?.role ?? '';

  // Convenience role booleans — avoids raw string comparisons in screens
  bool get isTechnician => userRole == AppConstants.roleTechnician;
  bool get isManager    => userRole == AppConstants.roleManager;
  bool get isCustomer   => userRole == AppConstants.roleCustomer;
  bool get isAdmin      => userRole == AppConstants.roleAdmin;

  /// Returns the named route the user should land on after login.
  /// Used by LoginScreen and SplashScreen — single place for routing logic.
  String get routeForRole {
    switch (userRole) {
      case AppConstants.roleTechnician: return AppConstants.technicianHomeRoute;
      case AppConstants.roleManager:    return AppConstants.managerHomeRoute;
      case AppConstants.roleCustomer:   return AppConstants.customerHomeRoute;
      case AppConstants.roleAdmin:      return AppConstants.managerHomeRoute;
      default:                          return AppConstants.loginRoute;
    }
  }

  // ── Auto-login from saved session ─────────────────────────────────────────
  /// Called by SplashScreen. Loads a previously saved session from
  /// SharedPreferences. Does NOT call the server — the access token
  /// is assumed valid until the user hits a 401.
  Future<void> tryAutoLogin() async {
    final user         = await AuthService.loadSession();
    final refreshToken = await AuthService.getRefreshToken();
    if (user != null) {
      _currentUser  = user;
      _refreshToken = refreshToken;
      notifyListeners();
    }
  }

  // ── Login ─────────────────────────────────────────────────────────────────
  /// Authenticates the user.
  ///
  /// In demo mode ([_useDummyLogin] = true), accepts:
  ///   technician@isp.co.ke / password123
  ///   manager@isp.co.ke    / password123
  ///   customer@isp.co.ke   / password123
  ///
  /// Returns true on success, false on failure.
  /// On failure, [errorMessage] is set and can be shown in the UI.
  Future<bool> login(String username, String password) async {
    _setLoading(true);

    if (_useDummyLogin) {
      return _dummyLogin(username, password);
    }

    try {
      final data = await AuthService.login(
        username: username,
        password: password,
      );
      return _handleAuthResponse(data);
    } on DioException catch (e) {
      return _fail(_extractDioError(e));
    } catch (_) {
      return _fail('Login failed. Please try again.');
    }
  }

  // ── Register ──────────────────────────────────────────────────────────────
  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
    required String role,
    String firstName = '',
    String lastName  = '',
    String phone     = '',
  }) async {
    _setLoading(true);

    if (_useDummyLogin) {
      // In demo mode, registration always succeeds and logs in as technician
      await Future.delayed(const Duration(milliseconds: 600));
      _currentUser = UserModel(
        id: 1, email: email, username: username,
        role: role.isNotEmpty ? role : AppConstants.roleTechnician,
        isActive: true,
      );
      _isLoading   = false;
      notifyListeners();
      return true;
    }

    try {
      final data = await AuthService.register(
        username:        username,
        email:           email,
        password:        password,
        passwordConfirm: passwordConfirm,
        role:            role,
        firstName:       firstName,
        lastName:        lastName,
        phone:           phone,
      );
      return _handleAuthResponse(data);
    } on DioException catch (e) {
      return _fail(_extractDioError(e));
    } catch (_) {
      return _fail('Registration failed. Please try again.');
    }
  }

  // ── Logout ────────────────────────────────────────────────────────────────
  Future<void> logout() async {
    if (!_useDummyLogin && _refreshToken != null) {
      await AuthService.revokeToken(_refreshToken!);
    }
    await AuthService.clearSession();
    await DatabaseHelper.instance.clearAll(); // wipe offline cache
    _currentUser  = null;
    _refreshToken = null;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ── Dummy login ───────────────────────────────────────────────────────────

  Future<bool> _dummyLogin(String username, String password) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 700));

    const validPassword = 'password123';
    final input = username.trim().toLowerCase();

    UserModel? user;
    if (input == 'technician@isp.co.ke' || input == 'technician') {
      user = UserModel(id: 1, email: 'technician@isp.co.ke', username: 'John Kamau',
          role: AppConstants.roleTechnician, isActive: true);
    } else if (input == 'manager@isp.co.ke' || input == 'manager') {
      user = UserModel(id: 2, email: 'manager@isp.co.ke', username: 'Grace Wanjiru',
          role: AppConstants.roleManager, isActive: true);
    } else if (input == 'customer@isp.co.ke' || input == 'customer') {
      user = UserModel(id: 3, email: 'customer@isp.co.ke', username: 'Peter Otieno',
          role: AppConstants.roleCustomer, isActive: true);
    }

    if (user == null || password != validPassword) {
      return _fail(
        'Invalid credentials.\n\nDemo accounts:\n'
        '• technician@isp.co.ke\n'
        '• manager@isp.co.ke\n'
        '• customer@isp.co.ke\n'
        'Password: password123',
      );
    }

    _currentUser = user;
    _isLoading   = false;
    notifyListeners();
    return true;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<bool> _handleAuthResponse(Map<String, dynamic> data) async {
    final user   = UserModel.fromJson(data['user'] as Map<String, dynamic>);
    final tokens = data['tokens'] as Map<String, dynamic>;

    _refreshToken = tokens['refresh'] as String;
    _currentUser  = user;

    await AuthService.saveSession(
      accessToken:  tokens['access'] as String,
      refreshToken: _refreshToken!,
      user:         user,
    );

    _isLoading = false;
    notifyListeners();
    return true;
  }

  bool _fail(String message) {
    _errorMessage = message;
    _isLoading    = false;
    notifyListeners();
    return false;
  }

  void _setLoading(bool v) {
    _isLoading    = v;
    _errorMessage = null;
    notifyListeners();
  }

  String _extractDioError(DioException e) {
    final response = e.response;

    if (response != null) {
      final body = response.data;
      if (body is Map) {
        if (body.containsKey('detail')) return body['detail'].toString();
        if (body.containsKey('error'))  return body['error'].toString();
        // Collect DRF field-level validation errors
        final msgs = <String>[];
        body.forEach((key, value) {
          final label = _fieldLabel(key);
          if (value is List) {
            msgs.addAll(value.map((v) =>
                label.isEmpty ? '$v' : '$label: $v'));
          } else {
            msgs.add(label.isEmpty ? '$value' : '$label: $value');
          }
        });
        if (msgs.isNotEmpty) return msgs.join('\n');
      }
      if (response.statusCode == 401) {
        return 'Invalid credentials. Please check your username and password.';
      }
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.receiveTimeout:
        return 'Cannot connect to the server.\nPlease check your internet connection.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }

  String _fieldLabel(String key) {
    const labels = {
      'username':         'Username',
      'email':            'Email',
      'password':         'Password',
      'password_confirm': 'Confirm password',
      'role':             'Role',
      'non_field_errors': '',
    };
    return labels[key] ?? key;
  }
}