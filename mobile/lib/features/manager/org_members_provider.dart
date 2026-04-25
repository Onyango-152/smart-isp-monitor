import 'package:flutter/material.dart';
import '../../data/models/organisation_model.dart';
import '../../data/models/invitation_model.dart';
import '../../services/api_client.dart';

class OrgMembersProvider extends ChangeNotifier {
  final int orgId;
  OrgMembersProvider(this.orgId);

  bool    _loading = false;
  String? _error;

  List<MembershipModel> _members     = [];
  List<InvitationModel> _invitations = [];

  bool                  get isLoading    => _loading;
  String?               get error        => _error;
  List<MembershipModel> get members      => _members;
  List<InvitationModel> get invitations  => _invitations;
  List<InvitationModel> get pendingInvitations =>
      _invitations.where((i) => i.status == 'pending' && !i.isExpired).toList();

  Future<void> load() async {
    _loading = true;
    _error   = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        ApiClient.getOrgMembers(orgId),
        ApiClient.getOrgInvitations(orgId),
      ]);
      _members     = results[0] as List<MembershipModel>;
      _invitations = results[1] as List<InvitationModel>;
    } catch (e) {
      _error = 'Failed to load members.';
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> invite({required String email, required String role}) async {
    try {
      final inv = await ApiClient.sendInvitation(
          orgId: orgId, email: email, role: role);
      _invitations = [inv, ..._invitations];
      notifyListeners();
      return null; // success
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to send invitation.';
    }
  }

  Future<String?> cancelInvitation(int invitationId) async {
    try {
      await ApiClient.cancelInvitation(orgId: orgId, invitationId: invitationId);
      _invitations = _invitations
          .map((i) => i.id == invitationId ? _withStatus(i, 'cancelled') : i)
          .toList();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to cancel invitation.';
    }
  }

  Future<String?> removeMember(int userId) async {
    try {
      await ApiClient.removeOrgMember(orgId: orgId, userId: userId);
      _members = _members.where((m) => m.user != userId).toList();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to remove member.';
    }
  }

  // Rebuild an InvitationModel with a new status (models are immutable)
  InvitationModel _withStatus(InvitationModel i, String s) {
    return InvitationModel(
      id: i.id, organisation: i.organisation, orgName: i.orgName,
      invitedBy: i.invitedBy, invitedByUsername: i.invitedByUsername,
      email: i.email, role: i.role, status: s,
      isExpired: i.isExpired, createdAt: i.createdAt,
      expiresAt: i.expiresAt, respondedAt: i.respondedAt,
    );
  }
}
