import 'package:flutter/material.dart';
import '../../data/models/report_model.dart';
import '../../services/api_client.dart';

class ReportsProvider extends ChangeNotifier {
  bool    _isLoading    = false;
  String? _errorMessage;

  List<ReportModel> _allReports      = [];
  List<ReportModel> _filteredReports = [];

  String _typeFilter = 'all'; // all, daily, weekly, monthly

  bool            get isLoading      => _isLoading;
  String?         get errorMessage   => _errorMessage;
  List<ReportModel> get reports      => _filteredReports;
  String          get typeFilter     => _typeFilter;

  ReportsProvider() {
    loadReports();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadReports() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiClient.get('/reports/');
      final list = data is List ? data : (data['results'] as List? ?? []);
      _allReports = list
          .map((j) => ReportModel.fromJson(j as Map<String, dynamic>))
          .toList();
      _applyFilter();
    } catch (e) {
      _errorMessage = 'Failed to load reports';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async => loadReports();

  // ── Filter ────────────────────────────────────────────────────────────────

  void setTypeFilter(String type) {
    _typeFilter = type;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_typeFilter == 'all') {
      _filteredReports = List.of(_allReports);
    } else {
      _filteredReports =
          _allReports.where((r) => r.type == _typeFilter).toList();
    }
  }

  // ── Summary getters (latest completed report) ─────────────────────────────

  ReportModel? get latestCompleted {
    final completed =
        _allReports.where((r) => r.status == 'completed').toList();
    if (completed.isEmpty) return null;
    return completed.first;
  }
}
