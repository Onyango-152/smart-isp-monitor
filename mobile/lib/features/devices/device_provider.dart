import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../core/utils.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import '../../data/dummy_data.dart';
import '../../services/api_client.dart';
import '../../services/database_helper.dart';

/// DeviceProvider holds the state for the device list screen.
///
/// Supports:
///   - Text search (name, IP, location, type label)
///   - Status filter chip (all / online / offline / degraded)
///   - Device type filter chip (all / router / switch / olt / access_point)
///   - Default sort: offline first, degraded second, online last
class DeviceProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;

  // ── Data ──────────────────────────────────────────────────────────────────
  List<DeviceModel> _allDevices = [];
  List<DeviceModel> _filteredDevices = [];
  List<MetricModel> _latestMetrics = [];

  // ── Filter state ──────────────────────────────────────────────────────────
  String _searchQuery = '';
  String _statusFilter = 'all';
  String _typeFilter = 'all';

  // ── Getters — state ───────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  // ── Getters — data ────────────────────────────────────────────────────────
  List<DeviceModel> get devices => _filteredDevices;
  int get totalCount => _allDevices.length;
  int get filteredCount => _filteredDevices.length;

  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty || _statusFilter != 'all' || _typeFilter != 'all';

  // ── Getters — filter values ───────────────────────────────────────────────
  String get searchQuery => _searchQuery;
  String get statusFilter => _statusFilter;
  String get typeFilter => _typeFilter;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadDevices() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Show cached data immediately for instant UI
    if (!kIsWeb) {
      try {
        final cached = await DatabaseHelper.instance.getCachedDevices();
        if (cached.isNotEmpty) {
          _allDevices = cached;
          _applyFilters();
          notifyListeners();
        }
      } catch (_) {/* cache miss — no-op */}
    }

    try {
      _allDevices = await ApiClient.getDevices();
      _latestMetrics = await ApiClient.getMetrics();
      _applyFilters();
      if (!kIsWeb) {
        await DatabaseHelper.instance.cacheDevices(_allDevices);
      }
    } catch (e) {
      if (_allDevices.isEmpty) {
        _allDevices = List<DeviceModel>.from(DummyData.devices);
        _latestMetrics = List<MetricModel>.from(DummyData.latestMetrics);
        _applyFilters();
        _errorMessage = null;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadDevices();

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

  void setTypeFilter(String type) {
    _typeFilter = type;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _statusFilter = 'all';
    _typeFilter = 'all';
    _applyFilters();
    notifyListeners();
  }

  // ── Metric helper ─────────────────────────────────────────────────────────

  MetricModel? getLatestMetric(int deviceId) =>
      _latestMetrics.where((m) => m.deviceId == deviceId).firstOrNull;

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Adds a new device — optimistic local insert, then persists to API.
  /// Returns true on success, false on failure (with errorMessage set).
  Future<bool> addDevice(DeviceModel device) async {
    _errorMessage = null;

    // Optimistic insert so the UI feels instant
    final tempDevice = device;
    _allDevices = [..._allDevices, tempDevice];
    _applyFilters();
    notifyListeners();

    try {
      // POST to Django — response contains the real server-assigned ID
      final created = await ApiClient.createDevice(device);

      // Replace the temp entry with the server-confirmed one
      _allDevices = _allDevices
          .map((d) => d.id == tempDevice.id ? created : d)
          .toList();
      _applyFilters();
      notifyListeners();

      // Update local cache with the real device
      if (!kIsWeb) {
        await DatabaseHelper.instance.upsertDevice(created);
      }
      return true;
    } on ApiException catch (e) {
      // Roll back optimistic insert
      _allDevices = _allDevices.where((d) => d.id != tempDevice.id).toList();
      _applyFilters();
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      // Roll back optimistic insert
      _allDevices = _allDevices.where((d) => d.id != tempDevice.id).toList();
      _applyFilters();
      _errorMessage = 'Failed to save device. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Updates an existing device — optimistic local update, then persists to API.
  Future<bool> updateDevice(DeviceModel updated) async {
    _errorMessage = null;

    // Remember old state for rollback
    final original = _allDevices.firstWhere(
      (d) => d.id == updated.id,
      orElse: () => updated,
    );

    // Optimistic update
    _allDevices = _allDevices
        .map((d) => d.id == updated.id ? updated : d)
        .toList();
    _applyFilters();
    notifyListeners();

    try {
      final saved = await ApiClient.updateDevice(updated);

      // Replace with server-confirmed version
      _allDevices = _allDevices
          .map((d) => d.id == saved.id ? saved : d)
          .toList();
      _applyFilters();
      notifyListeners();

      if (!kIsWeb) {
        await DatabaseHelper.instance.upsertDevice(saved);
      }
      return true;
    } on ApiException catch (e) {
      // Roll back
      _allDevices = _allDevices
          .map((d) => d.id == original.id ? original : d)
          .toList();
      _applyFilters();
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      // Roll back
      _allDevices = _allDevices
          .map((d) => d.id == original.id ? original : d)
          .toList();
      _applyFilters();
      _errorMessage = 'Failed to update device. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Deletes a device — optimistic local removal, then calls API.
  Future<bool> deleteDevice(int deviceId) async {
    _errorMessage = null;

    // Remember for rollback
    final removed = _allDevices.where((d) => d.id == deviceId).toList();

    // Optimistic removal
    _allDevices = _allDevices.where((d) => d.id != deviceId).toList();
    _applyFilters();
    notifyListeners();

    try {
      await ApiClient.deleteDevice(deviceId);

      if (!kIsWeb) {
        await DatabaseHelper.instance.deleteDevice(deviceId);
      }
      return true;
    } on ApiException catch (e) {
      // Roll back
      _allDevices = [..._allDevices, ...removed];
      _applyFilters();
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (_) {
      // Roll back
      _allDevices = [..._allDevices, ...removed];
      _applyFilters();
      _errorMessage = 'Failed to delete device. Please try again.';
      notifyListeners();
      return false;
    }
  }

  /// Generates the next available local ID (temporary, replaced by server ID).
  int get nextId {
    if (_allDevices.isEmpty) return -1; // negative = temp, server will assign real ID
    return _allDevices.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _applyFilters() {
    _filteredDevices = _allDevices.where((device) {
      final q = _searchQuery;
      final typeLabel =
          AppUtils.deviceTypeLabel(device.deviceType).toLowerCase();
      final matchesSearch = q.isEmpty ||
          device.name.toLowerCase().contains(q) ||
          device.ipAddress.toLowerCase().contains(q) ||
          (device.location?.toLowerCase().contains(q) ?? false) ||
          typeLabel.contains(q);

      final matchesStatus =
          _statusFilter == 'all' || device.status == _statusFilter;

      final matchesType =
          _typeFilter == 'all' || device.deviceType == _typeFilter;

      return matchesSearch && matchesStatus && matchesType;
    }).toList()
      ..sort((a, b) =>
          _statusPriority(a.status).compareTo(_statusPriority(b.status)));
  }

  int _statusPriority(String status) {
    switch (status) {
      case AppConstants.statusOffline:
        return 0;
      case AppConstants.statusDegraded:
        return 1;
      case AppConstants.statusOnline:
        return 2;
      default:
        return 3;
    }
  }
}