import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/device_model.dart';
import '../../data/models/user_model.dart';
import 'clients_provider.dart';

/// ClientDetailScreen shows full profile, subscription plan, and
/// assigned devices for a single customer account.
///
/// Pushed on top of the ClientsScreen via MaterialPageRoute.
class ClientDetailScreen extends StatelessWidget {
  final UserModel client;

  const ClientDetailScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ClientsProvider>();
    final plan     = provider.getPlan(client.id);
    final devices  = provider.getDevices(client.id);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(child: _buildProfileCard(plan)),
          SliverToBoxAdapter(child: _buildStatsRow(devices)),
          SliverToBoxAdapter(
            child: SectionHeader(
              title:    'Account Details',
              subtitle: 'Subscription & activity',
              icon:     Icons.account_circle_rounded,
            ),
          ),
          SliverToBoxAdapter(child: _buildAccountInfo(plan)),
          SliverToBoxAdapter(
            child: SectionHeader(
              title:    'Assigned Devices',
              subtitle: '${devices.length} device${devices.length != 1 ? "s" : ""}',
              icon:     Icons.router_rounded,
            ),
          ),
          devices.isEmpty
              ? SliverToBoxAdapter(child: _buildNoDevices())
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _buildDeviceTile(context, devices[index]),
                    childCount: devices.length,
                  ),
                ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  // ── Sliver App Bar ────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context) {
    final isActive = client.isActive;

    return SliverAppBar(
      expandedHeight: 180,
      pinned:    true,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          onSelected: (value) {
            if (value == 'edit') {
              _openEdit(context);
            } else if (value == 'delete') {
              _showDeleteDialog(context);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit',   child: Text('Edit')),
            PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
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
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 48, 20, 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Avatar
                  Container(
                    width: 64, height: 64,
                    decoration: BoxDecoration(
                      color:        Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        _getInitials(client.username),
                        style: const TextStyle(
                          color:      Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize:   24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.username,
                          style: const TextStyle(
                            color:      Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize:   20,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          client.email,
                          style: const TextStyle(
                            color:    Colors.white70,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? Colors.green.withOpacity(0.25)
                                : Colors.red.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isActive ? 'Active' : 'Inactive',
                            style: TextStyle(
                              color:      isActive
                                  ? Colors.greenAccent
                                  : Colors.redAccent,
                              fontSize:   11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        title: Text(
          client.username,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
        titlePadding: const EdgeInsets.only(left: 50, bottom: 14),
      ),
    );
  }

  // ── Profile Card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard(String plan) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow:    AppShadows.card,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                children: [
                  _InfoPill(
                    icon:  Icons.card_membership_rounded,
                    label: 'Plan',
                    value: plan,
                    color: _planColor(plan),
                  ),
                ],
              ),
            ),
            Container(
              width: 1, height: 40,
              color: AppColors.divider,
            ),
            Expanded(
              child: Column(
                children: [
                  _InfoPill(
                    icon:  Icons.schedule_rounded,
                    label: 'Last Seen',
                    value: AppUtils.timeAgo(client.lastLogin),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats Row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(List<DeviceModel> devices) {
    final online   = devices.where((d) => d.status == 'online').length;
    final offline  = devices.where((d) => d.status == 'offline').length;
    final degraded = devices.where((d) => d.status == 'degraded').length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Row(
        children: [
          _StatCard(
            label: 'Total',
            value: '${devices.length}',
            icon:  Icons.router_rounded,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Online',
            value: '$online',
            icon:  Icons.check_circle_rounded,
            color: AppColors.online,
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Offline',
            value: '$offline',
            icon:  Icons.cancel_rounded,
            color: AppColors.offline,
          ),
          const SizedBox(width: 8),
          _StatCard(
            label: 'Degraded',
            value: '$degraded',
            icon:  Icons.warning_rounded,
            color: AppColors.degraded,
          ),
        ],
      ),
    );
  }

  // ── Account Info ──────────────────────────────────────────────────────────

  Widget _buildAccountInfo(String plan) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow:    AppShadows.card,
        ),
        child: Column(
          children: [
            InfoRow(
              label: 'Email',
              value: client.email,
              icon:  Icons.email_rounded,
              isMono: false,
              copyable: true,
            ),
            InfoRow(
              label: 'Subscription',
              value: plan,
              icon:  Icons.card_membership_rounded,
              valueColor: _planColor(plan),
            ),
            InfoRow(
              label: 'Status',
              value: client.isActive ? 'Active' : 'Inactive',
              icon:  Icons.circle,
              valueColor: client.isActive ? AppColors.online : AppColors.offline,
            ),
            InfoRow(
              label: 'Joined',
              value: AppUtils.formatDateTime(client.dateJoined),
              icon:  Icons.calendar_today_rounded,
            ),
            InfoRow(
              label:  'Last Login',
              value:  AppUtils.formatDateTime(client.lastLogin),
              icon:   Icons.login_rounded,
              isLast: true,
            ),
          ],
        ),
      ),
    );
  }

  // ── No Devices ────────────────────────────────────────────────────────────

  Widget _buildNoDevices() {
    return const Padding(
      padding: EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.router_outlined, size: 48, color: AppColors.textHint),
            SizedBox(height: 8),
            Text('No devices assigned',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  // ── Device Tile ───────────────────────────────────────────────────────────

  Widget _buildDeviceTile(BuildContext context, DeviceModel device) {
    final statusColor = AppUtils.statusColor(device.status);
    final statusBg    = AppUtils.statusBgColor(device.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color:        AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).pushNamed(
            AppConstants.deviceDetailRoute,
            arguments: device,
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider, width: 0.5),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                // Status dot
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color:        statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    AppUtils.deviceTypeIcon(device.deviceType),
                    size:  20,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(device.name, style: AppTextStyles.heading3),
                      const SizedBox(height: 2),
                      Text(
                        '${device.ipAddress}  •  ${AppUtils.deviceTypeLabel(device.deviceType)}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color:        statusBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    device.status[0].toUpperCase() +
                        device.status.substring(1),
                    style: TextStyle(
                      color:      statusColor,
                      fontSize:   10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    size: 18, color: AppColors.textHint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  // ── Edit / Delete helpers ──────────────────────────────────────────────────

  void _openEdit(BuildContext context) async {
    final updated = await Navigator.of(context)
        .pushNamed(AppConstants.clientFormRoute, arguments: client);
    if (updated == true && context.mounted) {
      AppUtils.showSnackbar(context, 'Client updated');
    }
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Delete Client'),
        content: Text('Delete "${client.username}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop(); // close dialog
              final provider = context.read<ClientsProvider>();
              final ok = await provider.deleteClient(client.id);
              if (context.mounted) {
                Navigator.of(context).pop(); // pop detail screen
                if (ok) {
                  AppUtils.showSnackbar(context, 'Client deleted');
                } else {
                  AppUtils.showSnackbar(context, 'Delete failed',
                      isError: true);
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.offline)),
          ),
        ],
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _planColor(String plan) {
    switch (plan) {
      case 'Business Pro':        return AppColors.primary;
      case 'Business Enterprise': return AppColors.maintenance;
      case 'Home Premium':        return AppColors.degraded;
      case 'Home Basic':          return AppColors.online;
      default:                    return AppColors.unknown;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InfoPill — compact icon + label + value
// ─────────────────────────────────────────────────────────────────────────────

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final Color    color;

  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption),
        const SizedBox(height: 2),
        Text(
          value,
          style: AppTextStyles.labelBold.copyWith(color: color),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatCard — small KPI card for the stats row
// ─────────────────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color:        AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          boxShadow:    AppShadows.small,
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTextStyles.heading2.copyWith(color: color),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}
