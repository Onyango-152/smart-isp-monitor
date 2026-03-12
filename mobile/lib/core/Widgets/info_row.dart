import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';
import '../utils.dart';

/// InfoRow displays a single label–value pair in a horizontal row.
///
/// Used on detail screens to show device properties:
/// IP address, MAC address, location, SNMP settings, uptime, etc.
///
/// Features:
///   - Optional leading icon
///   - Monospace value rendering for IP/MAC addresses (`isMono: true`)
///   - Copy-to-clipboard on long-press when `copyable: true`
///   - Trailing widget slot for badges, chips, or switches
///   - Bottom divider hidden on last row via `isLast: true`
///
/// Usage:
/// ```dart
/// InfoRow(
///   label: 'IP Address',
///   value: device.ipAddress,
///   icon:  Icons.lan_rounded,
///   isMono: true,
///   copyable: true,
/// )
///
/// InfoRow(
///   label:   'Status',
///   value:   '',           // ignored when trailing is set
///   trailing: StatusBadge(status: device.status),
/// )
///
/// InfoRow(
///   label:  'SNMP Enabled',
///   value:  '',
///   trailing: Switch(value: device.snmpEnabled, onChanged: null),
///   isLast: true,
/// )
/// ```
///
/// Used by:
///   device_detail_screen.dart, device_management_screen.dart,
///   settings_screen.dart
class InfoRow extends StatelessWidget {
  final String    label;
  final String    value;
  final IconData? icon;
  final Color?    valueColor;
  final bool      isLast;
  final bool      isMono;      // renders value in monospace (IP, MAC, commands)
  final bool      copyable;    // long-press copies value to clipboard
  final Widget?   trailing;    // replaces value text when set

  const InfoRow({
    super.key,
    required this.label,
    this.value   = '',
    this.icon,
    this.valueColor,
    this.isLast   = false,
    this.isMono   = false,
    this.copyable = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(context),
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  Widget _buildRow(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [

          // ── Leading icon ────────────────────────────────────────────
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppColors.textHint),
            const SizedBox(width: 8),
          ],

          // ── Label ───────────────────────────────────────────────────
          // Uses flexible instead of fixed width so it wraps naturally
          // on small screens rather than overflowing.
          Flexible(
            flex: 4,
            child: Text(
              label,
              style: AppTextStyles.bodySmall,
            ),
          ),

          const SizedBox(width: 12),

          // ── Value or trailing widget ─────────────────────────────────
          Flexible(
            flex: 5,
            child: trailing != null
                ? Align(
                    alignment: Alignment.centerRight,
                    child: trailing,
                  )
                : _buildValue(),
          ),
        ],
      ),
    );

    // Wrap in GestureDetector only when copyable
    if (copyable && value.isNotEmpty) {
      return GestureDetector(
        onLongPress: () => _copyToClipboard(context),
        child: row,
      );
    }

    return row;
  }

  Widget _buildValue() {
    if (value.isEmpty) return const SizedBox.shrink();

    final style = isMono
        ? AppTextStyles.mono.copyWith(
            fontSize:   13,
            color:      valueColor ?? AppColors.textPrimary,
          )
        : AppTextStyles.body.copyWith(
            fontWeight: FontWeight.w500,
            color:      valueColor ?? AppColors.textPrimary,
          );

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize:      MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            value,
            style:     style,
            textAlign: TextAlign.right,
          ),
        ),
        // Copy hint icon — visible only when copyable
        if (copyable) ...[
          const SizedBox(width: 4),
          const Icon(
            Icons.copy_rounded,
            size:  12,
            color: AppColors.textHint,
          ),
        ],
      ],
    );
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: value));
    AppUtils.haptic();
    AppUtils.showSnackbar(context, 'Copied: $value');
  }
}