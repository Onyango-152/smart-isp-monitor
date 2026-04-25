import 'package:flutter/material.dart';
import '../../data/models/invitation_model.dart';
import '../../services/api_client.dart';

/// Holds pending invitations for the logged-in user.
/// Shown as a banner/notification on their home screen.
class MyInvitationsProvider extends ChangeNotifier {
  bool    _loading = false;
  List<InvitationModel> _invitations = [];

  bool                  get isLoading   => _loading;
  List<InvitationModel> get invitations => _invitations;
  bool                  get hasPending  => _invitations.isNotEmpty;

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    try {
      _invitations = await ApiClient.getMyInvitations();
    } catch (_) {
      _invitations = [];
    }
    _loading = false;
    notifyListeners();
  }

  Future<String?> accept(String token) async {
    try {
      await ApiClient.acceptInvitation(token);
      _invitations = _invitations.where((i) => i.status != 'pending').toList();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to accept invitation.';
    }
  }

  Future<String?> decline(String token) async {
    try {
      await ApiClient.declineInvitation(token);
      _invitations = _invitations.where((i) => i.status != 'pending').toList();
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Failed to decline invitation.';
    }
  }
}
