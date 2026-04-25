import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../data/models/organisation_model.dart';
import '../../data/models/invitation_model.dart';
import 'org_members_provider.dart';

class OrgMembersScreen extends StatelessWidget {
  final int    orgId;
  final String orgName;

  const OrgMembersScreen({
    super.key,
    required this.orgId,
    required this.orgName,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrgMembersProvider(orgId)..load(),
      child: _OrgMembersView(orgName: orgName),
    );
  }
}

class _OrgMembersView extends StatelessWidget {
  final String orgName;
  const _OrgMembersView({required this.orgName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      floatingActionButton: _InviteFab(orgName: orgName),
      body: Consumer<OrgMembersProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 48, color: AppColors.offline),
                  const SizedBox(height: 12),
                  Text(provider.error!, style: AppTextStyles.bodySmall),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: provider.load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: provider.load,
            color: AppColors.primary,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                _SectionHeader(
                  icon:  Icons.people_rounded,
                  title: 'Members',
                  count: provider.members.length,
                ),
                if (provider.members.isEmpty)
                  const _EmptyHint(text: 'No members yet. Invite someone below.')
                else
                  ...provider.members.map((m) => _MemberTile(member: m)),

                const SizedBox(height: 8),
                _SectionHeader(
                  icon:  Icons.mail_outline_rounded,
                  title: 'Pending Invitations',
                  count: provider.pendingInvitations.length,
                ),
                if (provider.pendingInvitations.isEmpty)
                  const _EmptyHint(text: 'No pending invitations.')
                else
                  ...provider.pendingInvitations
                      .map((i) => _InvitationTile(invitation: i)),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
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
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Members', style: TextStyle(color: Colors.white, fontSize: 17)),
          Text(orgName,
              style: TextStyle(
                  color: Colors.white.withOpacity(0.75), fontSize: 12)),
        ],
      ),
      actions: [
        Consumer<OrgMembersProvider>(
          builder: (_, p, __) => IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: p.isLoading ? null : p.load,
          ),
        ),
      ],
    );
  }
}

// ── Member tile ───────────────────────────────────────────────────────────────

class _MemberTile extends StatelessWidget {
  final MembershipModel member;
  const _MemberTile({required this.member});

  @override
  Widget build(BuildContext context) {
    final roleColor = _roleColor(member.role);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.divider, width: 0.5),
          boxShadow:    AppShadows.card,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: CircleAvatar(
            backgroundColor: AppColors.primarySurface,
            child: Text(
              _initials(member.fullName.isNotEmpty ? member.fullName : member.username),
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            member.fullName.isNotEmpty ? member.fullName : member.username,
            style: AppTextStyles.heading3,
          ),
          subtitle: Text(member.email, style: AppTextStyles.bodySmall),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:        roleColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  member.role[0].toUpperCase() + member.role.substring(1),
                  style: TextStyle(
                      color: roleColor, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 4),
              // Remove button
              IconButton(
                icon: const Icon(Icons.person_remove_rounded,
                    size: 20, color: AppColors.offline),
                tooltip: 'Remove member',
                onPressed: () => _confirmRemove(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Member'),
        content: Text(
            'Remove ${member.fullName.isNotEmpty ? member.fullName : member.username} from this organisation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await context
                  .read<OrgMembersProvider>()
                  .removeMember(member.user);
              if (context.mounted) {
                if (err != null) {
                  AppUtils.showSnackbar(context, err, isError: true);
                } else {
                  AppUtils.showSnackbar(context, 'Member removed.');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.offline),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'manager':    return AppColors.primary;
      case 'technician': return AppColors.maintenance;
      default:           return AppColors.online;
    }
  }
}

// ── Invitation tile ───────────────────────────────────────────────────────────

class _InvitationTile extends StatelessWidget {
  final InvitationModel invitation;
  const _InvitationTile({required this.invitation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Container(
        decoration: BoxDecoration(
          color:        Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border:       Border.all(color: AppColors.divider, width: 0.5),
          boxShadow:    AppShadows.card,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color:        AppColors.degraded.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.mail_outline_rounded,
                color: AppColors.degraded, size: 20),
          ),
          title: Text(invitation.email, style: AppTextStyles.heading3),
          subtitle: Text(
            'Invited as ${invitation.role} · expires ${_formatDate(invitation.expiresAt)}',
            style: AppTextStyles.caption,
          ),
          trailing: IconButton(
            icon: const Icon(Icons.cancel_outlined,
                size: 20, color: AppColors.offline),
            tooltip: 'Cancel invitation',
            onPressed: () => _confirmCancel(context),
          ),
        ),
      ),
    );
  }

  void _confirmCancel(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Invitation'),
        content: Text('Cancel the invitation sent to ${invitation.email}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final err = await context
                  .read<OrgMembersProvider>()
                  .cancelInvitation(invitation.id);
              if (context.mounted) {
                if (err != null) {
                  AppUtils.showSnackbar(context, err, isError: true);
                } else {
                  AppUtils.showSnackbar(context, 'Invitation cancelled.');
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.offline),
            child: const Text('Cancel Invite'),
          ),
        ],
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

// ── Invite FAB ────────────────────────────────────────────────────────────────

class _InviteFab extends StatelessWidget {
  final String orgName;
  const _InviteFab({required this.orgName});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      icon:  const Icon(Icons.person_add_rounded, color: Colors.white),
      label: const Text('Invite',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      onPressed: () => _showInviteSheet(context),
    );
  }

  void _showInviteSheet(BuildContext context) {
    final provider = context.read<OrgMembersProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: _InviteSheet(orgName: orgName),
      ),
    );
  }
}

class _InviteSheet extends StatefulWidget {
  final String orgName;
  const _InviteSheet({required this.orgName});

  @override
  State<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends State<_InviteSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  String  _role    = 'technician';
  bool    _sending = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Text('Invite to ${widget.orgName}',
                style: AppTextStyles.heading1),
            const SizedBox(height: 4),
            Text('They\'ll receive an email with a link to join.',
                style: AppTextStyles.bodySmall),
            const SizedBox(height: 24),

            // Email
            TextFormField(
              controller:   _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText:  'Email address',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Role
            DropdownButtonFormField<String>(
              value: _role,
              decoration: InputDecoration(
                labelText:  'Role',
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              items: const [
                DropdownMenuItem(value: 'technician', child: Text('Technician')),
                DropdownMenuItem(value: 'customer',   child: Text('Customer')),
                DropdownMenuItem(value: 'manager',    child: Text('Manager')),
              ],
              onChanged: (v) => setState(() => _role = v!),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!,
                  style: const TextStyle(color: AppColors.offline, fontSize: 13)),
            ],

            const SizedBox(height: 24),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 18, height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(_sending ? 'Sending…' : 'Send Invitation'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _sending = true; _error = null; });

    final err = await context.read<OrgMembersProvider>().invite(
      email: _emailCtrl.text.trim(),
      role:  _role,
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.pop(context);
      AppUtils.showSnackbar(context, 'Invitation sent to ${_emailCtrl.text.trim()}');
    }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String   title;
  final int      count;
  const _SectionHeader({required this.icon, required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(title, style: AppTextStyles.heading2),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color:        AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count',
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(text,
          style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textHint)),
    );
  }
}
