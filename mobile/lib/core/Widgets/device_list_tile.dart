import 'package:flutter/material.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import '../theme.dart';
import '../utils.dart';
import 'status_badge.dart';

/// DeviceListTile renders a single device as a tappable list row.
/// It shows the device name, IP address, type, location, current status,
/// and the latest latency reading if available.
class DeviceListTile extends StatelessWidget {
  final DeviceModel  device;
  final MetricModel? latestMetric; // optional — may not have been polled yet
  final VoidCallback onTap;

  const DeviceListTile({
    super.key,
    required this.device,
    this.latestMetric,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      // Card margin is already set in the theme so we don't add extra here
      child: InkWell(
        onTap:        onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [

              // ── Device Type Icon ───────────────────────────────────────
              Container(
                width:      46,
                height:     46,
                decoration: BoxDecoration(
                  color:        AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  AppUtils.deviceTypeIcon(device.deviceType),
                  color: AppColors.primary,
                  size:  24,
                ),
              ),
              const SizedBox(width: 12),

              // ── Device Info ────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Device name and status badge on the same row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            device.name,
                            style: const TextStyle(
                              fontSize:   15,
                              fontWeight: FontWeight.w600,
                              color:      AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusBadge(status: device.status, small: true),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // IP address and device type
                    Text(
                      '${device.ipAddress}  ·  ${AppUtils.deviceTypeLabel(device.deviceType)}',
                      style: const TextStyle(
                        fontSize: 13,
                        color:    AppColors.textSecondary,
                      ),
                    ),

                    // Location if available
                    if (device.location != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 13, color: AppColors.textHint),
                          const SizedBox(width: 3),
                          Text(
                            device.location!,
                            style: const TextStyle(
                              fontSize: 12,
                              color:    AppColors.textHint,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // Latest latency reading if the device is online
                    if (latestMetric?.latencyMs != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.speed,
                              size: 13, color: AppColors.textHint),
                          const SizedBox(width: 3),
                          Text(
                            '${latestMetric!.latencyMs!.toStringAsFixed(1)} ms',
                            style: TextStyle(
                              fontSize:   12,
                              color:      _latencyColor(latestMetric!.latencyMs!),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (latestMetric?.packetLossPct != null &&
                              latestMetric!.packetLossPct! > 0)
                            Text(
                              '${latestMetric!.packetLossPct!.toStringAsFixed(1)}% loss',
                              style: const TextStyle(
                                fontSize: 12,
                                color:    AppColors.offline,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // ── Chevron ────────────────────────────────────────────────
              const Icon(Icons.chevron_right,
                  color: AppColors.textHint, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// Returns a colour based on the latency value.
  /// Green = good, Orange = acceptable, Red = problematic
  Color _latencyColor(double ms) {
    if (ms < 50)  return AppColors.online;
    if (ms < 150) return AppColors.degraded;
    return AppColors.offline;
  }
}