import 'package:flutter/material.dart';
import '../theme.dart';

/// MetricCard displays a single performance metric with an animated value,
/// optional progress bar, and visual alert highlighting.
///
/// Used by:
///   - device_detail_screen.dart  (latency, packet loss, CPU, memory, bandwidth)
///   - diagnostic_screen.dart     (ping result summary)
///
/// Alert states:
///   - AlertState.none     → white card, primary icon colour
///   - AlertState.warning  → amber tint, amber icon (degraded threshold)
///   - AlertState.critical → red tint, red icon + pulsing dot
///
/// Progress bar:
///   Set [progress] to a 0.0–1.0 value to show a thin coloured bar
///   beneath the metric value. Use for CPU %, memory %, packet loss %.
///
/// Animated counter:
///   Set [doubleValue] to drive a 0 → value animation on first render.
///   Leave null to display [value] statically (e.g. for bandwidth strings).
///
/// Usage:
/// ```dart
/// MetricCard(
///   label:       'CPU Usage',
///   value:       '${metric.cpuUsagePct?.toStringAsFixed(0)}',
///   unit:        '%',
///   icon:        Icons.memory_rounded,
///   doubleValue: metric.cpuUsagePct,
///   progress:    (metric.cpuUsagePct ?? 0) / 100,
///   alertState:  metric.cpuUsagePct != null && metric.cpuUsagePct! > 90
///                  ? AlertState.critical
///                  : metric.cpuUsagePct != null && metric.cpuUsagePct! > 75
///                      ? AlertState.warning
///                      : AlertState.none,
/// )
/// ```
enum AlertState { none, warning, critical }

class MetricCard extends StatefulWidget {
  final String     label;
  final String     value;       // displayed as-is when doubleValue is null
  final String?    unit;
  final IconData   icon;
  final double?    doubleValue; // drives the animated counter (0 → value)
  final double?    progress;   // 0.0–1.0 for the progress bar; null = hidden
  final AlertState alertState;
  final Color?     valueColor;  // overrides computed colour if set

  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    this.doubleValue,
    this.progress,
    this.alertState = AlertState.none,
    this.valueColor,
  });

  // ── Convenience constructor — keeps old call sites working ───────────────
  // Old code used `isAlert: true` — this maps that to AlertState.critical.
  factory MetricCard.simple({
    Key?       key,
    required String   label,
    required String   value,
    String?           unit,
    required IconData icon,
    Color?            valueColor,
    bool              isAlert = false,
  }) {
    return MetricCard(
      key:        key,
      label:      label,
      value:      value,
      unit:       unit,
      icon:       icon,
      valueColor: valueColor,
      alertState: isAlert ? AlertState.critical : AlertState.none,
    );
  }

  @override
  State<MetricCard> createState() => _MetricCardState();
}

class _MetricCardState extends State<MetricCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _counterAnim;
  late final Animation<double>   _progressAnim;
  late final Animation<double>   _pulseAnim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync:    this,
      duration: const Duration(milliseconds: 950),
    );

    // Counter: 0 → doubleValue
    _counterAnim = Tween<double>(
      begin: 0,
      end:   widget.doubleValue ?? 0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    // Progress bar fill
    _progressAnim = Tween<double>(
      begin: 0,
      end:   widget.progress ?? 0,
    ).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.2, 1.0, curve: Curves.easeOut)));

    // Pulse for critical alert dot
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        if (widget.alertState == AlertState.critical) {
          // Pulse repeats; counter still plays on first cycle
          _ctrl.forward().then((_) {
            if (mounted) {
              _ctrl.duration = const Duration(milliseconds: 1200);
              _ctrl.repeat(reverse: true);
            }
          });
        } else {
          _ctrl.forward();
        }
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Derived colours from alert state ─────────────────────────────────────

  Color get _cardBg {
    switch (widget.alertState) {
      case AlertState.critical: return AppColors.offlineLight;
      case AlertState.warning:  return AppColors.degradedLight;
      case AlertState.none:     return Colors.white;
    }
  }

  Color get _iconColor {
    switch (widget.alertState) {
      case AlertState.critical: return AppColors.offline;
      case AlertState.warning:  return AppColors.degraded;
      case AlertState.none:     return AppColors.primary;
    }
  }

  Color get _iconBg {
    switch (widget.alertState) {
      case AlertState.critical: return AppColors.offlineLight;
      case AlertState.warning:  return AppColors.degradedLight;
      case AlertState.none:     return AppColors.primarySurface;
    }
  }

  Color get _valueColor {
    if (widget.valueColor != null) return widget.valueColor!;
    switch (widget.alertState) {
      case AlertState.critical: return AppColors.offline;
      case AlertState.warning:  return AppColors.degraded;
      case AlertState.none:     return AppColors.textPrimary;
    }
  }

  Color get _progressColor {
    switch (widget.alertState) {
      case AlertState.critical: return AppColors.offline;
      case AlertState.warning:  return AppColors.degraded;
      case AlertState.none:     return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding:  const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        _cardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow:    widget.alertState == AlertState.none
            ? AppShadows.card
            : AppShadows.statusGlow(_iconColor),
        border: Border.all(
          color: _iconColor.withOpacity(
              widget.alertState == AlertState.none ? 0.08 : 0.25),
          width: widget.alertState == AlertState.none ? 1 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Header: icon + label + alert dot ─────────────────────────
          Row(
            children: [
              Container(
                width:      32,
                height:     32,
                decoration: BoxDecoration(
                  color:        _iconBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconFromWidget, color: _iconColor, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppTextStyles.label,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // Alert dot — pulses for critical
              if (widget.alertState != AlertState.none)
                _buildAlertDot(),
            ],
          ),

          const SizedBox(height: 10),

          // ── Value + unit ──────────────────────────────────────────────
          AnimatedBuilder(
            animation: _counterAnim,
            builder:   (context, _) {
              final display = widget.doubleValue != null
                  ? _formatCounter(_counterAnim.value)
                  : widget.value;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    display,
                    style: AppTextStyles.displayMedium.copyWith(
                      color:    _valueColor,
                      fontSize: 22,
                    ),
                  ),
                  if (widget.unit != null) ...[
                    const SizedBox(width: 3),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        widget.unit!,
                        style: AppTextStyles.label,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),

          // ── Progress bar ──────────────────────────────────────────────
          if (widget.progress != null) ...[
            const SizedBox(height: 10),
            _buildProgressBar(),
          ],
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  IconData get _iconFromWidget => widget.icon;

  /// Formats the counter value to match the original value string format.
  /// If original has decimals, show one decimal; otherwise show integer.
  String _formatCounter(double v) {
    if (widget.value.contains('.')) {
      return v.toStringAsFixed(1);
    }
    return v.toStringAsFixed(0);
  }

  Widget _buildAlertDot() {
    if (widget.alertState == AlertState.warning) {
      // Static amber dot for warning
      return Container(
        width:  8,
        height: 8,
        decoration: const BoxDecoration(
          color: AppColors.degraded,
          shape: BoxShape.circle,
        ),
      );
    }

    // Pulsing red dot for critical
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder:   (context, _) {
        final scale = _ctrl.isAnimating
            ? _pulseAnim.value
            : 1.0;
        return Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width:  8 * scale,
              height: 8 * scale,
              decoration: BoxDecoration(
                color:  AppColors.offline.withOpacity(
                    0.3 * (2.0 - scale.clamp(1.0, 2.0))),
                shape:  BoxShape.circle,
              ),
            ),
            Container(
              width:  8,
              height: 8,
              decoration: BoxDecoration(
                color:     AppColors.offline,
                shape:     BoxShape.circle,
                boxShadow: AppShadows.statusGlow(AppColors.offline),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progressAnim,
      builder:   (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value:            _progressAnim.value.clamp(0.0, 1.0),
                backgroundColor:  _progressColor.withOpacity(0.12),
                valueColor:
                    AlwaysStoppedAnimation<Color>(_progressColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${(_progressAnim.value * 100).toStringAsFixed(0)}%',
              style: AppTextStyles.caption.copyWith(
                color:      _progressColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}