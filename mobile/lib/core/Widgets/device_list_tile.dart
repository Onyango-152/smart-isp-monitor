import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';

/// DeviceListTile renders a single device as a tappable card row.
///
/// Visual features:
///   - Blue accent border
///   - Device name, type label, IP address, and location
///   - Status pill
///   - Latency and packet loss chips
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
class DeviceListTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final device      = this.device;
    final metric      = latestMetric;
    final statusColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final surfaceColor = AppColors.surfaceOf(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Material(
        color:        Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            AppUtils.haptic();
            onTap();
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
                left: BorderSide(
                  color: isDark ? AppColors.primaryLight : AppColors.primary, 
                  width: 3.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                                style: AppTextStyles.heading3.copyWith(
                                  color: AppColors.textPrimaryOf(context),
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.primarySurfaceOf(context),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                device.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 3),

                        // IP · type
                        Text(
                          '${device.ipAddress}  ·  '
                          '${AppUtils.deviceTypeLabel(device.deviceType)}',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),

                        // Location
                        if (device.location != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            device.location!,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondaryOf(context),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],

                        // Latency + packet loss row
                        if (metric?.latencyMs != null) ...[
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              _MetricChip(
                                label: AppUtils.formatLatency(metric!.latencyMs),
                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                                bg:    AppColors.primarySurfaceOf(context),
                              ),
                              if ((metric.packetLossPct ?? 0) > 0) ...[
                                const SizedBox(width: 5),
                                _MetricChip(
                                  label:
                                      '${metric.packetLossPct!.toStringAsFixed(1)}% loss',
                                  color: isDark ? AppColors.primaryLight : AppColors.primary,
                                  bg:    AppColors.primarySurfaceOf(context),
                                ),
                              ],
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Text(
                          device.lastSeen != null
                              ? 'Last seen ${AppUtils.timeAgo(device.lastSeen)}'
                              : 'Last seen Never',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondaryOf(context),
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
      ),
    );
  }

  void _showQuickActions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final device = this.device;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceOf(context),
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
                  color: AppColors.dividerOf(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Device header
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name, 
                          style: AppTextStyles.heading3.copyWith(
                            color: AppColors.textPrimaryOf(context),
                          ),
                        ),
                        Text(
                          device.ipAddress, 
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Divider(height: 24, color: AppColors.dividerOf(context)),
              // Actions
              _QuickActionTile(
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
                label: 'Acknowledge All Alerts',
                subtitle: 'Mark all alerts for this device as seen',
                onTap: () {
                  Navigator.pop(ctx);
                  AppUtils.showSnackbar(
                    context, 'All alerts for ${device.name} acknowledged');
                },
              ),
              _QuickActionTile(
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
  final String       label;
  final String       subtitle;
  final VoidCallback onTap;

  const _QuickActionTile({
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      title:    Text(
        label, 
        style: AppTextStyles.body.copyWith(
          color: AppColors.textPrimaryOf(context),
        ),
      ),
      subtitle: Text(
        subtitle, 
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondaryOf(context),
        ),
      ),
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

