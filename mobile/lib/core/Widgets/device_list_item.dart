import 'package:flutter/material.dart';
import 'package:smart_isp_monitor/core/Widgets/status_budge.dart';
import '../../data/models/device_model.dart';
import '../../data/models/metric_model.dart';
import '../theme.dart';
import '../utils.dart';

/// DeviceListItem displays a single device as a card in a list.
/// It shows the device name, IP address, location, type icon,
/// status badge, and the latest latency reading.
///
/// The onTap callback is a function passed in from the parent screen.
/// When the user taps this card the parent screen decides what to do —
/// usually navigating to the Device Detail screen.
/// This is called a "callback" pattern and it keeps this widget
/// independent of any specific navigation logic.
class DeviceListItem extends StatelessWidget {
  final DeviceModel  device;
  final MetricModel? metric;   // null if no metrics recorded yet
  final VoidCallback? onTap;  // VoidCallback is a function that takes no arguments

  const DeviceListItem({
    super.key,
    required this.device,
    this.metric,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      // margin is defined in the CardTheme in theme.dart
      // but we can override it here if needed
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: InkWell(
        // InkWell adds the ripple tap effect on the card.
        // Without InkWell the card would look tappable but give
        // no visual feedback when pressed.
        onTap:        onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [

              // ── Device Type Icon ────────────────────────────────────
              // A circular container with a coloured icon representing
              // the device type (router, switch, OLT etc.)
              Container(
                width:   46,
                height:  46,
                decoration: BoxDecoration(
                  color:  AppColors.primarySurface,
                  shape:  BoxShape.circle,
                ),
                child: Icon(
                  // AppUtils.deviceTypeIcon returns the correct icon
                  // for the device type string
                  AppUtils.deviceTypeIcon(device.deviceType),
                  color: AppColors.primary,
                  size:  22,
                ),
              ),

              const SizedBox(width: 14),

              // ── Device Info ─────────────────────────────────────────
              // Expanded makes this column take all the remaining
              // horizontal space between the icon and the right side.
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Device name — bold and prominent
                    Text(
                      device.name,
                      style: const TextStyle(
                        fontSize:   15,
                        fontWeight: FontWeight.w600,
                        color:      AppColors.textPrimary,
                      ),
                      // If name is too long cut it off with ...
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 3),

                    // IP address and location on the same row
                    Row(
                      children: [
                        Text(
                          device.ipAddress,
                          style: const TextStyle(
                            fontSize: 12,
                            color:    AppColors.textSecondary,
                            fontFamily: 'monospace',
                          ),
                        ),
                        // Only show the location separator if a location exists
                        if (device.location != null) ...[
                          const Text(
                            '  ·  ',
                            style: TextStyle(color: AppColors.textHint),
                          ),
                          Expanded(
                            child: Text(
                              device.location!,
                              style: const TextStyle(
                                fontSize: 12,
                                color:    AppColors.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Status badge and latency on the same row
                    Row(
                      children: [
                        // StatusBadge widget we built yesterday
                        StatusBadge(status: device.status, small: true),

                        const SizedBox(width: 10),

                        // Latency reading — only show if we have metric data
                        // and the device is not offline
                        if (metric != null && metric!.latencyMs != null)
                          Row(
                            children: [
                              const Icon(
                                Icons.timer_outlined,
                                size:  13,
                                color: AppColors.textHint,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${metric!.latencyMs!.toStringAsFixed(1)} ms',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color:    AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Arrow Icon ──────────────────────────────────────────
              // A subtle right arrow indicating this item is tappable
              const Icon(
                Icons.chevron_right,
                color: AppColors.textHint,
                size:  22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}