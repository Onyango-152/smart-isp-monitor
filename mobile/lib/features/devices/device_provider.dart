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
///
/// On integration day replace DummyData calls in loadDevices() with
/// real API calls. The provider interface stays the same.
class DeviceProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;

  // ── Data ──────────────────────────────────────────────────────────────────
  List<DeviceModel> _allDevices = [];
  List<DeviceModel> _filteredDevices = [];

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

  /// True when any filter or search is active.
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
    try {
      final cached = await DatabaseHelper.instance.getCachedDevices();
      if (cached.isNotEmpty) {
        _allDevices = cached;
        _applyFilters();
        notifyListeners();
      }
    } catch (_) {/* cache miss — no-op */}

    try {
      _allDevices = await ApiClient.getDevices();
      _latestMetrics = await ApiClient.getMetrics();
      _applyFilters();
      await DatabaseHelper.instance.cacheDevices(_allDevices);
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

  /// Returns the latest metric snapshot for [deviceId], or null.
  /// Uses the cached metrics fetched alongside devices.
  MetricModel? getLatestMetric(int deviceId) =>
      _latestMetrics.where((m) => m.deviceId == deviceId).firstOrNull;

  List<MetricModel> _latestMetrics = [];

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Adds a new device locally. On integration day replace with POST API call.
  Future<bool> addDevice(DeviceModel device) async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      _allDevices = [..._allDevices, device];
      _applyFilters();
      notifyListeners();
      await DatabaseHelper.instance.upsertDevice(device);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateDevice(DeviceModel updated) async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      _allDevices = _allDevices
          .map(
            (d) => d.id == updated.id ? updated : d,
          )
          .toList();
      _applyFilters();
      notifyListeners();
      await DatabaseHelper.instance.upsertDevice(updated);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteDevice(int deviceId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      _allDevices = _allDevices.where((d) => d.id != deviceId).toList();
      _applyFilters();
      notifyListeners();
      await DatabaseHelper.instance.deleteDevice(deviceId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Generates the next available ID (for local adds before API integration).
  int get nextId {
    if (_allDevices.isEmpty) return 1;
    return _allDevices.map((d) => d.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _applyFilters() {
    _filteredDevices = _allDevices.where((device) {
      // ── Text search ───────────────────────────────────────────────
      // Matches name, IP address, location, and human-readable type label
      // (e.g. "access point" matches deviceType 'access_point')
      final q = _searchQuery;
      final typeLabel =
          AppUtils.deviceTypeLabel(device.deviceType).toLowerCase();
      final matchesSearch = q.isEmpty ||
          device.name.toLowerCase().contains(q) ||
          device.ipAddress.toLowerCase().contains(q) ||
          (device.location?.toLowerCase().contains(q) ?? false) ||
          typeLabel.contains(q);

      // ── Status filter ─────────────────────────────────────────────
      final matchesStatus =
          _statusFilter == 'all' || device.status == _statusFilter;

      // ── Type filter ───────────────────────────────────────────────
      final matchesType =
          _typeFilter == 'all' || device.deviceType == _typeFilter;

      return matchesSearch && matchesStatus && matchesType;
    }).toList()
      // Sort: offline → degraded → online (problem devices surface first)
      ..sort((a, b) =>
          _statusPriority(a.status).compareTo(_statusPriority(b.status)));
  }

  /// Lower number = shown first.
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
