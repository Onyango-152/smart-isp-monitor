class OrganisationModel {
  final int    id;
  final String name;
  final String slug;
  final String? description;
  final int?   createdBy;
  final String? createdByUsername;
  final bool   isActive;
  final int    membersCount;
  final String createdAt;

  const OrganisationModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.createdBy,
    this.createdByUsername,
    required this.isActive,
    required this.membersCount,
    required this.createdAt,
  });

  factory OrganisationModel.fromJson(Map<String, dynamic> json) {
    return OrganisationModel(
      id:                 json['id']                   as int,
      name:               json['name']                 as String,
      slug:               json['slug']                 as String,
      description:        json['description']          as String?,
      createdBy:          json['created_by']           as int?,
      createdByUsername:  json['created_by_username']  as String?,
      isActive:           json['is_active']            as bool,
      membersCount:       json['members_count']        as int,
      createdAt:          json['created_at']           as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id':                  id,
    'name':                name,
    'slug':                slug,
    'description':         description,
    'created_by':          createdBy,
    'created_by_username': createdByUsername,
    'is_active':           isActive,
    'members_count':       membersCount,
    'created_at':          createdAt,
  };
}

class MembershipModel {
  final int    id;
  final int    user;
  final String username;
  final String email;
  final String fullName;
  final String role;
  final String joinedAt;

  const MembershipModel({
    required this.id,
    required this.user,
    required this.username,
    required this.email,
    required this.fullName,
    required this.role,
    required this.joinedAt,
  });

  factory MembershipModel.fromJson(Map<String, dynamic> json) {
    return MembershipModel(
      id:       json['id']        as int,
      user:     json['user']      as int,
      username: json['username']  as String,
      email:    json['email']     as String,
      fullName: json['full_name'] as String,
      role:     json['role']      as String,
      joinedAt: json['joined_at'] as String,
    );
  }
}
