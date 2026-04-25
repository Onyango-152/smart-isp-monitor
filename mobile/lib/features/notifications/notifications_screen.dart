import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/empty_state.dart';
import '../../data/dummy_data.dart';
import '../../data/models/alert_model.dart';
import '../../data/models/invitation_model.dart';
import '../../services/api_client.dart';
import '../../services/notification_service.dart';

enum NotificationType { alert, resolved, info, system, invitation }

class NotificationItem {
  final int id;
  final String title;
  final String body;
  final NotificationType type;
  final String severity;
  final String timestamp;
  final String? deviceName;
  // invitation-specific
  final String? invitationToken;
  final String? invitationOrgName;
  final String? invitationRole;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.severity,
    required this.timestamp,
    this.deviceName,
    this.invitationToken,
    this.invitationOrgName,
    this.invitationRole,
    this.isRead = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationsProvider
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsProvider extends ChangeNotifier {
  // ── State ──────────────────────────────────────────────────────────────────
  bool _isLoading = false;
  String? _errorMessage;
  String _filter = 'all';

  // ── Data ───────────────────────────────────────────────────────────────────
  List<NotificationItem> _all = [];

  // ── Getters ────────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  bool get hasError => _errorMessage != null;
  String? get errorMessage => _errorMessage;
  String get filter => _filter;

  List<NotificationItem> get all => _all;
  List<NotificationItem> get unread => _all.where((n) => !n.isRead).toList();
  int get unreadCount => unread.length;

  List<NotificationItem> get filtered {
    switch (_filter) {
      case 'unread':
        return _all.where((n) => !n.isRead).toList();
      case 'alerts':
        return _all
            .where((n) =>
                n.type == NotificationType.alert ||
                n.type == NotificationType.resolved)
            .toList();
      case 'invitations':
        return _all.where((n) => n.type == NotificationType.invitation).toList();
      case 'system':
        return _all
            .where((n) =>
                n.type == NotificationType.system ||
                n.type == NotificationType.info)
            .toList();
      default:
        return _all;
    }
  }

  void setFilter(String f) {
    _filter = f;
    notifyListeners();
  }

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        ApiClient.getMyAlerts(),
        ApiClient.getMyInvitations(),
      ]);
      final alerts      = results[0] as List<AlertModel>;
      final invitations = results[1] as List<InvitationModel>;

      final alertItems = alerts.map(_fromAlert).toList();
      final inviteItems = invitations.map(_fromInvitation).toList();

      _all = [...inviteItems, ...alertItems]
        ..sort((a, b) =>
            DateTime.parse(b.timestamp).compareTo(DateTime.parse(a.timestamp)));

      await _notifyNewAlerts(alerts);
      await _notifyNewInvitations(invitations);
    } catch (e) {
      _all = DummyData.notifications.map((n) {
        final typeStr = (n['type'] as String? ?? 'info').toLowerCase();
        final type = typeStr == 'alert'
            ? NotificationType.alert
            : typeStr == 'resolved'
                ? NotificationType.resolved
                : typeStr == 'system'
                    ? NotificationType.system
                    : NotificationType.info;
        return NotificationItem(
          id: n['id'] as int,
          title: n['title'] as String,
          body: n['body'] as String,
          type: type,
          severity: n['severity'] as String? ?? 'info',
          timestamp: n['createdAt'] as String,
          deviceName: n['deviceName'] as String?,
          isRead: n['read'] as bool? ?? false,
        );
      }).toList()
        ..sort((a, b) =>
            DateTime.parse(b.timestamp).compareTo(DateTime.parse(a.timestamp)));
    }

    _isLoading = false;
    notifyListeners();
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void markRead(int id) {
    final idx = _all.indexWhere((n) => n.id == id);
    if (idx != -1) {
      _all[idx].isRead = true;
      notifyListeners();
    }
  }

  void markAllRead() {
    for (final n in _all) {
      n.isRead = true;
    }
    notifyListeners();
  }

  void dismiss(int id) {
    _all.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  void clearAll() {
    _all.clear();
    notifyListeners();
  }

  // ── Invitation actions ────────────────────────────────────────────────────

  Future<String?> acceptInvitation(String invitationId) async {
    try {
      await ApiClient.acceptInvitation(invitationId);
      // Mark as read and remove action buttons, but keep the tile
      _markInvitationRead(invitationId);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to accept invitation.';
    }
  }

  Future<String?> declineInvitation(String invitationId) async {
    try {
      await ApiClient.declineInvitation(invitationId);
      _markInvitationRead(invitationId);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to decline invitation.';
    }
  }

  void _markInvitationRead(String invitationId) {
    final idx = _all.indexWhere((n) => n.invitationToken == invitationId);
    if (idx != -1) {
      final n = _all[idx];
      _all[idx] = NotificationItem(
        id:                n.id,
        title:             n.title,
        body:              n.body,
        type:              n.type,
        severity:          n.severity,
        timestamp:         n.timestamp,
        deviceName:        n.deviceName,
        invitationToken:   null, // remove action buttons
        invitationOrgName: n.invitationOrgName,
        invitationRole:    n.invitationRole,
        isRead:            true,
      );
    }
  }

  NotificationItem _fromInvitation(InvitationModel inv) {
    return NotificationItem(
      id:                inv.id + 100000, // offset to avoid id clash with alerts
      title:             'Invitation to join ${inv.orgName}',
      body:              '${inv.invitedByUsername} invited you as ${inv.role}.',
      type:              NotificationType.invitation,
      severity:          'info',
      timestamp:         inv.createdAt,
      invitationToken:   inv.status == 'pending' ? inv.id.toString() : null,
      invitationOrgName: inv.orgName,
      invitationRole:    inv.role,
      isRead:            false,
    );
  }

  Future<void> _notifyNewInvitations(List<InvitationModel> invitations) async {
    final prefs  = await SharedPreferences.getInstance();
    final lastId = prefs.getInt('last_notified_invitation_id') ?? 0;
    final pending = invitations.where((i) => i.id > lastId).toList();

    int maxId = lastId;
    for (final inv in pending) {
      await NotificationService.showNotification(
        id:    inv.id + 200000,
        title: 'You\'ve been invited to ${inv.orgName}',
        body:  '${inv.invitedByUsername} invited you as ${inv.role}. Tap Notifications to respond.',
      );
      if (inv.id > maxId) maxId = inv.id;
    }
    if (maxId != lastId) {
      await prefs.setInt('last_notified_invitation_id', maxId);
    }
  }

  NotificationItem _fromAlert(AlertModel alert) {
    final type = alert.isResolved
        ? NotificationType.resolved
        : NotificationType.alert;
    return NotificationItem(
      id: alert.id,
      title: _titleForAlert(alert),
      body: alert.message,
      type: type,
      severity: alert.severity,
      timestamp: alert.triggeredAt,
      deviceName: alert.deviceName,
      isRead: alert.isAcknowledged || alert.isResolved,
    );
  }

  String _titleForAlert(AlertModel alert) {
    final type = alert.alertType.toLowerCase();
    if (type.contains('latency') || type.contains('buffer')) {
      return 'Buffering detected';
    }
    if (type.contains('packet')) {
      return 'Packet loss detected';
    }
    if (type.contains('offline')) {
      return 'Internet outage detected';
    }
    return 'Network alert';
  }

  Future<void> _notifyNewAlerts(List<AlertModel> alerts) async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getInt('last_notified_alert_id') ?? 0;

    final pending = alerts
        .where((a) => a.id > lastId && !a.isResolved)
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));

    int maxId = lastId;
    for (final alert in pending) {
      await NotificationService.showNotification(
        id: alert.id,
        title: _titleForAlert(alert),
        body: alert.message,
      );
      if (alert.id > maxId) {
        maxId = alert.id;
      }
    }

    if (maxId != lastId) {
      await prefs.setInt('last_notified_alert_id', maxId);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NotificationsScreen
// ─────────────────────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Consumer<NotificationsProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.hasError) {
            return EmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'Could Not Load Notifications',
              message: provider.errorMessage!,
              color: AppColors.primary,
              actionLabel: 'Retry',
              onAction: provider.load,
            );
          }

          return Column(
            children: [
              _buildFilterRow(provider),
              Expanded(child: _buildList(provider)),
            ],
          );
        },
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      automaticallyImplyLeading: false,
      elevation: 0,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.appBarGradientStart,
              AppColors.appBarGradientEnd,
            ],
          ),
        ),
      ),
      title: Consumer<NotificationsProvider>(
        builder: (_, provider, __) => Row(
          children: [
            const Text('Notifications', style: TextStyle(color: Colors.white)),
            if (provider.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${provider.unreadCount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Consumer<NotificationsProvider>(
          builder: (context, provider, _) => Row(
            children: [
              if (provider.unreadCount > 0)
                TextButton(
                  onPressed: () {
                    AppUtils.hapticSelect();
                    provider.markAllRead();
                  },
                  child: const Text('Mark all read',
                      style: TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onSelected: (value) {
                  if (value == 'clear') _showClearConfirm(context, provider);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Clear all',
                            style: TextStyle(color: AppColors.primary)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Filter row ─────────────────────────────────────────────────────────────

  Widget _buildFilterRow(NotificationsProvider provider) {
    const filters = [
      ('all',         'All'),
      ('unread',      'Unread'),
      ('invitations', 'Invitations'),
      ('alerts',      'Alerts'),
      ('system',      'System'),
    ];
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 46,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          scrollDirection: Axis.horizontal,
          children: filters.map((f) {
            final key = f.$1;
            final label = f.$2;
            final isSelected = provider.filter == key;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
              child: GestureDetector(
                onTap: () {
                  AppUtils.hapticSelect();
                  provider.setFilter(key);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.divider,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── List ───────────────────────────────────────────────────────────────────

  Widget _buildList(NotificationsProvider provider) {
    if (provider.filtered.isEmpty) {
      final noData = provider.all.isEmpty;
      return EmptyState(
        icon: Icons.notifications_off_rounded,
        title: noData ? 'No Notifications' : 'Nothing to Show',
        message: provider.filter == 'unread'
            ? 'You\'re all caught up. No unread notifications.'
            : noData
                ? 'Notifications will appear here when events occur.'
                : 'No notifications match this filter.',
        actionLabel: provider.filter != 'all' ? 'Show All' : null,
        onAction:
            provider.filter != 'all' ? () => provider.setFilter('all') : null,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.load,
      color: AppColors.primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 80),
        itemCount: provider.filtered.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, index) {
          final item = provider.filtered[index];
          return _NotificationTile(
            item: item,
            onTap: () => provider.markRead(item.id),
            onDismiss: () => provider.dismiss(item.id),
          );
        },
      ),
    );
  }

  // ── Confirm dialog ─────────────────────────────────────────────────────────

  void _showClearConfirm(BuildContext context, NotificationsProvider provider) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text(
          'This will remove all notifications from this list. '
          'It cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              AppUtils.haptic();
              provider.clearAll();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.offline),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _NotificationTile
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key('notif_${item.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) {
        AppUtils.hapticSelect();
        onDismiss();
      },
      background: Container(
        alignment: Alignment.centerRight,
        color: AppColors.primary,
        padding: const EdgeInsets.only(right: 20),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
            SizedBox(height: 3),
            Text('Dismiss',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      child: InkWell(
        onTap: () {
          AppUtils.hapticSelect();
          onTap();
        },
        // Unread: left blue stripe instead of tinted background.
        // A coloured background would bleed into the separator line
        // and read as an error state rather than "new".
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: item.isRead
                ? null
                : const Border(
                    left: BorderSide(color: AppColors.primary, width: 3)),
          ),
          padding: EdgeInsets.fromLTRB(item.isRead ? 16 : 13, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + unread dot
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: AppTextStyles.body.copyWith(
                              fontWeight: item.isRead
                                  ? FontWeight.w500
                                  : FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Body
                    Text(
                      item.body,
                      style: AppTextStyles.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),

                    // Invitation action buttons
                    if (item.type == NotificationType.invitation &&
                        item.invitationToken != null)
                      _InvitationActions(item: item),

                    // Footer: device + time
                    Row(
                      children: [
                        if (item.deviceName != null) ...[
                          const Icon(Icons.router_rounded,
                              size: 11, color: AppColors.textHint),
                          const SizedBox(width: 3),
                          Text(item.deviceName!, style: AppTextStyles.caption),
                          const SizedBox(width: 8),
                        ],
                        const Icon(Icons.access_time_rounded,
                            size: 11, color: AppColors.textHint),
                        const SizedBox(width: 3),
                        Text(AppUtils.timeAgo(item.timestamp),
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final Color fg = AppColors.primary;
    final Color bg = AppColors.primarySurface;
    final IconData icon = switch (item.type) {
      NotificationType.alert      => Icons.warning_rounded,
      NotificationType.resolved   => Icons.check_circle_rounded,
      NotificationType.system     => Icons.settings_rounded,
      NotificationType.invitation => Icons.mail_outline_rounded,
      NotificationType.info       => Icons.info_rounded,
    };

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: fg, size: 20),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _InvitationActions — accept / decline buttons shown on invitation tiles
// ─────────────────────────────────────────────────────────────────────────────

class _InvitationActions extends StatefulWidget {
  final NotificationItem item;
  const _InvitationActions({required this.item});

  @override
  State<_InvitationActions> createState() => _InvitationActionsState();
}

class _InvitationActionsState extends State<_InvitationActions> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Row(
        children: [
          _loading
              ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Row(
                  children: [
                    FilledButton(
                      onPressed: () => _respond(context, accept: true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize:     const Size(80, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Accept'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: () => _respond(context, accept: false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.offline,
                        side: const BorderSide(color: AppColors.offline),
                        minimumSize: const Size(80, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      child: const Text('Decline'),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Future<void> _respond(BuildContext context, {required bool accept}) async {
    setState(() => _loading = true);
    final provider = context.read<NotificationsProvider>();
    final token    = widget.item.invitationToken!;

    final err = accept
        ? await provider.acceptInvitation(token)
        : await provider.declineInvitation(token);

    if (!mounted) return;
    setState(() => _loading = false);

    if (err != null) {
      AppUtils.showSnackbar(context, err, isError: true);
    } else {
      AppUtils.showSnackbar(
        context,
        accept
            ? 'You joined ${widget.item.invitationOrgName}!'
            : 'Invitation declined.',
      );
    }
  }
}
