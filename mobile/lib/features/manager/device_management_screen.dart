import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/device_model.dart';
import '../../services/api_client.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DeviceManagementProvider
// ─────────────────────────────────────────────────────────────────────────────

class DeviceManagementProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String _search = '';
  String get search => _search;

  // Local mutable copy so add/deactivate work without touching DummyData
  late List<_EditableDevice> _devices;

  DeviceManagementProvider() {
    _devices = [];
  }

  List<_EditableDevice> get filtered {
    if (_search.isEmpty) return _devices;
    final q = _search.toLowerCase();
    return _devices.where((d) =>
        d.model.name.toLowerCase().contains(q) ||
        d.model.ipAddress.contains(q) ||
        (d.model.location ?? '').toLowerCase().contains(q)).toList();
  }

  void setSearch(String q) {
    _search = q;
    notifyListeners();
  }

  void deactivate(int id) {
    final idx = _devices.indexWhere((d) => d.model.id == id);
    if (idx >= 0) {
      _devices[idx] = _EditableDevice(
        model:    _devices[idx].model,
        isActive: false,
      );
      notifyListeners();
    }
  }

  void reactivate(int id) {
    final idx = _devices.indexWhere((d) => d.model.id == id);
    if (idx >= 0) {
      _devices[idx] = _EditableDevice(
        model:    _devices[idx].model,
        isActive: true,
      );
      notifyListeners();
    }
  }

  void saveEdit(_EditableDevice updated) {
    final idx = _devices.indexWhere((d) => d.model.id == updated.model.id);
    if (idx >= 0) {
      _devices[idx] = updated;
      notifyListeners();
    }
  }

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final fetched = await ApiClient.getDevices();
      _devices = fetched
          .map((d) => _EditableDevice(model: d, isActive: d.isActive))
          .toList();
    } catch (_) {
      // Keep stale data if available
    }
    _isLoading = false;
    notifyListeners();
  }
}

class _EditableDevice {
  final DeviceModel model;
  final bool        isActive;
  // Mutable edit fields
  String editName;
  String editLocation;
  String editSnmpCommunity;
  bool   editSnmpEnabled;

  _EditableDevice({required this.model, required this.isActive})
      : editName          = model.name,
        editLocation      = model.location ?? '',
        editSnmpCommunity = model.snmpCommunity,
        editSnmpEnabled   = model.snmpEnabled;

  _EditableDevice copyWith({
    String? name,
    String? location,
    String? snmpCommunity,
    bool?   snmpEnabled,
    bool?   isActive,
  }) {
    final updated = _EditableDevice(
      model: DeviceModel(
        id:            model.id,
        name:          name ?? editName,
        ipAddress:     model.ipAddress,
        macAddress:    model.macAddress,
        deviceType:    model.deviceType,
        status:        model.status,
        location:      location ?? editLocation,
        description:   model.description,
        snmpEnabled:   snmpEnabled ?? editSnmpEnabled,
        snmpCommunity: snmpCommunity ?? editSnmpCommunity,
        isActive:      isActive ?? this.isActive,
        lastSeen:      model.lastSeen,
        createdAt:     model.createdAt,
      ),
      isActive: isActive ?? this.isActive,
    );
    return updated;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DeviceManagementScreen
// ─────────────────────────────────────────────────────────────────────────────

class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DeviceManagementProvider>().load();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceManagementProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Device Management'),
            actions: [
              IconButton(
                icon:    const Icon(Icons.add),
                tooltip: 'Add Device',
                onPressed: () => _showAddDialog(context, provider),
              ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // ── Search bar ───────────────────────────────────────
                    _buildSearchBar(provider),

                    // ── Count badge ──────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: Row(
                        children: [
                          Text(
                            '${provider.filtered.length} device${provider.filtered.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              fontSize: 12, color: AppColors.textHint),
                          ),
                        ],
                      ),
                    ),

                    // ── Device list ──────────────────────────────────────
                    Expanded(
                      child: provider.filtered.isEmpty
                          ? const Center(
                              child: Text('No devices match your search.',
                                  style: TextStyle(color: AppColors.textHint)))
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                              itemCount: provider.filtered.length,
                              itemBuilder: (context, i) {
                                final device = provider.filtered[i];
                                return _DeviceCard(
                                  device:      device,
                                  onEdit:      () => _showEditSheet(context, provider, device),
                                  onDeactivate: () => _confirmDeactivate(context, provider, device),
                                  onReactivate: () {
                                    provider.reactivate(device.model.id);
                                    AppUtils.showSnackbar(context, '${device.model.name} reactivated.');
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildSearchBar(DeviceManagementProvider provider) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller:  _searchCtrl,
        onChanged:   provider.setSearch,
        decoration:  InputDecoration(
          hintText:        'Search by name, IP, location...',
          prefixIcon: const Icon(Icons.search, color: AppColors.textHint),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon:      const Icon(Icons.clear, color: AppColors.textHint),
                  onPressed: () {
                    _searchCtrl.clear();
                    provider.setSearch('');
                  },
                )
              : null,
          filled:      true,
          fillColor:   AppColors.surface,
          border:      OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:   BorderSide.none,
          ),
        ),
      ),
    );
  }

  // ── Edit bottom sheet ──────────────────────────────────────────────────────

  void _showEditSheet(BuildContext context, DeviceManagementProvider provider, _EditableDevice device) {
    final nameCtrl      = TextEditingController(text: device.editName);
    final locationCtrl  = TextEditingController(text: device.editLocation);
    final snmpCtrl      = TextEditingController(text: device.editSnmpCommunity);
    bool  snmpEnabled   = device.editSnmpEnabled;

    showModalBottomSheet<void>(
      context:            context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('Edit ${device.model.name}', style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                      ),
                      IconButton(
                        icon:      const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _EditField(label: 'Device Name',       controller: nameCtrl),
                  const SizedBox(height: 12),
                  _EditField(label: 'Location',          controller: locationCtrl),
                  const SizedBox(height: 12),
                  _EditField(label: 'SNMP Community',    controller: snmpCtrl),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Expanded(child: Text('SNMP Enabled',
                        style: TextStyle(fontSize: 14, color: AppColors.textPrimary))),
                      Switch(
                        value:     snmpEnabled,
                        onChanged: (v) => setModalState(() => snmpEnabled = v),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final updated = device.copyWith(
                          name:          nameCtrl.text.trim(),
                          location:      locationCtrl.text.trim(),
                          snmpCommunity: snmpCtrl.text.trim(),
                          snmpEnabled:   snmpEnabled,
                        );
                        provider.saveEdit(updated);
                        Navigator.pop(sheetContext);
                        AppUtils.showSnackbar(context, 'Device updated successfully.');
                      },
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameCtrl.dispose();
      locationCtrl.dispose();
      snmpCtrl.dispose();
    });
  }

  // ── Add device dialog ──────────────────────────────────────────────────────

  void _showAddDialog(BuildContext context, DeviceManagementProvider provider) {
    AppUtils.showSnackbar(context, 'Add Device connects to POST /api/devices/ — coming soon.');
  }

  // ── Deactivate confirm dialog ──────────────────────────────────────────────

  void _confirmDeactivate(BuildContext context, DeviceManagementProvider provider, _EditableDevice device) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title:   const Text('Deactivate Device?'),
        content: Text(
          '${device.model.name} will be removed from active monitoring. '
          'Its history will be retained and it can be reactivated at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child:     const Text('Cancel'),
          ),
          ElevatedButton(
            style:     ElevatedButton.styleFrom(backgroundColor: AppColors.severityCritical),
            onPressed: () {
              provider.deactivate(device.model.id);
              Navigator.pop(dialogContext);
              AppUtils.showSnackbar(context, '${device.model.name} deactivated.', isError: true);
            },
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DeviceCard
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceCard extends StatelessWidget {
  final _EditableDevice device;
  final VoidCallback    onEdit;
  final VoidCallback    onDeactivate;
  final VoidCallback    onReactivate;
  const _DeviceCard({
    required this.device,
    required this.onEdit,
    required this.onDeactivate,
    required this.onReactivate,
  });

  @override
  Widget build(BuildContext context) {
    final d          = device.model;
    final statusColor = AppUtils.statusColor(d.status);
    final inactive   = !device.isActive;

    return Opacity(
      opacity: inactive ? 0.55 : 1.0,
      child: Container(
        margin:  const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: inactive
              ? Border.all(color: AppColors.divider, width: 1.5)
              : null,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ─────────────────────────────────────────────
            Row(
              children: [
                Container(
                  padding:    const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:        AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(AppUtils.deviceTypeIcon(d.deviceType),
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(device.editName, style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                          if (inactive)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.divider, borderRadius: BorderRadius.circular(20)),
                              child: const Text('Inactive', style: TextStyle(
                                fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.textHint)),
                            ),
                        ],
                      ),
                      Text(d.ipAddress, style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                // Status dot
                Container(
                  width: 10, height: 10,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // ── Info chips ─────────────────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                _InfoChip(icon: Icons.place_outlined,
                    label: device.editLocation.isNotEmpty ? device.editLocation : 'No location'),
                _InfoChip(icon: Icons.settings_ethernet,
                    label: device.editSnmpEnabled ? 'SNMP: ${device.editSnmpCommunity}' : 'SNMP off'),
                _InfoChip(icon: Icons.access_time_outlined,
                    label: 'Seen ${AppUtils.timeAgo(d.lastSeen)}'),
              ],
            ),
            const SizedBox(height: 10),

            // ── Action row ─────────────────────────────────────────────
            Row(
              children: [
                OutlinedButton.icon(
                  icon:      const Icon(Icons.edit_outlined, size: 15),
                  label:     const Text('Edit', style: TextStyle(fontSize: 12)),
                  onPressed: inactive ? null : onEdit,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    side:    const BorderSide(color: AppColors.primary),
                  ),
                ),
                const SizedBox(width: 8),
                if (inactive)
                  OutlinedButton.icon(
                    icon:      const Icon(Icons.play_circle_outline, size: 15),
                    label:     const Text('Reactivate', style: TextStyle(fontSize: 12)),
                    onPressed: onReactivate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      foregroundColor: AppColors.online,
                      side: const BorderSide(color: AppColors.online),
                    ),
                  )
                else
                  OutlinedButton.icon(
                    icon:      const Icon(Icons.remove_circle_outline, size: 15),
                    label:     const Text('Deactivate', style: TextStyle(fontSize: 12)),
                    onPressed: onDeactivate,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      foregroundColor: AppColors.severityCritical,
                      side: const BorderSide(color: AppColors.severityCritical),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color:        AppColors.background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.textHint),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String             label;
  final TextEditingController controller;
  const _EditField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText:   label,
        filled:      true,
        fillColor:   AppColors.background,
        border:      OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:   const BorderSide(color: AppColors.primary),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }
}
