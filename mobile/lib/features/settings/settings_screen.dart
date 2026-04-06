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
    final isCustomer = (user?.role == AppConstants.roleCustomer);

    return Scaffold(
      backgroundColor: AppColors.bg(context),


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
          style: TextStyle(color: AppColors.textOnDark)),
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
          _buildCard(context, [
            _SettingsTile(
              title:    'Push Alerts',
              subtitle: 'Receive push notifications for network alerts',
              trailing: Switch(
                value:      settings.pushAlerts,
                onChanged:  (_) => settings.toggle('pushAlerts'),
                activeColor: AppColors.primary,
              ),
            ),
            if (!isCustomer)
              _SettingsTile(
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
          _buildCard(context, [
            _SettingsTile(
              title:     'Dark Mode',
              subtitle:  'Switch to a dark colour scheme',
              trailing: Switch(
                // ThemeProvider is the single source of truth for dark mode.
                // SettingsProvider no longer holds a _darkMode bool.
                value:     theme.isDarkMode,
                onChanged: (val) => theme.setDarkMode(val),
              ),
              isLast: true,
            ),
            if (!isCustomer)
              _SettingsTile(
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
          _buildCard(context, [
            _SettingsTile(
              title:     'Refresh Interval',
              subtitle:  'How often the dashboard auto-refreshes',
              trailing:  _RefreshIntervalSelector(settings: settings),
            ),
            _SettingsTile(
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
          _buildCard(context, [
            if (!isCustomer)
              _SettingsTile(
                title:     'API Endpoint',
                subtitle:  AppConstants.baseUrl,
                trailing:  const SizedBox.shrink(),
                onTap: () =>
                    AppUtils.showSnackbar(context, 'Endpoint config coming soon.'),
              ),
            _SettingsTile(
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
              title:     'Send Feedback',
              subtitle:  'Report a bug or suggest a feature',
              isLast:    true,
              trailing:  const SizedBox.shrink(),
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
            child: OutlinedButton(
              onPressed: () {
                AppUtils.haptic();
                _confirmLogout(context, auth);
              },
              style: OutlinedButton.styleFrom(
                minimumSize:     const Size(double.infinity, 52),
                foregroundColor: AppColors.primary,
                side:  const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Sign Out',
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
                      color: AppColors.primary)),
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
              color:        AppColors.textOnDark.withOpacity(0.2),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: AppColors.textOnDark.withOpacity(0.4), width: 2),
            ),
            child: Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : 'U',
                style: const TextStyle(
                  fontSize:   24,
                  fontWeight: FontWeight.bold,
                  color:      AppColors.textOnDark,
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
                        color: AppColors.textOnDark)),
                const SizedBox(height: 2),
                Text(email,
                    style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textOnDark.withOpacity(0.75))),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color:        AppColors.textOnDark.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: AppColors.textOnDark.withOpacity(0.35)),
                  ),
                  child: Text(roleLabel,
                      style: AppTextStyles.label.copyWith(
                          color: AppColors.textOnDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Card wrapper ───────────────────────────────────────────────────────────

  static Widget _buildCard(BuildContext context, List<Widget> children) {
    return Container(
      margin:     const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color:        AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border:       Border.all(color: AppColors.primary.withOpacity(0.12)),
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
                foregroundColor: AppColors.primary),
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
          color:         AppColors.primary,
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
  final String       title;
  final String       subtitle;
  final Widget?      trailing;
  final bool         isLast;
  final bool         enabled;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.title,
    required this.subtitle,
    this.trailing,
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
                  if (trailing != null) ...[
                    const SizedBox(width: 8),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 16, endIndent: 16,
              color: AppColors.primary.withOpacity(0.15)),
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
      icon: const SizedBox.shrink(),
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
