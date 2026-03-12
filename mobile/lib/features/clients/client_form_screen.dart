import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/user_model.dart';
import '../devices/device_provider.dart';
import 'clients_provider.dart';

/// ClientFormScreen handles both Add and Edit modes for customer accounts.
///
/// Pass a [UserModel] via route arguments to enter Edit mode;
/// pass nothing (or null) for Add mode.
class ClientFormScreen extends StatefulWidget {
  const ClientFormScreen({super.key});

  @override
  State<ClientFormScreen> createState() => _ClientFormScreenState();
}

class _ClientFormScreenState extends State<ClientFormScreen>
    with SingleTickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();

  // ── Controllers ───────────────────────────────────────────────────────────
  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;

  // ── Form state ────────────────────────────────────────────────────────────
  String      _plan     = 'Home Basic';
  bool        _isActive = true;
  List<int>   _deviceIds = [];
  bool        _isSaving = false;

  UserModel? _existingClient;
  bool get _isEditing => _existingClient != null;

  // ── Animation ─────────────────────────────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  static const _planOptions = [
    'Home Basic',
    'Home Premium',
    'Business Pro',
    'Business Enterprise',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController();
    _emailCtrl = TextEditingController();

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
    if (_existingClient == null) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is UserModel) {
        _existingClient = args;
        _nameCtrl.text  = args.username;
        _emailCtrl.text = args.email;
        _isActive       = args.isActive;

        final provider = context.read<ClientsProvider>();
        _plan      = provider.getPlan(args.id);
        _deviceIds = List<int>.from(provider.getDeviceIds(args.id));
      }
      _animCtrl.forward();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _handleSave() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = context.read<ClientsProvider>();
    final now = DateTime.now().toUtc().toIso8601String();

    final client = UserModel(
      id:         _existingClient?.id ?? provider.nextId,
      email:      _emailCtrl.text.trim(),
      username:   _nameCtrl.text.trim(),
      role:       AppConstants.roleCustomer,
      isActive:   _isActive,
      dateJoined: _existingClient?.dateJoined ?? now,
      lastLogin:  _existingClient?.lastLogin,
    );

    final success = _isEditing
        ? await provider.updateClient(client,
            plan: _plan, deviceIds: _deviceIds)
        : await provider.addClient(client,
            plan: _plan, deviceIds: _deviceIds);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (success) {
      Navigator.of(context).pop(true);
    } else {
      AppUtils.showSnackbar(
        context,
        'Failed to ${_isEditing ? "update" : "create"} client. Try again.',
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
        backgroundColor: AppColors.background,
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
                    _buildSubscriptionSection(),
                    const SizedBox(height: 20),
                    _buildDevicesSection(),
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
        _isEditing ? 'Edit Client' : 'Add Client',
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  // ── Basic Info Section ────────────────────────────────────────────────────

  Widget _buildBasicInfoSection() {
    return _FormSection(
      title: 'Personal Information',
      icon:  Icons.person_outline_rounded,
      children: [
        _buildTextField(
          controller: _nameCtrl,
          label:      'Full Name',
          hint:       'e.g. John Kamau',
          icon:       Icons.badge_rounded,
          validator:  (v) {
            if (v == null || v.trim().isEmpty) return 'Name is required';
            if (v.trim().length < 3) return 'Name must be at least 3 characters';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildTextField(
          controller:   _emailCtrl,
          label:        'Email Address',
          hint:         'e.g. john@example.com',
          icon:         Icons.email_rounded,
          keyboardType: TextInputType.emailAddress,
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email is required';
            final emailRegex = RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$');
            if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email';
            return null;
          },
        ),
        const SizedBox(height: 14),
        _buildSwitchTile(
          label:    'Account Status',
          subtitle: _isActive ? 'Active — can access services' : 'Inactive — suspended',
          value:    _isActive,
          icon:     Icons.verified_user_rounded,
          color:    _isActive ? AppColors.online : AppColors.offline,
          onChanged: (v) => setState(() => _isActive = v),
        ),
      ],
    );
  }

  // ── Subscription Section ──────────────────────────────────────────────────

  Widget _buildSubscriptionSection() {
    return _FormSection(
      title: 'Subscription',
      icon:  Icons.card_membership_rounded,
      children: [
        _buildDropdown<String>(
          label: 'Plan',
          icon:  Icons.workspace_premium_rounded,
          value: _plan,
          items: _planOptions.map((p) {
            return DropdownMenuItem(value: p, child: Text(p));
          }).toList(),
          onChanged: (v) => setState(() => _plan = v!),
        ),
      ],
    );
  }

  // ── Devices Section ───────────────────────────────────────────────────────

  Widget _buildDevicesSection() {
    final allDevices = context.watch<DeviceProvider>().devices;
    return _FormSection(
      title: 'Assigned Devices',
      icon:  Icons.router_rounded,
      children: [
        Text(
          'Select the devices this client should have access to.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 10),
        ...allDevices.map((device) {
          final isSelected = _deviceIds.contains(device.id);
          return CheckboxListTile(
            dense:         true,
            contentPadding: EdgeInsets.zero,
            value:    isSelected,
            title:    Text(device.name, style: AppTextStyles.body),
            subtitle: Text('${device.ipAddress} • ${device.deviceType}',
                style: AppTextStyles.caption),
            secondary: Icon(
              _deviceIcon(device.deviceType),
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textHint,
            ),
            activeColor: AppColors.primary,
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _deviceIds.add(device.id);
                } else {
                  _deviceIds.remove(device.id);
                }
              });
            },
          );
        }),
        if (_deviceIds.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_deviceIds.length} device${_deviceIds.length != 1 ? "s" : ""} selected',
              style: AppTextStyles.caption.copyWith(color: AppColors.primary),
            ),
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
                    _isEditing ? Icons.check_rounded : Icons.person_add_rounded,
                    color: Colors.white, size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isEditing ? 'Save Changes' : 'Add Client',
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
            ? Icon(icon, size: 20, color: AppColors.textHint)
            : null,
        filled:           true,
        fillColor:        AppColors.surfaceVariant,
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
        prefixIcon: Icon(icon, size: 20, color: AppColors.textHint),
        filled:     true,
        fillColor:  AppColors.surfaceVariant,
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
        color:        AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppColors.divider),
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

  IconData _deviceIcon(String type) {
    switch (type) {
      case AppConstants.deviceRouter: return Icons.router_rounded;
      case AppConstants.deviceSwitch: return Icons.device_hub_rounded;
      case AppConstants.deviceOlt:    return Icons.lan_rounded;
      case AppConstants.deviceAccessPoint:     return Icons.wifi_rounded;
      default:                        return Icons.devices_other_rounded;
    }
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
        color:        AppColors.surface,
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
                    color:        AppColors.primarySurface,
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
