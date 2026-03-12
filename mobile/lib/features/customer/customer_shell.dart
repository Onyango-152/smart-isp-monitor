import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../features/auth/auth_provider.dart';
import '../notifications/notifications_screen.dart';
import '../settings/settings_screen.dart';
import 'customer_home_screen.dart';
import 'fault_history_screen.dart';
import 'help_assistant_screen.dart';

/// CustomerShell — main navigation container for customer users.
///
/// Tabs:
///   0  My Service   — service status, device health, quick actions
///   1  History      — chronological fault/outage history in plain English
///   2  Help         — AI-powered troubleshooting assistant (chat)
///   3  Alerts       — notification feed
///   4  Settings     — profile, preferences, logout
///
/// Navigation adapts to screen width:
///   ≥ 600 px  → persistent collapsible side drawer, no bottom bar
///   < 600 px  → bottom NavigationBar + hamburger drawer
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key});

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
  int  _currentIndex  = 0;
  bool _drawerExpanded = true;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  static const double _wideBreakpoint  = 600.0;
  static const double _drawerWidth     = 240.0;

  void _switchTab(int index) => setState(() => _currentIndex = index);
  void _toggleDrawer() => setState(() => _drawerExpanded = !_drawerExpanded);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CustomerHomeProvider()),
        ChangeNotifierProvider(create: (_) => FaultHistoryProvider()),
        ChangeNotifierProvider(create: (_) => NotificationsProvider()),
      ],
      child: Consumer<NotificationsProvider>(
        builder: (context, notifications, _) {
          final isWide = MediaQuery.of(context).size.width >= _wideBreakpoint;

          final content = IndexedStack(
            index: _currentIndex,
            children: const [
              CustomerHomeScreen(),   // 0 — My Service
              FaultHistoryScreen(),   // 1 — History
              HelpAssistantScreen(),  // 2 — Help
              NotificationsScreen(),  // 3 — Alerts
              SettingsScreen(),       // 4 — Settings
            ],
          );

          if (isWide) {
            // ── Wide: collapsible side drawer ─────────────────────────
            return Scaffold(
              key: _scaffoldKey,
              body: Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeInOutCubic,
                    width: _drawerExpanded ? _drawerWidth : 0,
                    clipBehavior: Clip.hardEdge,
                    decoration: const BoxDecoration(),
                    child: _CustomerNavDrawer(
                      currentIndex:      _currentIndex,
                      onTabSelected:     _switchTab,
                      notificationCount: notifications.unreadCount,
                      onToggle:          _toggleDrawer,
                    ),
                  ),
                  if (_drawerExpanded)
                    const VerticalDivider(width: 1, thickness: 1),
                  Expanded(
                    child: Stack(
                      children: [
                        content,
                        if (!_drawerExpanded)
                          _buildExpandButton(context),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          // ── Narrow: bottom bar + modal hamburger drawer ───────────
          return Scaffold(
            key: _scaffoldKey,
            drawer: Drawer(
              width: _drawerWidth,
              child: _CustomerNavDrawer(
                currentIndex:      _currentIndex,
                onTabSelected:     _switchTab,
                notificationCount: notifications.unreadCount,
              ),
            ),
            body: content,
            bottomNavigationBar: _buildNavBar(context, notifications),
          );
        },
      ),
    );
  }

  // ── Floating hamburger when side drawer is collapsed ──────────────────────
  Widget _buildExpandButton(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Positioned(
      top: topPad + 6,
      left: 6,
      child: Material(
        elevation: 3,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(10),
        color: Theme.of(context).colorScheme.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _toggleDrawer,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(Icons.menu_rounded,
                size: 24, color: AppColors.textSecondaryOf(context)),
          ),
        ),
      ),
    );
  }

  // ── Bottom NavigationBar (narrow screens) ─────────────────────────────────
  Widget _buildNavBar(
      BuildContext context, NotificationsProvider notifications) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _switchTab,
      indicatorColor: AppColors.primarySurfaceOf(context),
      backgroundColor:
          Theme.of(context).navigationBarTheme.backgroundColor,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      height: 64,
      destinations: [
        const NavigationDestination(
          icon:         Icon(Icons.wifi_outlined),
          selectedIcon: Icon(Icons.wifi_rounded),
          label:        'My Service',
        ),
        const NavigationDestination(
          icon:         Icon(Icons.history_outlined),
          selectedIcon: Icon(Icons.history_rounded),
          label:        'History',
        ),
        const NavigationDestination(
          icon:         Icon(Icons.support_agent_outlined),
          selectedIcon: Icon(Icons.support_agent_rounded),
          label:        'Help',
        ),
        NavigationDestination(
          icon: _NavBadge(
            icon:       Icons.notifications_outlined,
            count:      notifications.unreadCount,
            badgeColor: AppColors.severityCritical,
          ),
          selectedIcon: _NavBadge(
            icon:       Icons.notifications_rounded,
            count:      notifications.unreadCount,
            badgeColor: AppColors.severityCritical,
            isSelected: true,
          ),
          label: 'Alerts',
        ),
        const NavigationDestination(
          icon:         Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings_rounded),
          label:        'Settings',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CustomerNavDrawer — collapsible side nav for customer role
// ─────────────────────────────────────────────────────────────────────────────

class _CustomerNavDrawer extends StatelessWidget {
  final int                currentIndex;
  final ValueChanged<int>  onTabSelected;
  final int                notificationCount;
  final VoidCallback?      onToggle; // null → hamburger hidden (modal drawer)

  const _CustomerNavDrawer({
    required this.currentIndex,
    required this.onTabSelected,
    this.notificationCount = 0,
    this.onToggle,
  });

  static const _tabs = [
    (icon: Icons.wifi_outlined,           selIcon: Icons.wifi_rounded,              label: 'My Service', idx: 0),
    (icon: Icons.history_outlined,        selIcon: Icons.history_rounded,           label: 'History',    idx: 1),
    (icon: Icons.support_agent_outlined,  selIcon: Icons.support_agent_rounded,     label: 'Help',       idx: 2),
    (icon: Icons.notifications_outlined,  selIcon: Icons.notifications_rounded,     label: 'Alerts',     idx: 3),
    (icon: Icons.settings_outlined,       selIcon: Icons.settings_rounded,          label: 'Settings',   idx: 4),
  ];

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final username  = auth.currentUser?.username ?? 'Customer';
    final firstName = username.split(' ').first;
    final isDark    = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: 240,
      child: Material(
        elevation: 2,
        shadowColor: Colors.black26,
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        child: Column(
          children: [
            // ── Gradient header ────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                  0, MediaQuery.of(context).padding.top, 0, 0),
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
              child: Column(
                children: [
                  // Hamburger row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
                    child: Row(
                      children: [
                        if (onToggle != null)
                          IconButton(
                            icon: const Icon(Icons.menu_rounded,
                                color: Colors.white, size: 22),
                            tooltip: 'Collapse menu',
                            onPressed: onToggle,
                          )
                        else
                          const SizedBox(width: 48),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Smart ISP',
                            style: TextStyle(
                              color:      Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize:   15,
                              letterSpacing: 0.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // User row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 12, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(
                            child: Text(
                              firstName[0].toUpperCase(),
                              style: const TextStyle(
                                color:      Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize:   15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                firstName,
                                style: const TextStyle(
                                  color:      Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize:   13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const Text(
                                'Customer',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // ── Nav tiles ──────────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: _tabs.map((t) {
                  final isActive = t.idx == currentIndex;
                  final badge =
                      t.idx == 3 ? notificationCount : 0;

                  final iconColor  = isActive
                      ? AppColors.primary
                      : AppColors.textSecondaryOf(context);
                  final labelColor = isActive
                      ? AppColors.primary
                      : AppColors.textPrimaryOf(context);

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    child: Material(
                      color: isActive
                          ? AppColors.primarySurfaceOf(context)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () {
                          onTabSelected(t.idx);
                          if (Scaffold.maybeOf(context)?.isDrawerOpen ??
                              false) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 12),
                          child: Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    isActive ? t.selIcon : t.icon,
                                    size:  22,
                                    color: iconColor,
                                  ),
                                  if (badge > 0)
                                    Positioned(
                                      right: -6,
                                      top:   -4,
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(
                                          minWidth:  16,
                                          minHeight: 16,
                                        ),
                                        padding:
                                            const EdgeInsets.symmetric(
                                          horizontal: 3,
                                          vertical:   1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors
                                              .severityCritical,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          badge > 9 ? '9+' : '$badge',
                                          style: const TextStyle(
                                            color:      Colors.white,
                                            fontSize:   9,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  t.label,
                                  style: TextStyle(
                                    fontSize:   14,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: labelColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ── Footer hint ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Icon(Icons.circle,
                      size: 8, color: AppColors.online),
                  const SizedBox(width: 6),
                  Text(
                    'Connected',
                    style: TextStyle(
                      fontSize: 11,
                      color:    AppColors.textHintOf(context),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NavBadge — icon with optional count badge (bottom bar)
// ─────────────────────────────────────────────────────────────────────────────

class _NavBadge extends StatelessWidget {
  final IconData icon;
  final int      count;
  final Color    badgeColor;
  final bool     isSelected;
  const _NavBadge({
    required this.icon,
    required this.count,
    required this.badgeColor,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon, color: isSelected ? AppColors.primary : null),
        if (count > 0)
          Positioned(
            right: -6,
            top:   -4,
            child: Container(
              constraints:
                  const BoxConstraints(minWidth: 16, minHeight: 16),
              padding: const EdgeInsets.symmetric(
                  horizontal: 3, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                count > 9 ? '9+' : '$count',
                style: const TextStyle(
                  color:      Colors.white,
                  fontSize:   9,
                  fontWeight: FontWeight.bold,
                  height:     1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
