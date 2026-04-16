import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/info_row.dart';
import '../../core/widgets/section_header.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/device_model.dart';
import '../alerts/alerts_provider.dart';
import '../devices/device_provider.dart';

class AlertDetailScreen extends StatelessWidget {
  const AlertDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alert = ModalRoute.of(context)?.settings.arguments;

    if (alert == null || alert is! AlertModel) {
      return Scaffold(
        appBar: AppBar(title: const Text('Alert Detail')),
        body: const Center(child: Text('No alert data provided.')),
      );
    }

    // Find the device this alert belongs to (if DeviceProvider is available)
    DeviceProvider? deviceProvider;
    try {
      deviceProvider = Provider.of<DeviceProvider>(
        context,
        listen: false,
      );
    } catch (_) {
      deviceProvider = null;
    }
    final device = deviceProvider
        ?.devices
        .cast<DeviceModel?>()
        .firstWhere(
          (d) => d?.id == alert.deviceId,
          orElse: () => null,
        );

    final severityColor = AppUtils.severityColor(alert.severity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Alert Detail'),
        actions: [
          // Only show action menu if alert is not yet resolved
          if (!alert.isResolved)
            Consumer<AlertsProvider>(
              builder: (context, provider, _) {
                // Get the most up-to-date version of this alert
                final current = [
                  ...provider.activeAlerts,
                  ...provider.resolvedAlerts,
                ].cast<AlertModel?>().firstWhere(
                      (a) => a?.id == alert.id,
                      orElse: () => null,
                    ) ?? alert;

                return PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'acknowledge') {
                      provider.acknowledgeAlert(alert.id);
                      AppUtils.showSnackbar(
                          context, 'Alert acknowledged.');
                    } else if (value == 'resolve') {
                      provider.resolveAlert(alert.id);
                      AppUtils.showSnackbar(
                          context, 'Alert marked as resolved.');
                      Navigator.of(context).pop();
                    }
                  },
                  itemBuilder: (_) => [
                    if (!current.isAcknowledged)
                      const PopupMenuItem(
                        value: 'acknowledge',
                        child: Row(children: [
                          Icon(Icons.visibility_outlined,
                              size: 18, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Acknowledge'),
                        ]),
                      ),
                    if (!current.isResolved)
                      const PopupMenuItem(
                        value: 'resolve',
                        child: Row(children: [
                          Icon(Icons.check_circle_outline,
                              size: 18, color: AppColors.online),
                          SizedBox(width: 8),
                          Text('Mark Resolved'),
                        ]),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Severity Banner ──────────────────────────────────────────
            Container(
              width:   double.infinity,
              padding: const EdgeInsets.all(16),
              color:   severityColor.withOpacity(0.1),
              child: Row(
                children: [
                  // Severity icon
                  Container(
                    padding:    const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:        severityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _alertIcon(alert.alertType),
                      color: severityColor,
                      size:  28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Alert type label
                        Text(
                          alert.alertType
                              .replaceAll('_', ' ')
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize:      12,
                            fontWeight:    FontWeight.bold,
                            color:         severityColor,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Alert message
                        Text(
                          alert.message,
                          style: TextStyle(
                            fontSize:   15,
                            fontWeight: FontWeight.w600,
                            color:      AppColors.textPrimaryOf(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Status Pills ─────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Consumer<AlertsProvider>(
                builder: (context, provider, _) {
                  final current = [
                    ...provider.activeAlerts,
                    ...provider.resolvedAlerts,
                  ].cast<AlertModel?>().firstWhere(
                        (a) => a?.id == alert.id,
                        orElse: () => null,
                      ) ?? alert;

                  return Wrap(
                    spacing: 8,
                    children: [
                      _StatusPill(
                        label: current.severity.toUpperCase(),
                        color: severityColor,
                      ),
                      _StatusPill(
                        label: current.isResolved
                            ? 'RESOLVED'
                            : 'ACTIVE',
                        color: current.isResolved
                            ? AppColors.online
                            : AppColors.offline,
                      ),
                      if (current.isAcknowledged && !current.isResolved)
                        _StatusPill(
                          label: 'ACKNOWLEDGED',
                          color: AppColors.primary,
                        ),
                    ],
                  );
                },
              ),
            ),

            // ── Alert Information ────────────────────────────────────────
            const SectionHeader(title: 'Alert Information'),
            Container(
              margin:     const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color:        Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color:      Colors.black.withOpacity(0.04),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: Column(
                children: [
                  InfoRow(
                    label: 'Device',
                    value: alert.deviceName,
                    icon:  Icons.router,
                  ),
                  InfoRow(
                    label: 'Alert Type',
                    value: alert.alertType.replaceAll('_', ' '),
                    icon:  Icons.category_outlined,
                  ),
                  InfoRow(
                    label: 'Severity',
                    value: alert.severity.toUpperCase(),
                    icon:  Icons.warning_amber_outlined,
                    valueColor: severityColor,
                  ),
                  InfoRow(
                    label: 'Triggered',
                    value: AppUtils.formatDateTime(alert.triggeredAt),
                    icon:  Icons.access_time,
                  ),
                  if (alert.resolvedAt != null)
                    InfoRow(
                      label: 'Resolved',
                      value: AppUtils.formatDateTime(alert.resolvedAt),
                      icon:  Icons.check_circle_outline,
                      valueColor: AppColors.online,
                    ),
                  InfoRow(
                    label:  'Acknowledged',
                    value:  alert.isAcknowledged ? 'Yes' : 'No',
                    icon:   Icons.visibility_outlined,
                    isLast: alert.details == null,
                  ),
                ],
              ),
            ),

            // ── Recommended Actions ─────────────────────────────────────
            const SectionHeader(title: 'Recommended Actions'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ActionList(actions: _recommendedActions(alert.alertType)),
            ),

            // ── Raw Metric Details ────────────────────────────────────────
            if (alert.details != null &&
                alert.details!.isNotEmpty) ...[
              const SectionHeader(title: 'Metric Details'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding:    const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:      Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: alert.details!.entries.map((entry) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            // Key
                            Expanded(
                              flex: 2,
                              child: Text(
                                entry.key.replaceAll('_', ' '),
                                style: TextStyle(
                                  fontSize: 13,
                                  color:    AppColors.textSecondaryOf(context),
                                ),
                              ),
                            ),
                            // Value
                            Expanded(
                              flex: 3,
                              child: Text(
                                entry.value.toString(),
                                style: TextStyle(
                                  fontSize:   13,
                                  fontWeight: FontWeight.w600,
                                  color:      AppColors.textPrimaryOf(context),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            // ── Device Info ───────────────────────────────────────────────
            if (device != null) ...[
              const SectionHeader(title: 'Affected Device'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding:    const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color:        Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:      Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding:    const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color:        AppColors.primarySurfaceOf(context),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          AppUtils.deviceTypeIcon(device.deviceType),
                          color: AppColors.primary,
                          size:  22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize:   15,
                              ),
                            ),
                            Text(
                              '${device.ipAddress}  ·  '
                              '${AppUtils.deviceTypeLabel(device.deviceType)}',
                              style: TextStyle(
                                fontSize: 13,
                                color:    AppColors.textSecondaryOf(context),
                              ),
                            ),
                            if (device.location != null)
                              Text(
                                device.location!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color:    AppColors.textHintOf(context),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Navigate to device detail
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios,
                            size: 16, color: AppColors.primary),
                        onPressed: () => Navigator.of(context).pushNamed(
                          AppConstants.deviceDetailRoute,
                          arguments: device,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).pushNamed(
                      AppConstants.deviceDetailRoute,
                      arguments: device,
                    ),
                    icon: const Icon(Icons.router_rounded, size: 18),
                    label: const Text('View Device'),
                    style: OutlinedButton.styleFrom(
                      minimumSize:     const Size(0, 46),
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ),
            ],

            // ── Action Buttons ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
              child: Consumer<AlertsProvider>(
                builder: (context, provider, _) {
                  final current = [
                    ...provider.activeAlerts,
                    ...provider.resolvedAlerts,
                  ].cast<AlertModel?>().firstWhere(
                        (a) => a?.id == alert.id,
                        orElse: () => null,
                      ) ?? alert;

                  if (current.isResolved) {
                    return Container(
                      padding:    const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color:        AppColors.onlineLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.check_circle,
                              color: AppColors.online, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'This alert has been resolved.',
                            style: TextStyle(
                              color:      AppColors.online,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final canTroubleshoot = device != null;
                  return Column(
                    children: [
                      // Troubleshoot button — most prominent
                      ElevatedButton.icon(
                        onPressed: canTroubleshoot
                            ? () => Navigator.of(context).pushNamed(
                                  AppConstants.troubleshootRoute,
                                  arguments: {
                                    'device':    device,
                                    'alertType': alert.alertType,
                                    'checkName': alert.alertType,
                                    'value':     alert.details?['latency_ms'] ??
                                        alert.details?['packet_loss_pct'] ??
                                        alert.details?['cpu_usage_pct'],
                                    'threshold': alert.details?['threshold'],
                                  },
                                )
                            : () => AppUtils.showSnackbar(
                                  context,
                                  'Device details are unavailable for this alert.',
                                ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 52),
                        ),
                        icon:  const Icon(Icons.build_outlined),
                        label: const Text('Start Troubleshooting'),
                      ),
                      const SizedBox(height: 10),

                      Row(
                        children: [
                          // Acknowledge
                          if (!current.isAcknowledged)
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  provider.acknowledgeAlert(alert.id);
                                  AppUtils.showSnackbar(
                                      context, 'Alert acknowledged.');
                                },
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 48),
                                  foregroundColor: AppColors.primary,
                                  side: const BorderSide(
                                      color: AppColors.primary),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                icon:  const Icon(
                                    Icons.visibility_outlined,
                                    size: 18),
                                label: const Text('Acknowledge'),
                              ),
                            ),

                          if (!current.isAcknowledged)
                            const SizedBox(width: 10),

                          // Resolve
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                provider.resolveAlert(alert.id);
                                AppUtils.showSnackbar(
                                    context,
                                    'Alert marked as resolved.');
                                Navigator.of(context).pop();
                              },
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(0, 48),
                                foregroundColor: AppColors.online,
                                side: const BorderSide(
                                    color: AppColors.online),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                              icon:  const Icon(
                                  Icons.check_circle_outline,
                                  size: 18),
                              label: const Text('Resolve'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  IconData _alertIcon(String alertType) {
    switch (alertType) {
      case 'device_offline':   return Icons.wifi_off;
      case 'high_latency':     return Icons.speed;
      case 'packet_loss':      return Icons.signal_wifi_bad;
      case 'high_cpu':         return Icons.memory;
      case 'high_memory':      return Icons.storage;
      case 'interface_error':  return Icons.cable;
      case 'bandwidth_spike':  return Icons.trending_up;
      case 'predictive':       return Icons.analytics;
      default:                 return Icons.warning_amber;
    }
  }

  List<String> _recommendedActions(String alertType) {
    switch (alertType) {
      case 'high_latency':
        return [
          'Check upstream link utilization for congestion.',
          'Verify interface errors and queue drops on the edge port.',
          'Run a focused ping/trace to isolate the slow hop.',
        ];
      case 'packet_loss':
        return [
          'Inspect interface errors and CRC counters.',
          'Check duplex/MTU mismatch on the access port.',
          'Confirm no loops or broadcast storms on the segment.',
        ];
      case 'high_cpu':
        return [
          'Review CPU-heavy processes and routing table size.',
          'Check for control plane storms or excessive polling.',
          'Consider moving non-critical services off the device.',
        ];
      case 'high_memory':
        return [
          'Inspect memory leaks or unusually large tables.',
          'Clear stale sessions if safe to do so.',
          'Schedule a maintenance restart if usage keeps rising.',
        ];
      case 'mac_table_saturation':
        return [
          'Identify the access port with excessive MACs.',
          'Check for unmanaged switches or loops.',
          'Apply port security limits to prevent flooding.',
        ];
      case 'power_load':
        return [
          'Verify UPS load and remaining headroom.',
          'Check for recent power events or battery health.',
          'Reduce load or balance circuits if possible.',
        ];
      default:
        return [
          'Review related device metrics and recent changes.',
          'Acknowledge and monitor if the issue is transient.',
          'Escalate to field team if the alert persists.',
        ];
    }
  }
}

class _ActionList extends StatelessWidget {
  final List<String> actions;
  const _ActionList({required this.actions});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        children: actions.map((text) {
          final isLast = text == actions.last;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check_circle_outline,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    text,
                    style: AppTextStyles.bodySmall,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Small coloured pill showing a status label.
class _StatusPill extends StatelessWidget {
  final String label;
  final Color  color;
  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:        color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize:   11,
          fontWeight: FontWeight.bold,
          color:      color,
        ),
      ),
    );
  }
}