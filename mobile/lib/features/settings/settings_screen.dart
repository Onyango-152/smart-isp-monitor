import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/theme_provider.dart';
import '../../core/utils.dart';
import '../auth/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// SettingsProvider
// ─────────────────────────────────────────────────────────────────────────────

class SettingsProvider extends ChangeNotifier {
  bool _pushAlerts       = true;
  bool _pushCriticalOnly = false;
  bool _pushSystem       = true;
  bool _compactList      = false;
  int  _refreshInterval  = 30;
  bool _autoAcknowledge  = false;

  bool get pushAlerts       => _pushAlerts;
  bool get pushCriticalOnly => _pushCriticalOnly;
  bool get pushSystem       => _pushSystem;
  bool get compactList      => _compactList;
  int  get refreshInterval  => _refreshInterval;
  bool get autoAcknowledge  => _autoAcknowledge;

  void toggle(String key) {
    switch (key) {
      case 'pushAlerts':
        _pushAlerts = !_pushAlerts;
        if (!_pushAlerts) _pushCriticalOnly = false;
        break;
      case 'pushCriticalOnly':
        if (_pushAlerts) _pushCriticalOnly = !_pushCriticalOnly;
        break;
      case 'pushSystem':      _pushSystem      = !_pushSystem;      break;
      case 'compactList':     _compactList     = !_compactList;     break;
      case 'autoAcknowledge': _autoAcknowledge = !_autoAcknowledge; break;
    }
    notifyListeners();
  }

  void setRefreshInterval(int s) {
    _refreshInterval = s;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SettingsScreen
// ─────────────────────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, this.title = 'Settings'});

  final String title;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child: _SettingsContent(title: title),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final auth       = context.read<AuthProvider>();
    final settings   = context.watch<SettingsProvider>();
    final theme      = context.watch<ThemeProvider>();
    final user       = auth.currentUser;
    final isCustomer = user?.role == AppConstants.roleCustomer;

    return Scaffold(
      backgroundColor: AppColors.bg(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin:  Alignment.topLeft,
              end:    Alignment.bottomRight,
              colors: [AppColors.appBarGradientStart, AppColors.appBarGradientEnd],
            ),
          ),
        ),
        title: Text(title,
            style: TextStyle(color: AppColors.textOnDark)),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 48),
        children: [

          // ── Hero ─────────────────────────────────────────────────────
          _buildHero(context, user),

          const SizedBox(height: 28),

          // ── Notifications ─────────────────────────────────────────────
          _buildCard(context, 'Notifications', [
            _Tile(
              title:    'Push Alerts',
              subtitle: 'Receive push notifications for network alerts',
              trailing: Switch(
                value:       settings.pushAlerts,
                onChanged:   (_) => settings.toggle('pushAlerts'),
                activeColor: AppColors.primary,
              ),
            ),
            if (!isCustomer)
              _Tile(
                title:    'Critical Alerts Only',
                subtitle: 'Only notify for critical severity alerts',
                enabled:  settings.pushAlerts,
                trailing: Switch(
                  value:     settings.pushAlerts ? settings.pushCriticalOnly : false,
                  onChanged: settings.pushAlerts
                      ? (_) => settings.toggle('pushCriticalOnly')
                      : null,
                  activeColor: AppColors.primary,
                ),
              ),
            _Tile(
              title:    'System Notifications',
              subtitle: 'Monitoring cycles, device changes, and system events',
              isLast:   true,
              trailing: Switch(
                value:       settings.pushSystem,
                onChanged:   (_) => settings.toggle('pushSystem'),
                activeColor: AppColors.primary,
              ),
            ),
          ]),

          const SizedBox(height: 12),

          // ── Display ───────────────────────────────────────────────────
          _buildCard(context, 'Display', [
            _Tile(
              title:    'Dark Mode',
              subtitle: 'Switch to a dark colour scheme',
              trailing: Switch(
                value:     theme.isDarkMode,
                onChanged: (val) => theme.setDarkMode(val),
              ),
              isLast: isCustomer,
            ),
            if (!isCustomer)
              _Tile(
                title:    'Compact Device List',
                subtitle: 'Show smaller device rows to fit more on screen',
                isLast:   true,
                trailing: Switch(
                  value:       settings.compactList,
                  onChanged:   (_) => settings.toggle('compactList'),
                  activeColor: AppColors.primary,
                ),
              ),
          ]),

          const SizedBox(height: 12),

          // ── Monitoring (non-customer only) ────────────────────────────
          if (!isCustomer) ...[
            _buildCard(context, 'Monitoring', [
              _Tile(
                title:    'Refresh Interval',
                subtitle: 'How often the dashboard auto-refreshes',
                trailing: _RefreshIntervalSelector(settings: settings),
              ),
              _Tile(
                title:    'Auto-Acknowledge Low Alerts',
                subtitle: 'Automatically acknowledge low-severity alerts',
                isLast:   true,
                trailing: Switch(
                  value:       settings.autoAcknowledge,
                  onChanged:   (_) => settings.toggle('autoAcknowledge'),
                  activeColor: AppColors.primary,
                ),
              ),
            ]),
            const SizedBox(height: 12),
          ],

          // ── System ────────────────────────────────────────────────────
          _buildCard(context, 'System', [
            if (!isCustomer)
              _Tile(
                title:    'API Endpoint',
                subtitle: AppConstants.baseUrl,
                trailing: Icon(Icons.chevron_right_rounded,
                    color: AppColors.textSecondaryOf(context)),
                onTap: () =>
                    AppUtils.showSnackbar(context, 'Endpoint config coming soon.'),
              ),
            _Tile(
              title:    'App Version',
              subtitle: 'ISP Monitor v${AppConstants.appVersion}',
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        AppColors.primarySurfaceOf(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Up to date',
                    style: AppTextStyles.label.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark 
                            ? AppColors.primaryLight 
                            : AppColors.primary)),
              ),
            ),
            _Tile(
              title:    'Send Feedback',
              subtitle: 'Report a bug or suggest a feature',
              trailing: Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryOf(context)),
              onTap: () {
                AppUtils.haptic();
                AppUtils.showSnackbar(context, 'Feedback feature coming soon.');
              },
            ),
            _Tile(
              title:    'About ISP Monitor',
              subtitle: 'Version ${AppConstants.appVersion} — build 1',
              trailing: Icon(Icons.chevron_right_rounded,
                  color: AppColors.textSecondaryOf(context)),
              onTap: () => showAboutDialog(
                context:            context,
                applicationName:    'ISP Monitor',
                applicationVersion: AppConstants.appVersion,
                applicationLegalese: '© 2026 Smart ISP',
              ),
            ),
            _Tile(
              title:    'Sign Out',
              subtitle: 'Log out of ISP Monitor',
              isLast:   true,
              iconColor: AppColors.offline,
              trailing: const Icon(Icons.logout_rounded,
                  color: AppColors.offline, size: 20),
              onTap: () => _confirmLogout(context, auth),
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context, dynamic user) {
    final name  = user?.username ?? 'User';
    final email = user?.email    ?? '';
    final role  = user?.role     ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    final roleLabel = role == AppConstants.roleTechnician ? 'Technician'
        : role == AppConstants.roleManager                ? 'Manager'
        : role == AppConstants.roleCustomer               ? 'Customer'
        :                                                   'Admin';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
      child: Column(
        children: [
          CircleAvatar(
            radius:          40,
            backgroundColor: AppColors.primarySurfaceOf(context),
            child: Text(
              initial,
              style: TextStyle(
                color:      Theme.of(context).brightness == Brightness.dark 
                    ? AppColors.primaryLight 
                    : AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize:   32,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: TextStyle(
              fontSize:   22,
              fontWeight: FontWeight.w700,
              color:      AppColors.textPrimaryOf(context),
            ),
          ),
          const SizedBox(height: 4),
          if (email.isNotEmpty)
            Text(
              email,
              style: TextStyle(
                fontSize: 13,
                color:    AppColors.textSecondaryOf(context),
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color:        AppColors.primarySurfaceOf(context),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              roleLabel,
              style: TextStyle(
                color:      Theme.of(context).brightness == Brightness.dark 
                    ? AppColors.primaryLight 
                    : AppColors.primary,
                fontSize:   12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Card builder ──────────────────────────────────────────────────────────

  Widget _buildCard(BuildContext context, String title, List<Widget> tiles) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color:        AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize:      11,
                  fontWeight:    FontWeight.w700,
                  letterSpacing: 1.1,
                  color:         AppColors.textSecondaryOf(context),
                ),
              ),
            ),
            Divider(height: 8, color: AppColors.dividerOf(context)),
            ...tiles,
          ],
        ),
      ),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    final parentContext = context;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:     const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                await auth.logout();
              } catch (_) {
                // Still navigate to login even if logout cleanup fails.
              }
              if (!parentContext.mounted) return;
              Navigator.of(parentContext, rootNavigator: true)
                  .pushNamedAndRemoveUntil(
                AppConstants.loginRoute, (r) => false);
            },
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.offline),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _Tile — Material + InkWell for proper ripple
// ─────────────────────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final String        title;
  final String        subtitle;
  final Widget?       trailing;
  final bool          isLast;
  final bool          enabled;
  final Color?        iconColor;
  final VoidCallback? onTap;

  const _Tile({
    required this.title,
    required this.subtitle,
    this.trailing,
    this.isLast   = false,
    this.enabled  = true,
    this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = isLast
        ? const BorderRadius.vertical(bottom: Radius.circular(14))
        : BorderRadius.zero;

    return Column(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled && onTap != null
                ? () { AppUtils.hapticSelect(); onTap!(); }
                : null,
            borderRadius: radius,
            child: Opacity(
              opacity: enabled ? 1.0 : 0.45,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 13),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize:   14,
                              color:      iconColor ?? AppColors.textPrimaryOf(context),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(subtitle,
                              style: TextStyle(
                                  fontSize: 12,
                                  color:    AppColors.textSecondaryOf(context))),
                        ],
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 8),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, color: AppColors.dividerOf(context)),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _RefreshIntervalSelector
// ─────────────────────────────────────────────────────────────────────────────

class _RefreshIntervalSelector extends StatelessWidget {
  final SettingsProvider settings;
  const _RefreshIntervalSelector({required this.settings});

  static const _values = [15,      30,      60,      120,      300     ];
  static const _labels = ['15 s',  '30 s',  '1 min', '2 min',  '5 min' ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DropdownButton<int>(
      value:     settings.refreshInterval,
      underline: const SizedBox.shrink(),
      style:     AppTextStyles.label.copyWith(
        color: isDark ? AppColors.primaryLight : AppColors.primary,
      ),
      icon:      const SizedBox.shrink(),
      onChanged: (v) {
        if (v != null) {
          AppUtils.hapticSelect();
          settings.setRefreshInterval(v);
        }
      },
      items: List.generate(
        _values.length,
        (i) => DropdownMenuItem(value: _values[i], child: Text(_labels[i])),
      ),
    );
  }
}
