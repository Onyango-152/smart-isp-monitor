class InvitationModel {
  final int     id;
  final int     organisation;
  final String  orgName;
  final int     invitedBy;
  final String  invitedByUsername;
  final String  email;
  final String  role;
  final String  status;
  final bool    isExpired;
  final String  createdAt;
  final String  expiresAt;
  final String? respondedAt;

  const InvitationModel({
    required this.id,
    required this.organisation,
    required this.orgName,
    required this.invitedBy,
    required this.invitedByUsername,
    required this.email,
    required this.role,
    required this.status,
    required this.isExpired,
    required this.createdAt,
    required this.expiresAt,
    this.respondedAt,
  });

  factory InvitationModel.fromJson(Map<String, dynamic> json) {
    return InvitationModel(
      id:                 json['id']                   as int,
      organisation:       json['organisation']         as int,
      orgName:            json['org_name']             as String,
      invitedBy:          json['invited_by']           as int,
      invitedByUsername:  json['invited_by_username']  as String,
      email:              json['email']                as String,
      role:               json['role']                 as String,
      status:             json['status']               as String,
      isExpired:          json['is_expired']           as bool,
      createdAt:          json['created_at']           as String,
      expiresAt:          json['expires_at']           as String,
      respondedAt:        json['responded_at']         as String?,
    );
  }
}
