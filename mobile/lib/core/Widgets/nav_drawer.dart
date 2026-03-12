import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme.dart';
import '../../features/auth/auth_provider.dart';

/// Item definition for the navigation drawer.
class _NavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String   label;
  final int?     tabIndex;   // non-null → switches IndexedStack tab
  final Color?   iconColor;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.tabIndex,
    this.iconColor,
  });
}

/// Side navigation drawer for the technician interface.
///
/// The drawer always renders at its full 260 px width — the parent
/// (TechnicianShell) controls visibility by animating an outer
/// container's width between 260 and 0.
///
/// When [onToggle] is non-null a hamburger button is shown in the
/// header so the user can collapse the drawer.  On narrow screens
/// (Scaffold overlay) [onToggle] is typically null and dismissal is
/// handled by the framework.
class NavDrawer extends StatelessWidget {
  final int  currentIndex;
  final ValueChanged<int> onTabSelected;
  final int alertCount;
  final int notificationCount;
  /// Called when the user taps the hamburger toggle.  If null the
  /// hamburger button is hidden (e.g. when used inside Scaffold.drawer).
  final VoidCallback? onToggle;

  const NavDrawer({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    this.alertCount        = 0,
    this.notificationCount = 0,
    this.onToggle,
  });

  static const double width = 260.0;

  // ── Items ─────────────────────────────────────────────────────────────────

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.dashboard_outlined,      selectedIcon: Icons.dashboard_rounded,      label: 'Dashboard',     tabIndex: 0),
    _NavItem(icon: Icons.router_outlined,          selectedIcon: Icons.router_rounded,          label: 'Devices',       tabIndex: 1),
    _NavItem(icon: Icons.people_outline_rounded,   selectedIcon: Icons.people_rounded,          label: 'Clients',       tabIndex: 2),
    _NavItem(icon: Icons.warning_amber_rounded,    selectedIcon: Icons.warning_rounded,         label: 'Alerts',        tabIndex: 3, iconColor: AppColors.degraded),
    _NavItem(icon: Icons.task_alt_outlined,         selectedIcon: Icons.task_alt_rounded,         label: 'Tasks',         tabIndex: 4),
    _NavItem(icon: Icons.assessment_outlined,       selectedIcon: Icons.assessment_rounded,       label: 'Reports',       tabIndex: 5),
    _NavItem(icon: Icons.settings_outlined,         selectedIcon: Icons.settings_rounded,         label: 'Settings',      tabIndex: 7),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;
    final firstName = (user?.username ?? 'Technician').split(' ').first;

    return SizedBox(
      width: width,
      child: Material(
        elevation: 2,
        shadowColor: Colors.black26,
        child: Container(
          color: AppColors.surface,
          child: Column(
            children: [
              // ── Header / branding ───────────────────────────────────
              _buildHeader(context, firstName),
              const Divider(height: 1),

              // ── Nav items ───────────────────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: _items.map((item) =>
                      _buildNavTile(context, item)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, String name) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        0, MediaQuery.of(context).padding.top, 0, 0,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin:  Alignment.topLeft,
          end:    Alignment.bottomRight,
          colors: [AppColors.appBarGradientStart, AppColors.appBarGradientEnd],
        ),
      ),
      child: Column(
        children: [
          // ── Top row: hamburger + branding ───────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
            child: Row(
              children: [
                if (onToggle != null)
                  IconButton(
                    icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
                    tooltip: 'Collapse menu',
                    onPressed: onToggle,
                  )
                else
                  const SizedBox(width: 48), // keep alignment when no toggle
                const SizedBox(width: 4),
                const Expanded(
                  child: Text(
                    'Smart ISP',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── User row: avatar + name ────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      name[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text('Technician', style: TextStyle(
                        color: Colors.white70, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Nav item tile ───────────────────────────────────────────────────────

  Widget _buildNavTile(BuildContext context, _NavItem item) {
    final isActive = item.tabIndex != null &&
        item.tabIndex == currentIndex;
    final isDisabled = item.tabIndex == null;

    final iconColor = isActive
        ? AppColors.primary
        : isDisabled
            ? AppColors.textHint
            : item.iconColor ?? AppColors.textSecondary;

    final labelColor = isActive
        ? AppColors.primary
        : isDisabled
            ? AppColors.textHint
            : AppColors.textPrimary;

    // Badge count
    int badge = 0;
    if (item.label == 'Alerts')        badge = alertCount;
    if (item.label == 'Notifications') badge = notificationCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Material(
        color: isActive ? AppColors.primarySurface : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: isDisabled
              ? () => _showComingSoon(context, item.label)
              : () {
                  onTabSelected(item.tabIndex!);
                  // Close drawer on mobile after tap
                  if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
                    Navigator.of(context).pop();
                  }
                },
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical:   12,
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      isActive ? item.selectedIcon : item.icon,
                      size:  22,
                      color: iconColor,
                    ),
                    if (badge > 0)
                      Positioned(
                        right: -6, top: -4,
                        child: _Badge(count: badge, color: item.iconColor ?? AppColors.offline),
                      ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontSize:   14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                      color:      labelColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isDisabled)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Soon', style: TextStyle(
                      fontSize: 9, fontWeight: FontWeight.bold,
                      color: AppColors.textHint)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape:    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small badge widget
// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final int   count;
  final Color color;
  const _Badge({required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      padding:     const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration:  BoxDecoration(
        color:        color,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold,
          height: 1.3),
        textAlign: TextAlign.center,
      ),
    );
  }
}
