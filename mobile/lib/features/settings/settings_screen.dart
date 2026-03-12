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
      case 'pushSystem':       _pushSystem       = !_pushSystem;       break;
      case 'compactList':      _compactList      = !_compactList;      break;
      case 'autoAcknowledge':  _autoAcknowledge  = !_autoAcknowledge;  break;
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
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SettingsProvider(),
      child:  const _SettingsContent(),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    final auth     = context.read<AuthProvider>();
    final settings = context.watch<SettingsProvider>();
    final theme    = context.watch<ThemeProvider>();
    final user     = auth.currentUser;

    return Scaffold(


      // ── App Bar ───────────────────────────────────────────────────────────
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        flexibleSpace: Container(
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
        ),
        title: const Text('Settings',
            style: TextStyle(color: Colors.white)),
      ),

      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [

          // ── Profile card ───────────────────────────────────────────────
          _buildProfileCard(
            context: context,
            name:  user?.username ?? 'User',
            email: user?.email    ?? '',
            role:  user?.role     ?? '',
          ),

          const SizedBox(height: 8),

          // ── Notifications ──────────────────────────────────────────────
          const _SectionTitle('Notifications'),
          _buildCard([
            _SettingsTile(
              icon:      Icons.notifications_active_rounded,
              iconColor: AppColors.primary,
              title:    'Push Alerts',
              subtitle: 'Receive push notifications for network alerts',
              trailing: Switch(
                value:      settings.pushAlerts,
                onChanged:  (_) => settings.toggle('pushAlerts'),
                activeColor: AppColors.primary,
              ),
            ),
            _SettingsTile(
              icon:      Icons.priority_high_rounded,
              iconColor: AppUtils.severityColor(AppConstants.severityCritical),
              title:     'Critical Alerts Only',
              subtitle:  'Only notify for critical severity alerts',
              enabled:   settings.pushAlerts,
              trailing: Switch(
                value:     settings.pushAlerts ? settings.pushCriticalOnly : false,
                onChanged: settings.pushAlerts
                    ? (_) => settings.toggle('pushCriticalOnly')
                    : null,
                activeColor: AppColors.primary,
              ),
            ),
            _SettingsTile(
              icon:      Icons.info_rounded,
              iconColor: AppColors.primaryLight,
              title:     'System Notifications',
              subtitle:  'Monitoring cycles, device changes, and system events',
              isLast:    true,
              trailing: Switch(
                value:      settings.pushSystem,
                onChanged:  (_) => settings.toggle('pushSystem'),
                activeColor: AppColors.primary,
              ),
            ),
          ]),

          const SizedBox(height: 4),

          // ── Display ────────────────────────────────────────────────────
          const _SectionTitle('Display'),
          _buildCard([
            _SettingsTile(
              icon:      Icons.dark_mode_rounded,
              iconColor: AppColors.primaryDark,
              title:     'Dark Mode',
              subtitle:  'Switch to a dark colour scheme',
              trailing: Switch(
                // ThemeProvider is the single source of truth for dark mode.
                // SettingsProvider no longer holds a _darkMode bool.
                value:     theme.isDarkMode,
                onChanged: (val) => theme.setDarkMode(val),
              ),
            ),
            _SettingsTile(
              icon:      Icons.view_list_rounded,
              iconColor: AppColors.primaryLight,
              title:     'Compact Device List',
              subtitle:  'Show smaller device rows to fit more on screen',
              isLast:    true,
              trailing: Switch(
                value:      settings.compactList,
                onChanged:  (_) => settings.toggle('compactList'),
                activeColor: AppColors.primary,
              ),
            ),
          ]),

          const SizedBox(height: 4),

          // ── Monitoring ─────────────────────────────────────────────────
          const _SectionTitle('Monitoring'),
          _buildCard([
            _SettingsTile(
              icon:      Icons.timer_rounded,
              iconColor: AppColors.degraded,
              title:     'Refresh Interval',
              subtitle:  'How often the dashboard auto-refreshes',
              trailing:  _RefreshIntervalSelector(settings: settings),
            ),
            _SettingsTile(
              icon:      Icons.check_circle_rounded,
              iconColor: AppColors.online,
              title:     'Auto-Acknowledge Low Alerts',
              subtitle:  'Automatically acknowledge low-severity alerts',
              isLast:    true,
              trailing: Switch(
                value:      settings.autoAcknowledge,
                onChanged:  (_) => settings.toggle('autoAcknowledge'),
                activeColor: AppColors.primary,
              ),
            ),
          ]),

          const SizedBox(height: 4),

          // ── System ─────────────────────────────────────────────────────
          const _SectionTitle('System'),
          _buildCard([
            _SettingsTile(
              icon:      Icons.link_rounded,
              iconColor: AppColors.primaryLight,
              title:     'API Endpoint',
              subtitle:  AppConstants.baseUrl,
              trailing:  Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHintOf(context)),
              onTap: () =>
                  AppUtils.showSnackbar(context, 'Endpoint config coming soon.'),
            ),
            _SettingsTile(
              icon:      Icons.info_outline_rounded,
              iconColor: AppColors.textSecondary,
              title:     'App Version',
              subtitle:  'ISP Monitor v${AppConstants.appVersion}',
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color:        AppColors.primarySurfaceOf(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Up to date',
                    style: AppTextStyles.label.copyWith(
                        color: AppColors.primary)),
              ),
            ),
            _SettingsTile(
              icon:      Icons.bug_report_rounded,
              iconColor: AppColors.textSecondary,
              title:     'Send Feedback',
              subtitle:  'Report a bug or suggest a feature',
              isLast:    true,
              trailing:  Icon(Icons.chevron_right_rounded,
                  color: AppColors.textHintOf(context)),
              onTap: () {
                AppUtils.haptic();
                AppUtils.showSnackbar(
                    context, 'Feedback feature coming soon.');
              },
            ),
          ]),

          const SizedBox(height: 20),

          // ── Sign Out ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () {
                AppUtils.haptic();
                _confirmLogout(context, auth);
              },
              style: OutlinedButton.styleFrom(
                minimumSize:     const Size(double.infinity, 52),
                foregroundColor: AppColors.offline,
                side:  const BorderSide(color: AppColors.offline),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon:  const Icon(Icons.logout_rounded),
              label: const Text('Sign Out',
                  style: TextStyle(
                      fontSize:   16,
                      fontWeight: FontWeight.w600)),
            ),
          ),

          // ── Delete account ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextButton(
              onPressed: () {
                AppUtils.hapticSelect();
                AppUtils.showSnackbar(
                  context,
                  'Account deletion requires contacting your administrator.',
                );
              },
              child: Text('Delete Account',
                  style: AppTextStyles.body.copyWith(
                      color: AppColors.offline)),
            ),
          ),
        ],
      ),
    );
  }

  // ── Profile card ───────────────────────────────────────────────────────────

  Widget _buildProfileCard({
    required BuildContext context,
    required String name,
    required String email,
    required String role,
  }) {
    final roleLabel = role == AppConstants.roleTechnician ? 'Technician'
        : role == AppConstants.roleManager                ? 'Manager'
        : role == AppConstants.roleCustomer               ? 'Customer'
        :                                                   'Admin';

    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        // Matches the app bar gradient for visual cohesion
        gradient: const LinearGradient(
          colors: [
            AppColors.appBarGradientStart,
            AppColors.appBarGradientEnd,
          ],
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.heroCard,
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width:  56, height: 56,
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: Colors.white.withOpacity(0.4), width: 2),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                  color:      Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Name / email / role badge
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: AppTextStyles.heading2.copyWith(
                        color: Colors.white)),
                const SizedBox(height: 2),
                Text(email,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.75))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color:        Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.35)),
                  ),
                  child: Text(roleLabel,
                      style: AppTextStyles.label.copyWith(
                          color: Colors.white)),
                ),
              ],
            ),
          ),

          // Edit button
          IconButton(
            icon: const Icon(Icons.edit_rounded,
                color: Colors.white70, size: 20),
            onPressed: () {
              AppUtils.haptic();
              AppUtils.showSnackbar(
                  context, 'Profile editing coming soon.');
            },
          ),
        ],
      ),
    );
  }

  // ── Card wrapper ───────────────────────────────────────────────────────────

  static Widget _buildCard(List<Widget> children) {
    return Container(
      margin:     const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color:        Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow:    AppShadows.card,
      ),
      child: Column(children: children),
    );
  }

  // ── Logout ─────────────────────────────────────────────────────────────────

  void _confirmLogout(BuildContext context, AuthProvider auth) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title:   const Text('Sign Out'),
        content: const Text(
            'Are you sure you want to sign out of ISP Monitor?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child:     const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              auth.logout();
              Navigator.of(context)
                  .pushReplacementNamed(AppConstants.loginRoute);
            },
            style: TextButton.styleFrom(
                foregroundColor: AppColors.offline),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SectionTitle
// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color:         AppColors.textHint,
          fontWeight:    FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SettingsTile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData     icon;
  final Color        iconColor;
  final String       title;
  final String       subtitle;
  final Widget       trailing;
  final bool         isLast;
  final bool         enabled;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.isLast  = false,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveOnTap = enabled && onTap != null
        ? () { AppUtils.hapticSelect(); onTap!(); }
        : null;

    return Column(
      children: [
        InkWell(
          onTap:        effectiveOnTap,
          borderRadius: isLast
              ? const BorderRadius.only(
                  bottomLeft:  Radius.circular(14),
                  bottomRight: Radius.circular(14))
              : BorderRadius.zero,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.45,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 13),
              child: Row(
                children: [
                  // Icon container
                  Container(
                    width:  36, height: 36,
                    decoration: BoxDecoration(
                      color:        iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: iconColor, size: 18),
                  ),
                  const SizedBox(width: 12),

                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: AppTextStyles.body.copyWith(
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  trailing,
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 64, endIndent: 16),
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

  static const _values = [15,     30,     60,       120,      300     ];
  static const _labels = ['15 s', '30 s', '1 min',  '2 min',  '5 min' ];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<int>(
      value:     settings.refreshInterval,
      underline: const SizedBox.shrink(),
      style:     AppTextStyles.label.copyWith(color: AppColors.primary),
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: AppColors.primary, size: 18),
      onChanged: (v) {
        if (v != null) {
          AppUtils.hapticSelect();
          settings.setRefreshInterval(v);
        }
      },
      items: List.generate(
        _values.length,
        (i) => DropdownMenuItem(
          value: _values[i],
          child: Text(_labels[i]),
        ),
      ),
    );
  }
}
