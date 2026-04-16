import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/device_model.dart';
import '../auth/auth_provider.dart';
import 'device_provider.dart';

/// DeviceFormScreen handles both Add and Edit modes.
///
/// Pass a [DeviceModel] via route arguments to enter Edit mode;
/// pass nothing (or null) for Add mode.
///
/// On save the screen pops and returns `true` to the caller so it
/// can show a success snackbar.
class DeviceFormScreen extends StatefulWidget {
  const DeviceFormScreen({super.key});

  @override
  State<DeviceFormScreen> createState() => _DeviceFormScreenState();
}

class _DeviceFormScreenState extends State<DeviceFormScreen> {

  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ipCtrl;
  late final TextEditingController _macCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _snmpCommunityCtrl;

  // ── Form state ────────────────────────────────────────────────────────────
  String _deviceType   = AppConstants.deviceRouter;
  bool   _snmpEnabled  = true;
  bool   _isActive     = true;
  bool   _isSaving     = false;
  String? _saveError;
  bool   _readyToSave  = false;

  DeviceModel? _existingDevice;
  bool get _isEditing => _existingDevice != null;

  @override
  void initState() {
    super.initState();

    _nameCtrl          = TextEditingController();
    _ipCtrl            = TextEditingController();
    _macCtrl           = TextEditingController();
    _locationCtrl      = TextEditingController();
    _descriptionCtrl   = TextEditingController();
    _snmpCommunityCtrl = TextEditingController(text: 'public');

    _nameCtrl.addListener(_updateReadyToSave);
    _ipCtrl.addListener(_updateReadyToSave);
    _snmpCommunityCtrl.addListener(_updateReadyToSave);

    _updateReadyToSave();

  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Populate fields when editing an existing device
    if (_existingDevice == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is DeviceModel) {
        _existingDevice = args;
        _nameCtrl.text          = args.name;
        _ipCtrl.text            = args.ipAddress;
        _macCtrl.text           = args.macAddress ?? '';
        _locationCtrl.text      = args.location ?? '';
        _descriptionCtrl.text   = args.description ?? '';
        _snmpCommunityCtrl.text = args.snmpCommunity;
        _deviceType  = args.deviceType;
        _snmpEnabled = args.snmpEnabled;
        _isActive    = args.isActive;
        _updateReadyToSave();
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_updateReadyToSave);
    _ipCtrl.removeListener(_updateReadyToSave);
    _snmpCommunityCtrl.removeListener(_updateReadyToSave);
    _nameCtrl.dispose();
    _ipCtrl.dispose();
    _macCtrl.dispose();
    _locationCtrl.dispose();
    _descriptionCtrl.dispose();
    _snmpCommunityCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  void _updateReadyToSave() {
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final hasIp = _ipCtrl.text.trim().isNotEmpty;
    final hasSnmp = !_snmpEnabled || _snmpCommunityCtrl.text.trim().isNotEmpty;
    final ready = hasName && hasIp && hasSnmp;
    if (ready != _readyToSave) {
      setState(() => _readyToSave = ready);
    }
  }

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    String? errorMessage;

    try {
      final provider = context.read<DeviceProvider>();
      final now = DateTime.now().toUtc().toIso8601String();

      final device = DeviceModel(
        id:            _existingDevice?.id ?? provider.nextId,
        name:          _nameCtrl.text.trim(),
        ipAddress:     _ipCtrl.text.trim(),
        macAddress:    _macCtrl.text.trim().isEmpty
            ? null : _macCtrl.text.trim(),
        deviceType:    _deviceType,
        status:        _existingDevice?.status ?? AppConstants.statusUnknown,
        location:      _locationCtrl.text.trim().isEmpty
            ? null : _locationCtrl.text.trim(),
        description:   _descriptionCtrl.text.trim().isEmpty
            ? null : _descriptionCtrl.text.trim(),
        snmpEnabled:   _snmpEnabled,
        snmpCommunity: _snmpCommunityCtrl.text.trim(),
        isActive:      _isActive,
        lastSeen:      _existingDevice?.lastSeen,
        createdAt:     _existingDevice?.createdAt ?? now,
      );

      final success = _isEditing
          ? await provider.updateDevice(device)
          : await provider.addDevice(device);

      if (!mounted) return;

      if (success) {
        Navigator.of(context).pop(true);
        return;
      }

      errorMessage = provider.errorMessage;
    } catch (_) {
      errorMessage = null;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (mounted) {
      final message = errorMessage ??
          'Failed to ${_isEditing ? "update" : "add"} device. Try again.';
      setState(() => _saveError = message);
      AppUtils.showSnackbar(context, message, isError: true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAdmin) {
      return Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: _buildAppBar(),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Only admins can add or edit devices.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: AppColors.bg(context),
        appBar: _buildAppBar(),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildBasicInfoSection(),
                const SizedBox(height: 20),
                _buildNetworkSection(),
                const SizedBox(height: 20),
                _buildSnmpSection(),
                const SizedBox(height: 20),
                _buildDetailsSection(),
                const SizedBox(height: 28),
                if (_saveError != null) ...[
                  Text(
                    _saveError!,
                    style: const TextStyle(
                      color: AppColors.offline,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _buildSaveButton(),
              ],
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
        icon: const Icon(Icons.close_rounded, color: AppColors.textOnDark),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        _isEditing ? 'Edit Device' : 'Add Device',
        style: const TextStyle(color: AppColors.textOnDark),
      ),
    );
  }

  // ── Basic Info Section ────────────────────────────────────────────────────

  Widget _buildBasicInfoSection() {
    return _FormSection(
      title: 'Basic Information',
      icon:  Icons.info_outline_rounded,
      children: [
        // Device Name
        _buildTextField(
          controller: _nameCtrl,
          label:      'Device Name',
          hint:       'e.g. Core Router',
          icon:       Icons.device_hub_rounded,
          validator:  (v) {
            if (v == null || v.trim().isEmpty) return 'Name is required';
            if (v.trim().length < 2) return 'Name must be at least 2 characters';
            return null;
          },
        ),
        const SizedBox(height: 14),

        // Device Type
        _buildDropdown(
          label:   'Device Type',
          icon:    Icons.category_rounded,
          value:   _deviceType,
          items: const [
            DropdownMenuItem(value: AppConstants.deviceRouter,
                child: Text('Router')),
            DropdownMenuItem(value: AppConstants.deviceSwitch,
                child: Text('Switch')),
            DropdownMenuItem(value: AppConstants.deviceOlt,
                child: Text('OLT')),
            DropdownMenuItem(value: AppConstants.deviceAccessPoint,
                child: Text('Access Point')),
          ],
          onChanged: (v) {
            setState(() => _deviceType = v!);
            _updateReadyToSave();
          },
        ),
        const SizedBox(height: 14),

        // Active toggle
        _buildSwitchTile(
          label:    'Active',
          subtitle: _isActive
              ? 'Device will be monitored'
              : 'Device monitoring paused',
          value:    _isActive,
          icon:     Icons.power_settings_new_rounded,
          color:    _isActive ? AppColors.online : AppColors.offline,
          onChanged: (v) => setState(() => _isActive = v),
        ),
      ],
    );
  }

  // ── Network Section ───────────────────────────────────────────────────────

  Widget _buildNetworkSection() {
    return _FormSection(
      title: 'Network',
      icon:  Icons.lan_rounded,
      children: [
        // IP Address
        _buildTextField(
          controller: _ipCtrl,
          label:      'IP Address',
          hint:       'e.g. 192.168.1.1',
          icon:       Icons.language_rounded,
          keyboardType: TextInputType.number,
          isMono:     true,
          validator:  (v) {
            if (v == null || v.trim().isEmpty) return 'IP address is required';
            final parts = v.trim().split('.');
            if (parts.length != 4) return 'Enter a valid IPv4 address';
            for (final p in parts) {
              final n = int.tryParse(p);
              if (n == null || n < 0 || n > 255) {
                return 'Enter a valid IPv4 address';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 14),

        // MAC Address
        _buildTextField(
          controller: _macCtrl,
          label:      'MAC Address',
          hint:       'e.g. AA:BB:CC:DD:EE:FF (optional)',
          icon:       Icons.memory_rounded,
          isMono:     true,
          validator:  (v) {
            if (v == null || v.trim().isEmpty) return null; // optional
            final mac = RegExp(
                r'^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$');
            if (!mac.hasMatch(v.trim())) {
              return 'Format: AA:BB:CC:DD:EE:FF';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ── SNMP Section ──────────────────────────────────────────────────────────

  Widget _buildSnmpSection() {
    return _FormSection(
      title: 'SNMP Configuration',
      icon:  Icons.settings_ethernet_rounded,
      children: [
        // SNMP toggle
        _buildSwitchTile(
          label:    'SNMP Enabled',
          subtitle: _snmpEnabled
              ? 'Device will be polled via SNMP'
              : 'SNMP polling disabled — ICMP only',
          value:    _snmpEnabled,
          icon:     Icons.swap_horiz_rounded,
          color:    _snmpEnabled ? AppColors.primary : AppColors.textHint,
          onChanged: (v) {
            setState(() => _snmpEnabled = v);
            _updateReadyToSave();
          },
        ),
        if (_snmpEnabled) ...[
          const SizedBox(height: 14),
          _buildTextField(
            controller: _snmpCommunityCtrl,
            label:      'SNMP Community String',
            hint:       'e.g. public',
            icon:       Icons.vpn_key_rounded,
            validator:  (v) {
              if (_snmpEnabled && (v == null || v.trim().isEmpty)) {
                return 'Community string is required when SNMP is enabled';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  // ── Details Section ───────────────────────────────────────────────────────

  Widget _buildDetailsSection() {
    return _FormSection(
      title: 'Additional Details',
      icon:  Icons.description_outlined,
      children: [
        // Location
        _buildTextField(
          controller: _locationCtrl,
          label:      'Location',
          hint:       'e.g. Server Room, Block A (optional)',
          icon:       Icons.location_on_rounded,
        ),
        const SizedBox(height: 14),

        // Description
        _buildTextField(
          controller: _descriptionCtrl,
          label:      'Description',
          hint:       'Brief description of this device (optional)',
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
            color:      AppColors.primary.withOpacity(0.3),
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
                        strokeWidth: 2, color: AppColors.textOnDark),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Saving…',
                    style: TextStyle(
                      color: AppColors.textOnDark, fontSize: 16,
                      fontWeight: FontWeight.w700),
                  ),
                ] else ...[
                  Icon(
                    _isEditing
                        ? Icons.check_rounded
                        : Icons.add_rounded,
                    color: AppColors.textOnDark, size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing
                      ? 'Save Changes'
                      : (_readyToSave ? 'Save Device' : 'Add Device'),
                    style: const TextStyle(
                      color: AppColors.textOnDark, fontSize: 16,
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
    bool isMono = false,
    int  maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller:   controller,
      keyboardType: keyboardType,
      maxLines:     maxLines,
      validator:    validator,
      style: isMono ? AppTextStyles.mono : AppTextStyles.body,
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

  Widget _buildDropdown({
    required String label,
    required IconData icon,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
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
          // Header
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
                  child: Icon(icon, size: 16, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Text(title, style: AppTextStyles.heading2),
              ],
            ),
          ),
          const Divider(height: 1),
          // Fields
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
