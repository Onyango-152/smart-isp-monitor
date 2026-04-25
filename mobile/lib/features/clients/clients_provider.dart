import 'package:flutter/material.dart';
import '../../data/models/user_model.dart';
import '../../data/models/device_model.dart';
import '../../services/api_client.dart';
import '../../services/database_helper.dart';

/// ClientsProvider holds state for the clients list screen.
///
/// Supports:
///   - Text search (name, email, plan)
///   - Status filter (all / active / inactive)
///   - Plan filter (all / specific plan)
///   - Default sort: inactive first, then alphabetical
///
/// On integration day replace DummyData calls in loadClients() with
/// real API calls. The provider interface stays the same.
class ClientsProvider extends ChangeNotifier {

  // ── State ─────────────────────────────────────────────────────────────────
  bool    _isLoading    = false;
  String? _errorMessage;

  // ── Data ──────────────────────────────────────────────────────────────────
  List<UserModel> _allClients      = [];
  List<UserModel> _filteredClients = [];

  // Plan and device-assignment maps, keyed by client ID.
  // Populated from the API response or the local cache.
  final Map<int, String>    _clientPlans   = {};
  final Map<int, List<int>> _clientDevices = {};

  // Devices list held by the provider for getDevices() helper.
  List<DeviceModel> _allDevices = [];

  // ── Filter state ──────────────────────────────────────────────────────────
  String _searchQuery  = '';
  String _statusFilter = 'all';    // all | active | inactive
  String _planFilter   = 'all';

  // ── Getters — state ───────────────────────────────────────────────────────
  bool    get isLoading    => _isLoading;
  bool    get hasError     => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  // ── Getters — data ────────────────────────────────────────────────────────
  List<UserModel> get clients       => _filteredClients;
  int             get totalCount    => _allClients.length;
  int             get filteredCount => _filteredClients.length;
  int get activeCount  => _allClients.where((c) => c.isActive).length;
  int get inactiveCount => _allClients.where((c) => !c.isActive).length;

  /// True when any filter or search is active.
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _statusFilter != 'all' ||
      _planFilter   != 'all';

  // ── Getters — filter values ───────────────────────────────────────────────
  String get searchQuery  => _searchQuery;
  String get statusFilter => _statusFilter;
  String get planFilter   => _planFilter;

  /// All unique plan names from the client list.
  List<String> get availablePlans {
    final plans = <String>{};
    for (final client in _allClients) {
      final plan = _clientPlans[client.id];
      if (plan != null) plans.add(plan);
    }
    return plans.toList()..sort();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadClients() async {
    _isLoading    = true;
    _errorMessage = null;
    
    // Reset filters to default on fresh load
    if (_allClients.isEmpty) {
      _searchQuery  = '';
      _statusFilter = 'all';
      _planFilter   = 'all';
    }
    
    notifyListeners();

    // Show cached data immediately for instant UI
    try {
      final cached = await DatabaseHelper.instance.getCachedClients();
      if (cached.isNotEmpty) {
        _allClients = cached;
        // Also restore plan/device maps from cache.
        for (final c in cached) {
          _clientPlans[c.id]  = await DatabaseHelper.instance.getCachedClientPlan(c.id);
          _clientDevices[c.id] = await DatabaseHelper.instance.getCachedClientDeviceIds(c.id);
        }
        _applyFilters();
        notifyListeners();
      }
    } catch (_) { /* cache miss — no-op */ }

    try {
      _allClients = await ApiClient.getClients();
      // Restore plan/device maps from DB after API fetch.
      for (final c in _allClients) {
        _clientPlans[c.id]   = await DatabaseHelper.instance.getCachedClientPlan(c.id);
        _clientDevices[c.id] = await DatabaseHelper.instance.getCachedClientDeviceIds(c.id);
      }
      _allDevices = await ApiClient.getDevices();
      _applyFilters();
      await DatabaseHelper.instance.cacheClients(
        _allClients,
        plans:     _clientPlans,
        deviceIds: _clientDevices,
      );
    } catch (e) {
      if (_allClients.isEmpty) {
        _errorMessage = 'Failed to load clients. Please try again.';
      }
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

  void setPlanFilter(String plan) {
    _planFilter = plan;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery  = '';
    _statusFilter = 'all';
    _planFilter   = 'all';
    _applyFilters();
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Next available ID for a new client.
  int get nextId =>
      _allClients.isEmpty ? 20 : _allClients.map((c) => c.id).reduce((a, b) => a > b ? a : b) + 1;

  Future<bool> addClient(UserModel client, {String plan = 'Home Basic', List<int> deviceIds = const []}) async {
    try {
      _allClients = [..._allClients, client];
      _clientPlans[client.id]   = plan;
      _clientDevices[client.id] = deviceIds;
      _applyFilters();
      notifyListeners();
      await DatabaseHelper.instance.upsertClient(client, plan: plan, deviceIds: deviceIds);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateClient(UserModel client, {String? plan, List<int>? deviceIds}) async {
    try {
      final idx = _allClients.indexWhere((c) => c.id == client.id);
      if (idx == -1) return false;
      _allClients = [..._allClients]..[idx] = client;
      if (plan != null)      _clientPlans[client.id]   = plan;
      if (deviceIds != null) _clientDevices[client.id] = deviceIds;
      _applyFilters();
      notifyListeners();
      await DatabaseHelper.instance.upsertClient(
        client,
        plan:      plan      ?? getPlan(client.id),
        deviceIds: deviceIds ?? getDeviceIds(client.id),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteClient(int clientId) async {
    try {
      _allClients = _allClients.where((c) => c.id != clientId).toList();
      _clientPlans.remove(clientId);
      _clientDevices.remove(clientId);
      _applyFilters();
      notifyListeners();
      await DatabaseHelper.instance.deleteClient(clientId);
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the subscription plan name for a client.
  String getPlan(int clientId) =>
      _clientPlans[clientId] ?? 'No Plan';

  /// Returns the device IDs assigned to a client.
  List<int> getDeviceIds(int clientId) =>
      _clientDevices[clientId] ?? [];

  /// Returns the DeviceModel objects assigned to a client.
  List<DeviceModel> getDevices(int clientId) {
    final ids = getDeviceIds(clientId);
    return _allDevices.where((d) => ids.contains(d.id)).toList();
  }

  /// Returns the count of devices that are currently online for a client.
  int getOnlineDeviceCount(int clientId) {
    return getDevices(clientId).where((d) => d.status == 'online').length;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _applyFilters() {
    debugPrint('[ClientsProvider] Applying filters: search="$_searchQuery", status="$_statusFilter", plan="$_planFilter"');
    debugPrint('[ClientsProvider] Total clients before filter: ${_allClients.length}');
    
    _filteredClients = _allClients.where((client) {
      // ── Text search ───────────────────────────────────────────────
      final q = _searchQuery;
      if (q.isNotEmpty) {
        final name  = client.username.toLowerCase();
        final email = client.email.toLowerCase();
        final plan  = getPlan(client.id).toLowerCase();
        if (!name.contains(q) && !email.contains(q) && !plan.contains(q)) {
          return false;
        }
      }

      // ── Status filter ─────────────────────────────────────────────
      if (_statusFilter == 'active'   && !client.isActive) return false;
      if (_statusFilter == 'inactive' &&  client.isActive) return false;

      // ── Plan filter ───────────────────────────────────────────────
      if (_planFilter != 'all') {
        if (getPlan(client.id) != _planFilter) return false;
      }

      return true;
    }).toList();

    debugPrint('[ClientsProvider] Filtered clients: ${_filteredClients.length}');

    // Sort: inactive first, then alphabetical by name
    _filteredClients.sort((a, b) {
      if (a.isActive != b.isActive) {
        return a.isActive ? 1 : -1; // inactive first
      }
      return a.username.compareTo(b.username);
    });
  }
}
