import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../core/constants.dart';

/// AuthProvider holds the authentication state for the entire app.
/// It extends ChangeNotifier which means any widget that listens to
/// this provider will automatically rebuild when notifyListeners() is called.
class AuthProvider extends ChangeNotifier {

  UserModel? _currentUser;
  bool       _isLoading = false;
  String?    _errorMessage;

  // Getters expose private fields as read-only to the rest of the app
  UserModel? get currentUser    => _currentUser;
  bool       get isLoading      => _isLoading;
  String?    get errorMessage   => _errorMessage;
  bool       get isAuthenticated => _currentUser != null;
  String     get userRole       => _currentUser?.role ?? '';

  /// Simulates a login with dummy data.
  /// On integration day this will call the real Django login endpoint.
  /// Returns true if login succeeded, false if it failed.
  Future<bool> login(String email, String password) async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    // Simulate network delay so the loading spinner is visible
    await Future.delayed(const Duration(seconds: 1));

    // Dummy credential check — any of the three role emails work
    UserModel? user;

    if (email == 'technician@isp.co.ke' && password == 'Tech1234!') {
      user = UserModel(
        id: 1, email: email, username: 'technician',
        role: AppConstants.roleTechnician, isActive: true,
      );
    } else if (email == 'manager@isp.co.ke' && password == 'Man1234!') {
      user = UserModel(
        id: 2, email: email, username: 'manager',
        role: AppConstants.roleManager, isActive: true,
      );
    } else if (email == 'customer@isp.co.ke' && password == 'Cust1234!') {
      user = UserModel(
        id: 3, email: email, username: 'customer',
        role: AppConstants.roleCustomer, isActive: true,
      );
    } else if (email == 'admin@isp.co.ke' && password == 'Admin1234!') {
      user = UserModel(
        id: 4, email: email, username: 'admin',
        role: AppConstants.roleAdmin, isActive: true,
      );
    }

    if (user != null) {
      _currentUser = user;
      _isLoading   = false;
      notifyListeners();
      return true;
    } else {
      _errorMessage = 'Invalid email or password. Please try again.';
      _isLoading    = false;
      notifyListeners();
      return false;
    }
  }

  /// Logs the user out and clears all state.
  void logout() {
    _currentUser  = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Clears any previous error message.
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}