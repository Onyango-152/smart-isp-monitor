import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/status_badge.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';

/// DeviceListTile renders a single device as a tappable card row.
///
/// Visual features:
///   - Coloured left border matching device status (online/offline/degraded)
///   - Device type icon with status-tinted background
///   - Device name, type label, IP address, and location
///   - StatusBadge pill top-right of the name
///   - Latency chip and packet loss chip (colour-coded)
///   - Pulsing animated dot for offline / degraded devices
///   - Last-seen timestamp
///   - Haptic feedback on tap
///   - Full dark mode support
///
/// Used by:
///   device_list_screen.dart, technician_dashboard.dart
///
/// Constructor:
/// ```dart
/// DeviceListTile(
///   device:       device,
///   latestMetric: provider.getLatestMetric(device.id), // nullable
///   onTap:        () => Navigator.of(context).pushNamed(
///                   AppConstants.deviceDetailRoute,
///                   arguments: device,
///                 ),
/// )
/// ```
class DeviceListTile extends StatefulWidget {
  final DeviceModel  device;
  final MetricModel? latestMetric;
  final VoidCallback onTap;

  const DeviceListTile({
    super.key,
    required this.device,
    required this.latestMetric,
    required this.onTap,
  });

  @override
  State<DeviceListTile> createState() => _DeviceListTileState();
}

class _DeviceListTileState extends State<DeviceListTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  bool get _needsPulse =>
      widget.device.status == AppConstants.statusOffline ||
      widget.device.status == AppConstants.statusDegraded;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 1400),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    if (_needsPulse) _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device      = widget.device;
    final metric      = widget.latestMetric;
    final isDark      = Theme.of(context).brightness == Brightness.dark;
    final statusColor = AppUtils.statusColor(device.status);
    final statusBg    = isDark
        ? AppUtils.statusDarkBgColor(device.status)
        : AppUtils.statusBgColor(device.status);
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            AppUtils.haptic();
            widget.onTap();
          },
          onLongPress: () {
            AppUtils.haptic();
            _showQuickActions(context);
          },
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color:        surfaceColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow:    AppShadows.card,
              border: Border(
                left: BorderSide(color: statusColor, width: 3.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Device type icon ────────────────────────────────
                  Container(
                    width:      46,
                    height:     46,
                    decoration: BoxDecoration(
                      color:        statusBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      AppUtils.deviceTypeIcon(device.deviceType),
                      color: statusColor,
                      size:  24,
                    ),
                  ),

                  const SizedBox(width: 12),

                  // ── Main info column ────────────────────────────────
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        // Name row + status badge
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                device.name,
                                style: AppTextStyles.heading3,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            StatusBadge(
                              status: device.status,
                              size:   BadgeSize.small,
                            ),
                          ],
                        ),

                        const SizedBox(height: 3),

                        // IP · type
                        Text(
                          '${device.ipAddress}  ·  '
                          '${AppUtils.deviceTypeLabel(device.deviceType)}',
                          style: AppTextStyles.caption,
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Location
                        if (device.location != null) ...[
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.location_on_outlined,
                                  size: 11, color: AppColors.textHint),
                              const SizedBox(width: 2),
                              Expanded(
                                child: Text(
                                  device.location!,
                                  style: AppTextStyles.caption,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],

                        // Latency + packet loss row
                        if (metric?.latencyMs != null) ...[
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              _MetricChip(
                                label: AppUtils.formatLatency(metric!.latencyMs),
                                color: AppUtils.latencyColor(metric.latencyMs!),
                                bg:    AppUtils.latencyBgColor(metric.latencyMs!),
                              ),
                              if ((metric.packetLossPct ?? 0) > 0) ...[
                                const SizedBox(width: 5),
                                _MetricChip(
                                  label:
                                      '${metric.packetLossPct!.toStringAsFixed(1)}% loss',
                                  color: AppColors.offline,
                                  bg:    AppColors.offlineLight,
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(width: 10),

                  // ── Right column: pulse dot + last seen + chevron ───
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _StatusDot(
                        statusColor: statusColor,
                        pulseAnim:   _pulseAnim,
                        shouldPulse: _needsPulse,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        device.lastSeen != null
                            ? AppUtils.timeAgo(device.lastSeen)
                            : 'Never',
                        style: AppTextStyles.caption,
                      ),
                      const SizedBox(height: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        size:  18,
                        color: AppColors.textHint,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    final device = widget.device;
    final statusColor = AppUtils.statusColor(device.status);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Device header
              Row(
                children: [
                  Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      AppUtils.deviceTypeIcon(device.deviceType),
                      color: statusColor, size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(device.name, style: AppTextStyles.heading3),
                        Text(device.ipAddress, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              // Actions
              _QuickActionTile(
                icon: Icons.network_ping_rounded,
                color: AppColors.primary,
                label: 'Ping',
                subtitle: 'Quick ICMP ping test',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamed(
                    AppConstants.diagnosticRoute,
                    arguments: device,
                  );
                },
              ),
              _QuickActionTile(
                icon: Icons.troubleshoot_rounded,
                color: AppColors.degraded,
                label: 'Run Diagnostic',
                subtitle: 'Full device health check',
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).pushNamed(
                    AppConstants.diagnosticRoute,
                    arguments: device,
                  );
                },
              ),
              _QuickActionTile(
                icon: Icons.visibility_rounded,
                color: AppColors.online,
                label: 'Acknowledge All Alerts',
                subtitle: 'Mark all alerts for this device as seen',
                onTap: () {
                  Navigator.pop(ctx);
                  AppUtils.showSnackbar(
                    context, 'All alerts for ${device.name} acknowledged');
                },
              ),
              _QuickActionTile(
                icon: Icons.copy_rounded,
                color: AppColors.textSecondary,
                label: 'Copy IP Address',
                subtitle: device.ipAddress,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: device.ipAddress));
                  Navigator.pop(ctx);
                  AppUtils.showSnackbar(context, 'IP copied to clipboard');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _QuickActionTile — row item in the device long-press bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  final IconData     icon;
  final Color        color;
  final String       label;
  final String       subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title:    Text(label, style: AppTextStyles.body),
      subtitle: Text(subtitle, style: AppTextStyles.caption),
      trailing: const Icon(Icons.chevron_right_rounded,
          size: 18, color: AppColors.textHint),
      onTap: onTap,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MetricChip
// ─────────────────────────────────────────────────────────────────────────────

class _MetricChip extends StatelessWidget {
  final String label;
  final Color  color;
  final Color  bg;

  const _MetricChip({
    required this.label,
    required this.color,
    required this.bg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize:   10,
          fontWeight: FontWeight.w700,
          color:      color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _StatusDot
// ─────────────────────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  final Color             statusColor;
  final Animation<double> pulseAnim;
  final bool              shouldPulse;

  const _StatusDot({
    required this.statusColor,
    required this.pulseAnim,
    required this.shouldPulse,
  });

  @override
  Widget build(BuildContext context) {
    if (!shouldPulse) {
      return Container(
        width:      10,
        height:     10,
        decoration: BoxDecoration(
          color:     statusColor,
          shape:     BoxShape.circle,
          boxShadow: AppShadows.statusGlow(statusColor),
        ),
      );
    }

    return AnimatedBuilder(
      animation: pulseAnim,
      builder:   (context, _) => Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow ring
          Container(
            width:      10 * pulseAnim.value,
            height:     10 * pulseAnim.value,
            decoration: BoxDecoration(
              color:  statusColor.withOpacity(
                  0.25 * (2.0 - pulseAnim.value.clamp(1.0, 2.0))),
              shape:  BoxShape.circle,
            ),
          ),
          // Inner solid dot
          Container(
            width:      10,
            height:     10,
            decoration: BoxDecoration(
              color:     statusColor,
              shape:     BoxShape.circle,
              boxShadow: AppShadows.statusGlow(statusColor),
            ),
          ),
        ],
      ),
    );
  }
}