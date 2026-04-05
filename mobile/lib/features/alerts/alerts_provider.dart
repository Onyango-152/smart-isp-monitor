import 'package:flutter/material.dart';
import '../../core/constants.dart';
import '../../data/models/alert_model.dart';
import '../../data/dummy_data.dart';
import '../../services/api_client.dart';
import '../../services/database_helper.dart';

/// AlertsProvider manages the state for the alerts screen.
///
/// Holds all alerts, splits them into active and resolved,
/// and handles acknowledge and resolve actions.
///
/// On integration day replace DummyData calls with:
///   final r = await ApiService.get(AppConstants.alertsEndpoint);
///   _allAlerts = (r.data['results'] as List)
///       .map((j) => AlertModel.fromJson(j)).toList();
class AlertsProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;

  // ── Data ──────────────────────────────────────────────────────────────────
  List<AlertModel> _allAlerts = [];

  // ── Getters — state ───────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  // ── Getters — lists ───────────────────────────────────────────────────────

  /// Unresolved alerts, newest triggered first.
  List<AlertModel> get activeAlerts {
    final list = _allAlerts.where((a) => !a.isResolved).toList()
      ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));
    return list;
  }

  /// Resolved alerts, most recently resolved first.
  List<AlertModel> get resolvedAlerts {
    final list = _allAlerts.where((a) => a.isResolved).toList()
      ..sort((a, b) {
        final ra = a.resolvedAt ?? '';
        final rb = b.resolvedAt ?? '';
        return rb.compareTo(ra);
      });
    return list;
  }

  // ── Getters — counts ──────────────────────────────────────────────────────
  int get criticalCount => activeAlerts
      .where((a) => a.severity == AppConstants.severityCritical)
      .length;

  int get highCount =>
      activeAlerts.where((a) => a.severity == AppConstants.severityHigh).length;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadAlerts() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Show cached data immediately for instant UI
    try {
      final cached = await DatabaseHelper.instance.getCachedAlerts();
      if (cached.isNotEmpty) {
        _allAlerts = cached;
        notifyListeners();
      }
    } catch (_) {/* cache miss — no-op */}

    try {
      _allAlerts = await ApiClient.getAlerts();
      await DatabaseHelper.instance.cacheAlerts(_allAlerts);
    } catch (e) {
      if (_allAlerts.isEmpty) {
        _allAlerts = List<AlertModel>.from(DummyData.alerts);
        _errorMessage = null;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadAlerts();

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Marks an alert as acknowledged.
  void acknowledgeAlert(int alertId) {
    _updateAlert(alertId, isAcknowledged: true);
    // Sync to backend (fire and forget — optimistic UI)
    ApiClient.acknowledgeAlert(alertId).onError((_, __) {});
  }

  /// Marks an alert as resolved (also sets isAcknowledged = true).
  void resolveAlert(int alertId) {
    _updateAlert(
      alertId,
      isResolved: true,
      isAcknowledged: true,
      resolvedAt: DateTime.now().toIso8601String(),
    );
    // Sync to backend (fire and forget — optimistic UI)
    ApiClient.resolveAlert(alertId).onError((_, __) {});
  }

  // ── Multi-select ──────────────────────────────────────────────────────────

  bool _selectMode = false;
  final Set<int> _selectedIds = {};

  bool get isSelectMode => _selectMode;
  Set<int> get selectedIds => _selectedIds;
  int get selectedCount => _selectedIds.length;

  void enterSelectMode(int alertId) {
    _selectMode = true;
    _selectedIds.add(alertId);
    notifyListeners();
  }

  void exitSelectMode() {
    _selectMode = false;
    _selectedIds.clear();
    notifyListeners();
  }

  void toggleSelection(int alertId) {
    if (_selectedIds.contains(alertId)) {
      _selectedIds.remove(alertId);
      if (_selectedIds.isEmpty) _selectMode = false;
    } else {
      _selectedIds.add(alertId);
    }
    notifyListeners();
  }

  void selectAll(List<AlertModel> alerts) {
    _selectedIds.addAll(alerts.map((a) => a.id));
    notifyListeners();
  }

  void acknowledgeSelected() {
    for (final id in _selectedIds.toList()) {
      _updateAlert(id, isAcknowledged: true);
    }
    _selectedIds.clear();
    _selectMode = false;
    notifyListeners();
  }

  void resolveSelected() {
    final now = DateTime.now().toIso8601String();
    for (final id in _selectedIds.toList()) {
      _updateAlert(id, isResolved: true, isAcknowledged: true, resolvedAt: now);
    }
    _selectedIds.clear();
    _selectMode = false;
    notifyListeners();
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _updateAlert(
    int alertId, {
    bool? isAcknowledged,
    bool? isResolved,
    String? resolvedAt,
  }) {
    final index = _allAlerts.indexWhere((a) => a.id == alertId);
    if (index == -1) return;

    final old = _allAlerts[index];
    final updated = AlertModel(
      id: old.id,
      deviceId: old.deviceId,
      deviceName: old.deviceName,
      alertType: old.alertType,
      severity: old.severity,
      message: old.message,
      details: old.details,
      isResolved: isResolved ?? old.isResolved,
      isAcknowledged: isAcknowledged ?? old.isAcknowledged,
      triggeredAt: old.triggeredAt,
      resolvedAt: resolvedAt ?? old.resolvedAt,
    );

    _allAlerts[index] = updated;
    notifyListeners();
    // Persist the change to the local cache (fire and forget)
    DatabaseHelper.instance.upsertAlert(updated);
  }
}
