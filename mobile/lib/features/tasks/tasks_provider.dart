import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../data/models/task_model.dart';
import '../../data/dummy_data.dart';
import '../../services/api_client.dart';
import '../../services/database_helper.dart';

/// TasksProvider manages the state for the monitoring tasks screen.
///
/// Supports:
///   - Two views: Enabled (active) and Disabled tasks
///   - Text search (name, device name, description)
///   - Task type filter (all / snmp / ping / http / tcp / dns)
///   - Status filter (all / success / failed / pending)
///   - Toggle enabled/disabled, run now (simulate)
///
/// On integration day replace DummyData calls with:
///   final r = await ApiService.get('/monitoring/tasks/');
///   _allTasks = (r.data['results'] as List)
///       .map((j) => TaskModel.fromJson(j)).toList();
class TasksProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;

  // ── Data ──────────────────────────────────────────────────────────────────
  List<TaskModel> _allTasks = [];
  List<TaskModel> _scopedTasks = [];
  List<TaskModel> _filteredTasks = [];

  // ── Filter state ──────────────────────────────────────────────────────────
  String _searchQuery = '';
  String _typeFilter = 'all'; // all | snmp | ping | http | tcp | dns
  String _statusFilter = 'all'; // all | success | failed | pending
  int? _assignedToFilterId;

  // ── Getters — state ───────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;

  // ── Getters — data ────────────────────────────────────────────────────────
  List<TaskModel> get tasks => _filteredTasks;
  int get totalCount => _scopedTasks.length;
  int get filteredCount => _filteredTasks.length;

  /// Enabled tasks (sorted: failed first, then by last run).
  List<TaskModel> get enabledTasks {
    final list = _filteredTasks.where((t) => t.enabled).toList();
    list.sort((a, b) {
      // Failed first
      if (a.lastStatus == 'failed' && b.lastStatus != 'failed') return -1;
      if (b.lastStatus == 'failed' && a.lastStatus != 'failed') return 1;
      // Then by last run (most recent first)
      final ra = a.lastRun ?? '';
      final rb = b.lastRun ?? '';
      return rb.compareTo(ra);
    });
    return list;
  }

  /// Disabled tasks.
  List<TaskModel> get disabledTasks =>
      _filteredTasks.where((t) => !t.enabled).toList();

  // ── Getters — counts ──────────────────────────────────────────────────────
  int get enabledCount => _scopedTasks.where((t) => t.enabled).length;
    int get disabledCount => _scopedTasks.where((t) => !t.enabled).length;
  int get failedCount =>
      _scopedTasks.where((t) => t.enabled && t.lastStatus == 'failed').length;

  /// True when any filter or search is active.
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty || _typeFilter != 'all' || _statusFilter != 'all';

  /// Next available ID for a new task.
  int get nextId {
    if (_allTasks.isEmpty) return 1;
    return _allTasks.map((t) => t.id).reduce((a, b) => a > b ? a : b) + 1;
  }

  // ── Getters — filter values ───────────────────────────────────────────────
  String get searchQuery => _searchQuery;
  String get typeFilter => _typeFilter;
  String get statusFilter => _statusFilter;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadTasks() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    // Show cached data immediately for instant UI
    try {
      final cached = await DatabaseHelper.instance.getCachedTasks();
      if (cached.isNotEmpty) {
        _allTasks = cached;
        _applyFilters();
        notifyListeners();
      }
    } catch (_) {/* cache miss — no-op */}

    try {
      _allTasks = await ApiClient.getTasks();
      _applyFilters();
      await DatabaseHelper.instance.cacheTasks(_allTasks);
    } catch (e) {
      if (_allTasks.isEmpty) {
        _allTasks = List<TaskModel>.from(DummyData.tasks);
        _applyFilters();
        _errorMessage = null;
      }
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() => loadTasks();

  // ── Filters ───────────────────────────────────────────────────────────────

  void search(String query) {
    _searchQuery = query.toLowerCase().trim();
    _applyFilters();
    notifyListeners();
  }

  void setTypeFilter(String type) {
    _typeFilter = type;
    _applyFilters();
    notifyListeners();
  }

  void setStatusFilter(String status) {
    _statusFilter = status;
    _applyFilters();
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _typeFilter = 'all';
    _statusFilter = 'all';
    _applyFilters();
    notifyListeners();
  }

  void setAssignedToFilter(int? userId) {
    if (_assignedToFilterId == userId) return;
    _assignedToFilterId = userId;
    _applyFilters();
    notifyListeners();
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  /// Toggle a task's enabled state.
  void toggleEnabled(int taskId) {
    final index = _allTasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _allTasks[index] = _allTasks[index].copyWith(
      enabled: !_allTasks[index].enabled,
    );
    _applyFilters();
    notifyListeners();
  }

  /// Simulate running a task immediately.
  void runNow(int taskId) {
    final index = _allTasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _allTasks[index] = _allTasks[index].copyWith(
      lastRun: DateTime.now().toUtc().toIso8601String(),
      lastStatus: 'completed',
    );
    _applyFilters();
    notifyListeners();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  Future<bool> addTask(TaskModel task) async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      _allTasks.insert(0, task);
      _applyFilters();
      notifyListeners();
      if (!kIsWeb) {
        await DatabaseHelper.instance.upsertTask(task);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTask(TaskModel task) async {
    try {
      await Future.delayed(const Duration(milliseconds: 400));
      final index = _allTasks.indexWhere((t) => t.id == task.id);
      if (index == -1) return false;
      _allTasks[index] = task;
      _applyFilters();
      notifyListeners();
      if (!kIsWeb) {
        await DatabaseHelper.instance.upsertTask(task);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTask(int taskId) async {
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      _allTasks.removeWhere((t) => t.id == taskId);
      _applyFilters();
      notifyListeners();
      if (!kIsWeb) {
        await DatabaseHelper.instance.deleteTask(taskId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Human-readable label for a task type.
  static String taskTypeLabel(String type) {
    switch (type) {
      case 'install':
        return 'Client Install';
      case 'survey':
        return 'Site Survey';
      case 'fault':
        return 'Fault Resolution';
      case 'maintenance':
        return 'Preventive Maintenance';
      case 'change':
        return 'Network Change';
      case 'audit':
        return 'Field Audit';
      case 'expansion':
        return 'Network Expansion';
      case 'support':
        return 'Customer Support';
      case 'marketing':
        return 'Marketing Activity';
      default:
        return type.toUpperCase();
    }
  }

  /// Icon for a task type.
  static IconData taskTypeIcon(String type) {
    switch (type) {
      case 'install':
        return Icons.router_rounded;
      case 'survey':
        return Icons.map_rounded;
      case 'fault':
        return Icons.build_rounded;
      case 'maintenance':
        return Icons.handyman_rounded;
      case 'change':
        return Icons.swap_horiz_rounded;
      case 'audit':
        return Icons.fact_check_rounded;
      case 'expansion':
        return Icons.cell_tower_rounded;
      case 'support':
        return Icons.support_agent_rounded;
      case 'marketing':
        return Icons.campaign_rounded;
      default:
        return Icons.task_alt_rounded;
    }
  }

  /// Colour for a task's last_status.
  static Color statusColor(String status) {
    switch (status) {
      case 'completed':
        return const Color(0xFF16A34A); // green
      case 'partial':
        return const Color(0xFFD97706); // amber
      case 'not_done':
        return const Color(0xFFDC2626); // red
      default:
        return const Color(0xFF64748B); // grey
    }
  }

  /// Format interval seconds to a human-friendly string.
  static String formatInterval(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    return '${seconds ~/ 3600}h ${(seconds % 3600) ~/ 60}m';
  }

  // ── Private ───────────────────────────────────────────────────────────────

  void _applyFilters() {
    _scopedTasks = _assignedToFilterId == null
        ? List<TaskModel>.from(_allTasks)
        : _allTasks.where((t) => t.assignedToId == _assignedToFilterId).toList();

    _filteredTasks = _scopedTasks.where((task) {
      // ── Text search ───────────────────────────────────────────────
      final q = _searchQuery;
      if (q.isNotEmpty) {
        final name = task.name.toLowerCase();
        final device = (task.deviceName ?? '').toLowerCase();
        final desc = (task.description ?? '').toLowerCase();
        final type = taskTypeLabel(task.taskType).toLowerCase();
        if (!name.contains(q) &&
            !device.contains(q) &&
            !desc.contains(q) &&
            !type.contains(q)) {
          return false;
        }
      }

      // ── Type filter ───────────────────────────────────────────────
      if (_typeFilter != 'all' && task.taskType != _typeFilter) {
        return false;
      }

      // ── Status filter ─────────────────────────────────────────────
      if (_statusFilter != 'all' && task.lastStatus != _statusFilter) {
        return false;
      }

      return true;
    }).toList();
  }
}
