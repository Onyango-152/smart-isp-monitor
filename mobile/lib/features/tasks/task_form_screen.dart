import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/task_model.dart';
import '../../data/models/user_model.dart';
import '../../services/api_client.dart';
import '../auth/auth_provider.dart';
import '../devices/device_provider.dart';
import 'tasks_provider.dart';

/// TaskFormScreen handles both Add and Edit modes for monitoring tasks.
///
/// Pass a [TaskModel] via route arguments to enter Edit mode;
/// pass nothing (or null) for Add mode.
///
/// On save the screen pops and returns `true` to the caller.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen>
    with SingleTickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;

  // ── Form state ────────────────────────────────────────────────────────────
  String  _taskType     = 'install';
  int     _intervalSecs = 300;
  int     _timeoutSecs  = 5;
  bool    _enabled      = true;
  int?    _deviceId;
  String? _deviceName;
  int?    _assignedToId;
  bool    _isSaving     = false;
  String? _templateKey;
  bool    _techLoading  = false;
  bool    _techLoaded   = false;
  String? _techError;
  List<UserModel> _technicians = [];

  TaskModel? _existingTask;
  bool get _isEditing => _existingTask != null;

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  // ── Interval presets ──────────────────────────────────────────────────────
  static const _intervalOptions = [
    (30,   '30 seconds'),
    (60,   '1 minute'),
    (120,  '2 minutes'),
    (300,  '5 minutes'),
    (600,  '10 minutes'),
    (1800, '30 minutes'),
    (3600, '1 hour'),
  ];

  static const _timeoutOptions = [
    (3,  '3 seconds'),
    (5,  '5 seconds'),
    (10, '10 seconds'),
    (15, '15 seconds'),
    (30, '30 seconds'),
  ];

  static const _taskTemplates = <_TaskTemplate>[
    _TaskTemplate(
      key: 'install_clients',
      name: 'Install 3 clients',
      description: 'Checklist:\n'
          '- Install CPE\n'
          '- Align antenna\n'
          '- Configure router\n'
          '- Verify throughput\n'
          '- Photos + client sign-off\n'
          'Status:\n'
          '- Completed: 3 installs + evidence\n'
          '- Partial: 1-2 installs\n'
          '- Not done: 0 installs',
    ),
    _TaskTemplate(
      key: 'site_survey',
      name: 'CO site survey',
      description: 'Checklist:\n'
          '- LOS check\n'
          '- Signal strength\n'
          '- Obstruction notes\n'
          '- Photos\n'
          '- GPS pin',
    ),
    _TaskTemplate(
      key: 'fault_resolution',
      name: 'Fault resolution visit',
      description: 'Checklist:\n'
          '- Replace CPE if needed\n'
          '- Re-terminate fiber\n'
          '- Change power supply\n'
          '- Port swap\n'
          '- Final verification',
    ),
    _TaskTemplate(
      key: 'preventive_maintenance',
      name: 'Preventive maintenance',
      description: 'Checklist:\n'
          '- Clean/inspect tower\n'
          '- Tighten brackets\n'
          '- Label cables\n'
          '- Photo evidence',
    ),
    _TaskTemplate(
      key: 'network_changes',
      name: 'Network change',
      description: 'Checklist:\n'
          '- VLAN setup\n'
          '- IP changes\n'
          '- Firmware upgrade\n'
          '- Config backup/restore',
    ),
    _TaskTemplate(
      key: 'field_audit',
      name: 'Field audit',
      description: 'Checklist:\n'
          '- Inventory check\n'
          '- Serial/MAC verification\n'
          '- Cable trace\n'
          '- Photos',
    ),
    _TaskTemplate(
      key: 'network_expansion',
      name: 'Network expansion',
      description: 'Checklist:\n'
          '- Pole install\n'
          '- New AP mounting\n'
          '- Sector alignment\n'
          '- Verification',
    ),
    _TaskTemplate(
      key: 'customer_support',
      name: 'Customer support visit',
      description: 'Checklist:\n'
          '- Wi-Fi optimization\n'
          '- Coverage tuning\n'
          '- Speed validation\n'
          '- Client sign-off',
    ),
    _TaskTemplate(
      key: 'ads_kathem',
      name: 'Run ads at Kathembony',
      description: 'Checklist:\n'
          '- Place ads at agreed spots\n'
          '- Photos\n'
          '- Brief report\n'
          'Status:\n'
          '- Completed: all spots covered\n'
          '- Partial: some locations covered\n'
          '- Not done: none placed',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl        = TextEditingController();
    _descriptionCtrl = TextEditingController();

    _animCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_existingTask == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is TaskModel) {
        _existingTask = args;
        _nameCtrl.text        = args.name;
        _descriptionCtrl.text = args.description ?? '';
        _taskType     = args.taskType;
        _intervalSecs = args.intervalSecs;
        _timeoutSecs  = args.timeoutSecs;
        _enabled      = args.enabled;
        _deviceId     = args.deviceId;
        _deviceName   = args.deviceName;
        _assignedToId = args.assignedToId;
      }
      _animCtrl.forward();
    }
    _loadTechniciansIfNeeded();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  bool get _canAssignTechnicians {
    final auth = context.read<AuthProvider>();
    return auth.isManager || auth.isAdmin;
  }

  Future<void> _loadTechniciansIfNeeded({bool force = false}) async {
    if (_techLoaded && !force) return;
    if (!_canAssignTechnicians) {
      _techLoaded = true;
      return;
    }

    setState(() {
      _techLoading = true;
      _techError = null;
    });

    try {
      final list = await ApiClient.getTechnicians();
      if (!mounted) return;
      setState(() {
        _technicians = list;
        _techError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _techError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _techError = 'Failed to load technicians.');
    } finally {
      if (mounted) {
        setState(() => _techLoading = false);
      }
      _techLoaded = true;
    }
  }

  String? _resolveTechnicianName(int? id) {
    if (id == null) return null;
    for (final tech in _technicians) {
      if (tech.id == id) return tech.username;
    }
    return null;
  }

  int? _assignedDropdownValue() {
    if (_assignedToId == null) return null;
    final exists = _technicians.any((t) => t.id == _assignedToId);
    return exists ? _assignedToId : null;
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<TasksProvider>();
    final auth = context.read<AuthProvider>();
    final canAssign = auth.isManager || auth.isAdmin;
    final now = DateTime.now().toUtc().toIso8601String();
    final assignedToId = canAssign ? _assignedToId : _existingTask?.assignedToId;
    final assignedToName = _resolveTechnicianName(assignedToId)
      ?? _existingTask?.assignedToName;

    final task = TaskModel(
      id:           _existingTask?.id ?? provider.nextId,
      name:         _nameCtrl.text.trim(),
      description:  _descriptionCtrl.text.trim().isEmpty
          ? null : _descriptionCtrl.text.trim(),
      deviceId:     _deviceId,
      deviceName:   _deviceName,
      taskType:     _taskType,
      intervalSecs: _intervalSecs,
      timeoutSecs:  _timeoutSecs,
      enabled:      _enabled,
      lastRun:      _existingTask?.lastRun,
      lastStatus:   _existingTask?.lastStatus ?? 'not_done',
      createdAt:    _existingTask?.createdAt ?? now,
      updatedAt:    _isEditing ? now : null,
      assignedToId: assignedToId,
      assignedToName: assignedToName,
    );

    final success = _isEditing
        ? await provider.updateTask(task)
        : await provider.addTask(task);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      AppUtils.showSnackbar(
        context,
        'Failed to ${_isEditing ? "update" : "create"} task. Try again.',
        isError: true,
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: _buildAppBar(),
        body: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBasicInfoSection(),
                    const SizedBox(height: 20),
                    _buildScheduleSection(),
                    const SizedBox(height: 20),
                    _buildTargetSection(),
                    if (_canAssignTechnicians) ...[
                      const SizedBox(height: 20),
                      _buildAssignmentSection(),
                    ],
                    const SizedBox(height: 20),
                    _buildDetailsSection(),
                    const SizedBox(height: 28),
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── App Bar ───────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin:  Alignment.topLeft,
            end:    Alignment.bottomRight,
            colors: [
              AppColors.appBarGradientStart,
              AppColors.appBarGradientEnd,
            ],
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.close_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        _isEditing ? 'Edit Task' : 'Create Task',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  // ── Basic Info Section ────────────────────────────────────────────────────

  Widget _buildBasicInfoSection() {
    return _FormSection(
      title: 'Basic Information',
      icon:  Icons.info_outline_rounded,
      children: [
        _buildDropdown<String?>(
          label:   'Task Template',
          icon:    Icons.list_alt_rounded,
          value:   _templateKey,
          items: [
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('Custom task (no template)'),
            ),
            ..._taskTemplates.map((t) => DropdownMenuItem<String?>(
              value: t.key,
              child: Text(t.name),
            )),
          ],
          onChanged: (v) {
            setState(() {
              _templateKey = v;
              final template = _taskTemplates
                  .where((t) => t.key == v)
                  .cast<_TaskTemplate?>()
                  .firstWhere((t) => t != null, orElse: () => null);
              if (template != null) {
                _nameCtrl.text = template.name;
                _descriptionCtrl.text = template.description;
              }
            });
          },
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller: _nameCtrl,
          label:      'Task Name',
          hint:       'e.g. Core Router SNMP Poll',
          icon:       Icons.task_alt_rounded,
          validator:  (v) {
            if (v == null || v.trim().isEmpty) return 'Name is required';
            if (v.trim().length < 3) return 'Name must be at least 3 characters';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildDropdown<String>(
          label:   'Task Type',
          icon:    Icons.category_rounded,
          value:   _taskType,
          items: const [
            DropdownMenuItem(value: 'install', child: Text('Client Install')),
            DropdownMenuItem(value: 'survey', child: Text('Site Survey')),
            DropdownMenuItem(value: 'fault', child: Text('Fault Resolution')),
            DropdownMenuItem(value: 'maintenance', child: Text('Preventive Maintenance')),
            DropdownMenuItem(value: 'change', child: Text('Network Change')),
            DropdownMenuItem(value: 'audit', child: Text('Field Audit')),
            DropdownMenuItem(value: 'expansion', child: Text('Network Expansion')),
            DropdownMenuItem(value: 'support', child: Text('Customer Support')),
            DropdownMenuItem(value: 'marketing', child: Text('Marketing Activity')),
          ],
          onChanged: (v) => setState(() => _taskType = v!),
        ),
        const SizedBox(height: 14),
        _buildSwitchTile(
          label:    'Enabled',
          subtitle: _enabled
              ? 'Task will run on schedule'
              : 'Task is paused',
          value:    _enabled,
          icon:     Icons.power_settings_new_rounded,
          color:    _enabled ? AppColors.primary : AppColors.primaryDark,
          onChanged: (v) => setState(() => _enabled = v),
        ),
      ],
    );
  }

  // ── Schedule Section ──────────────────────────────────────────────────────

  Widget _buildScheduleSection() {
    return _FormSection(
      title: 'Schedule',
      icon:  Icons.schedule_rounded,
      children: [
        _buildDropdown<int>(
          label:   'Polling Interval',
          icon:    Icons.repeat_rounded,
          value:   _intervalSecs,
          items: _intervalOptions.map((o) {
            return DropdownMenuItem(value: o.$1, child: Text(o.$2));
          }).toList(),
          onChanged: (v) => setState(() => _intervalSecs = v!),
        ),
        const SizedBox(height: 14),
        _buildDropdown<int>(
          label:   'Timeout',
          icon:    Icons.timer_outlined,
          value:   _timeoutSecs,
          items: _timeoutOptions.map((o) {
            return DropdownMenuItem(value: o.$1, child: Text(o.$2));
          }).toList(),
          onChanged: (v) => setState(() => _timeoutSecs = v!),
        ),
      ],
    );
  }

  // ── Target Section ────────────────────────────────────────────────────────

  Widget _buildTargetSection() {
    final devices = context.watch<DeviceProvider>().devices;
    return _FormSection(
      title: 'Target Device',
      icon:  Icons.router_rounded,
      children: [
        DropdownButtonFormField<int?>(
          value: _deviceId,
          decoration: InputDecoration(
            labelText: 'Device (optional)',
            prefixIcon: Icon(Icons.device_hub_rounded,
                size: 20, color: AppColors.textHintOf(context)),
            filled:     true,
            fillColor:  AppColors.surfaceVariantOf(context),
            border:        _inputBorder(),
            enabledBorder: _inputBorder(),
            focusedBorder: _inputBorder(color: AppColors.primary),
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
          ),
          style: AppTextStyles.body,
          items: [
            const DropdownMenuItem<int?>(
              value: null,
              child: Text('None — applies to all devices'),
            ),
            ...devices.map((d) => DropdownMenuItem<int?>(
              value: d.id,
              child: Text(d.name),
            )),
          ],
          onChanged: (v) {
            setState(() {
              _deviceId = v;
              _deviceName = v != null
                  ? devices.firstWhere((d) => d.id == v).name
                  : null;
            });
          },
        ),
        const SizedBox(height: 8),
        Text(
          _deviceId == null
              ? 'Task will target all active devices'
              : 'Task will target "$_deviceName" only',
          style: AppTextStyles.caption,
        ),
      ],
    );
  }

  // ── Assignment Section ───────────────────────────────────────────────────

  Widget _buildAssignmentSection() {
    return _FormSection(
      title: 'Assignment',
      icon:  Icons.badge_outlined,
      children: [
        if (_techLoading) ...[
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Text('Loading technicians…', style: AppTextStyles.caption),
            ],
          ),
        ] else if (_techError != null) ...[
          Text(
            _techError!,
            style: AppTextStyles.caption.copyWith(color: AppColors.offline),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _loadTechniciansIfNeeded(force: true),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
          ),
        ] else ...[
          _buildDropdown<int?>(
            label: 'Assigned Technician',
            icon:  Icons.engineering_rounded,
            value: _assignedDropdownValue(),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Unassigned'),
              ),
              ..._technicians.map((t) => DropdownMenuItem<int?>(
                value: t.id,
                child: Text(t.username),
              )),
            ],
            onChanged: (v) => setState(() => _assignedToId = v),
          ),
          const SizedBox(height: 8),
          Text(
            _assignedToId == null
                ? 'Unassigned tasks are hidden from technicians.'
                : 'Assigned to ${_resolveTechnicianName(_assignedToId) ?? "technician"}',
            style: AppTextStyles.caption,
          ),
          if (_technicians.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'No technicians found. Add a technician to assign tasks.',
              style: AppTextStyles.caption,
            ),
          ],
        ],
      ],
    );
  }

  // ── Details Section ───────────────────────────────────────────────────────

  Widget _buildDetailsSection() {
    return _FormSection(
      title: 'Description',
      icon:  Icons.description_outlined,
      children: [
        _buildTextField(
          controller: _descriptionCtrl,
          label:      'Description',
          hint:       'Describe what this task monitors (optional)',
          icon:       Icons.notes_rounded,
          maxLines:   3,
        ),
      ],
    );
  }

  // ── Save Button ───────────────────────────────────────────────────────────

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          colors: [AppColors.appBarGradientStart, AppColors.appBarGradientEnd],
        ),
        boxShadow: [
          BoxShadow(
            color:      AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap:        _isSaving ? null : _handleSave,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSaving) ...[
                  const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Saving…',
                    style: TextStyle(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700),
                  ),
                ] else ...[
                  Icon(
                    _isEditing
                        ? Icons.check_rounded
                        : Icons.add_rounded,
                    color: Colors.white, size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing ? 'Save Changes' : 'Create Task',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 16,
                      fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Reusable field builders ───────────────────────────────────────────────

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    IconData? icon,
    TextInputType keyboardType = TextInputType.text,
    int  maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      maxLines:     maxLines,
      validator:    validator,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText:  label,
        hintText:   hint,
        prefixIcon: icon != null
            ? Icon(icon, size: 20, color: AppColors.textHintOf(context))
            : null,
        filled:           true,
        fillColor:        AppColors.surfaceVariantOf(context),
        border:           _inputBorder(),
        enabledBorder:    _inputBorder(),
        focusedBorder:    _inputBorder(color: AppColors.primary),
        errorBorder:      _inputBorder(color: AppColors.offline),
        focusedErrorBorder: _inputBorder(color: AppColors.offline),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required IconData icon,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value:    value,
      items:    items,
      onChanged: onChanged,
      style: AppTextStyles.body,
      decoration: InputDecoration(
        labelText:  label,
        prefixIcon: Icon(icon, size: 20, color: AppColors.textHintOf(context)),
        filled:     true,
        fillColor:  AppColors.surfaceVariantOf(context),
        border:        _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(color: AppColors.primary),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String label,
    required String subtitle,
    required bool   value,
    required IconData icon,
    required Color    color,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color:        AppColors.surfaceVariantOf(context),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.dividerOf(context)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.heading3),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch.adaptive(
            value:       value,
            onChanged:   onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  OutlineInputBorder _inputBorder({Color color = AppColors.divider}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide:   BorderSide(color: color, width: 1),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FormSection — titled card grouping related fields
// ─────────────────────────────────────────────────────────────────────────────

class _FormSection extends StatelessWidget {
  final String       title;
  final IconData     icon;
  final List<Widget> children;

  const _FormSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color:        Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow:    AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color:        AppColors.primarySurfaceOf(context),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(title, style: AppTextStyles.heading3),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskTemplate {
  final String key;
  final String name;
  final String description;
  const _TaskTemplate({
    required this.key,
    required this.name,
    required this.description,
  });
}
