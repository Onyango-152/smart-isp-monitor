import 'package:flutter/material.dart';
import '../theme.dart';

/// A reusable shimmer-animated skeleton placeholder.
///
/// Use the named constructors for common dashboard / list layouts,
/// or compose manually with rows of [SkeletonBox].
class ShimmerSkeleton extends StatelessWidget {
  final Widget child;
  const ShimmerSkeleton({super.key, required this.child});

  // ── Named constructors for common layouts ─────────────────────────────────

  /// Dashboard: hero strip + summary row + 3 list items.
  static Widget dashboard() {
    return const ShimmerSkeleton(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero strip
            SkeletonBox(width: double.infinity, height: 110, radius: 18),
            SizedBox(height: 14),
            // Summary row — 4 cards
            Row(children: [
              Expanded(child: SkeletonBox(height: 90, radius: 14)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 90, radius: 14)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 90, radius: 14)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 90, radius: 14)),
            ]),
            SizedBox(height: 14),
            // Metric strip — 3 cards
            Row(children: [
              Expanded(child: SkeletonBox(height: 70, radius: 12)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 70, radius: 12)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 70, radius: 12)),
            ]),
            SizedBox(height: 20),
            // Weekly chart placeholder
            SkeletonBox(width: double.infinity, height: 130, radius: 16),
            SizedBox(height: 20),
            // List items
            SkeletonBox(width: 140, height: 14, radius: 4),
            SizedBox(height: 12),
            _SkeletonListItem(),
            SizedBox(height: 8),
            _SkeletonListItem(),
            SizedBox(height: 8),
            _SkeletonListItem(),
          ],
        ),
      ),
    );
  }

  /// Alert list: filter row + 5 alert card skeletons.
  static Widget alertList() {
    return const ShimmerSkeleton(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter chips row
            Row(children: [
              SkeletonBox(width: 50, height: 28, radius: 14),
              SizedBox(width: 8),
              SkeletonBox(width: 70, height: 28, radius: 14),
              SizedBox(width: 8),
              SkeletonBox(width: 55, height: 28, radius: 14),
              SizedBox(width: 8),
              SkeletonBox(width: 65, height: 28, radius: 14),
            ]),
            SizedBox(height: 16),
            _SkeletonAlertCard(),
            SizedBox(height: 10),
            _SkeletonAlertCard(),
            SizedBox(height: 10),
            _SkeletonAlertCard(),
            SizedBox(height: 10),
            _SkeletonAlertCard(),
            SizedBox(height: 10),
            _SkeletonAlertCard(),
          ],
        ),
      ),
    );
  }

  /// Device list: search bar + filter row + 5 device card skeletons.
  static Widget deviceList() {
    return const ShimmerSkeleton(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            SkeletonBox(width: double.infinity, height: 44, radius: 12),
            SizedBox(height: 12),
            // Filter chips
            Row(children: [
              SkeletonBox(width: 60, height: 28, radius: 14),
              SizedBox(width: 8),
              SkeletonBox(width: 55, height: 28, radius: 14),
              SizedBox(width: 8),
              SkeletonBox(width: 70, height: 28, radius: 14),
            ]),
            SizedBox(height: 16),
            _SkeletonListItem(),
            SizedBox(height: 8),
            _SkeletonListItem(),
            SizedBox(height: 8),
            _SkeletonListItem(),
            SizedBox(height: 8),
            _SkeletonListItem(),
            SizedBox(height: 8),
            _SkeletonListItem(),
          ],
        ),
      ),
    );
  }

  /// Device detail: header + metrics grid + chart placeholder.
  static Widget deviceDetail() {
    return const ShimmerSkeleton(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status header card
            SkeletonBox(width: double.infinity, height: 160, radius: 16),
            SizedBox(height: 16),
            // Section title
            SkeletonBox(width: 120, height: 14, radius: 4),
            SizedBox(height: 12),
            // Metrics grid 2×3
            Row(children: [
              Expanded(child: SkeletonBox(height: 95, radius: 12)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 95, radius: 12)),
            ]),
            SizedBox(height: 10),
            Row(children: [
              Expanded(child: SkeletonBox(height: 95, radius: 12)),
              SizedBox(width: 10),
              Expanded(child: SkeletonBox(height: 95, radius: 12)),
            ]),
            SizedBox(height: 16),
            // Chart
            SkeletonBox(width: double.infinity, height: 180, radius: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrapper(child: child);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SkeletonBox — a single rounded rectangle placeholder
// ─────────────────────────────────────────────────────────────────────────────

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double  height;
  final double  radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  width,
      height: height,
      decoration: BoxDecoration(
        color:        AppColors.divider.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Compound skeleton pieces
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonListItem extends StatelessWidget {
  const _SkeletonListItem();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow:    AppShadows.card,
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 42, height: 42, radius: 10),
          SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SkeletonBox(width: 120, height: 12, radius: 4),
              SizedBox(height: 8),
              SkeletonBox(width: 180, height: 10, radius: 4),
            ],
          )),
          SkeletonBox(width: 50, height: 22, radius: 6),
        ],
      ),
    );
  }
}

class _SkeletonAlertCard extends StatelessWidget {
  const _SkeletonAlertCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        border:       const Border(left: BorderSide(color: AppColors.divider, width: 4)),
        boxShadow:    AppShadows.card,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            SkeletonBox(width: 17, height: 17, radius: 4),
            SizedBox(width: 6),
            SkeletonBox(width: 100, height: 10, radius: 4),
            Spacer(),
            SkeletonBox(width: 50, height: 18, radius: 4),
            SizedBox(width: 8),
            SkeletonBox(width: 35, height: 10, radius: 4),
          ]),
          SizedBox(height: 10),
          SkeletonBox(width: double.infinity, height: 12, radius: 4),
          SizedBox(height: 10),
          Row(children: [
            SkeletonBox(width: 13, height: 13, radius: 3),
            SizedBox(width: 6),
            SkeletonBox(width: 80, height: 10, radius: 4),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shimmer animation wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _ShimmerWrapper extends StatefulWidget {
  final Widget child;
  const _ShimmerWrapper({required this.child});

  @override
  State<_ShimmerWrapper> createState() => _ShimmerWrapperState();
}

class _ShimmerWrapperState extends State<_ShimmerWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF1F5F9),
                Color(0xFFE2E8F0),
              ],
              stops: [
                (_ctrl.value - 0.3).clamp(0.0, 1.0),
                _ctrl.value,
                (_ctrl.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}
