import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/device_model.dart';
import '../../services/api_client.dart';

/// ClientProvider holds the state for the technician's client list screen.
///
/// Supports:
///   - Text search (username, email)
///   - Status filter (all / active / inactive)
///   - Device count and plan lookups per client
class ClientProvider extends ChangeNotifier {
  bool    _isLoading    = false;
  String? _errorMessage;

  List<UserModel> _allClients      = [];
  List<UserModel> _filteredClients = [];

  // Local maps for plan and device assignment data.
  final Map<int, String>    _clientPlans   = {};
  final Map<int, List<int>> _clientDevices = {};
  List<DeviceModel>         _allDevices    = [];

  String _searchQuery  = '';
  String _statusFilter = 'all'; // all | active | inactive

  // ── Getters ───────────────────────────────────────────────────────────────
  bool    get isLoading    => _isLoading;
  bool    get hasError     => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  List<UserModel> get clients       => _filteredClients;
  int             get totalCount    => _allClients.length;
  int             get filteredCount => _filteredClients.length;
  int             get activeCount   => _allClients.where((c) => c.isActive).length;
  int             get inactiveCount => _allClients.where((c) => !c.isActive).length;

  String get searchQuery  => _searchQuery;
  String get statusFilter => _statusFilter;

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty || _statusFilter != 'all';

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadClients() async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _allClients = await ApiClient.getClients();
      _allDevices = await ApiClient.getDevices();
      _applyFilters();
    } catch (e) {
      _errorMessage = 'Failed to load clients.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadClients();

  // ── Filters ───────────────────────────────────────────────────────────────

  void search(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applyFilters();
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery  = '';
    _statusFilter = 'all';
    _applyFilters();
    notifyListeners();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Device IDs assigned to the given client.
  List<int> deviceIdsFor(int clientId) =>
      _clientDevices[clientId] ?? [];

  /// Resolved DeviceModel list for a client.
  List<DeviceModel> devicesFor(int clientId) {
    final ids = deviceIdsFor(clientId);
    return _allDevices.where((d) => ids.contains(d.id)).toList();
  }

  /// Subscription plan for a client.
  String planFor(int clientId) =>
      _clientPlans[clientId] ?? 'Unknown';

  // ── Private ───────────────────────────────────────────────────────────────

  void _applyFilters() {
    _filteredClients = _allClients.where((client) {
      // Status filter
      if (_statusFilter == 'active'   && !client.isActive) return false;
      if (_statusFilter == 'inactive' &&  client.isActive) return false;

      // Text search
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery;
        final matchesName  = client.username.toLowerCase().contains(q);
        final matchesEmail = client.email.toLowerCase().contains(q);
        if (!matchesName && !matchesEmail) return false;
      }

      return true;
    }).toList()
      // Active clients first, then alphabetical
      ..sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.username.compareTo(b.username);
      });
  }
}
