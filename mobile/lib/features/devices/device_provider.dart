import 'package:flutter/material.dart';
import '../../data/dummy_data.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';

/// DeviceProvider holds the state for the device list screen.
/// It supports searching and filtering by device type and status.
class DeviceProvider extends ChangeNotifier {

  bool    _isLoading    = false;
  String? _errorMessage;

  List<DeviceModel> _allDevices     = [];
  List<DeviceModel> _filteredDevices = [];

  // Filter state
  String _searchQuery   = '';
  String _statusFilter  = 'all';
  String _typeFilter    = 'all';

  // Getters
  bool              get isLoading       => _isLoading;
  String?           get errorMessage    => _errorMessage;
  List<DeviceModel> get devices         => _filteredDevices;
  String            get searchQuery     => _searchQuery;
  String            get statusFilter    => _statusFilter;
  String            get typeFilter      => _typeFilter;

  Future<void> loadDevices() async {
    _isLoading    = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));

    _allDevices = DummyData.devices;
    _applyFilters();

    _isLoading = false;
    notifyListeners();
  }

  /// Called every time the user types in the search bar.
  void search(String query) {
    _searchQuery = query.toLowerCase();
    _applyFilters();
    notifyListeners();
  }

  /// Called when the user taps a status filter chip.
  void setStatusFilter(String status) {
    _statusFilter = status;
    _applyFilters();
    notifyListeners();
  }

  /// Called when the user taps a device type filter chip.
  void setTypeFilter(String type) {
    _typeFilter = type;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery  = '';
    _statusFilter = 'all';
    _typeFilter   = 'all';
    _applyFilters();
    notifyListeners();
  }

  /// _applyFilters runs every time the search query or a filter changes.
  /// It filters _allDevices and stores the result in _filteredDevices.
  void _applyFilters() {
    _filteredDevices = _allDevices.where((device) {

      // Search filter — matches name, IP, or location
      final matchesSearch = _searchQuery.isEmpty ||
          device.name.toLowerCase().contains(_searchQuery) ||
          device.ipAddress.toLowerCase().contains(_searchQuery) ||
          (device.location?.toLowerCase().contains(_searchQuery) ?? false);

      // Status filter
      final matchesStatus = _statusFilter == 'all' ||
          device.status == _statusFilter;

      // Type filter
      final matchesType = _typeFilter == 'all' ||
          device.deviceType == _typeFilter;

      return matchesSearch && matchesStatus && matchesType;
    }).toList();
  }

  /// Returns the latest metric for a given device ID.
  MetricModel? getLatestMetric(int deviceId) {
    final metrics = DummyData.latestMetrics
        .where((m) => m.deviceId == deviceId)
        .toList();
    return metrics.isNotEmpty ? metrics.first : null;
  }

  Future<void> refresh() => loadDevices();
}