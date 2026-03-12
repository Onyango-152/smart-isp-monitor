/// UserModel represents a logged-in user of the system.
/// The role field determines which screens and features they can access.
class UserModel {
  final int    id;
  final String email;
  final String username;
  final String role;
  final bool   isActive;
  final String? fcmToken;
  final String? dateJoined;
  final String? lastLogin;

  const UserModel({
    required this.id,
    required this.email,
    required this.username,
    required this.role,
    required this.isActive,
    this.fcmToken,
    this.dateJoined,
    this.lastLogin,
  });

  /// fromJson creates a UserModel from a JSON map.
  /// This is called when we receive user data from the Django API.
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:         json['id']         as int,
      email:      json['email']      as String,
      username:   json['username']   as String,
      role:       json['role']       as String,
      isActive:   json['is_active']  as bool,
      fcmToken:   json['fcm_token']  as String?,
      dateJoined: json['date_joined'] as String?,
      lastLogin:  json['last_login']  as String?,
    );
  }

  /// toJson converts the UserModel back to a map.
  /// Used when we need to store the user object locally.
  Map<String, dynamic> toJson() {
    return {
      'id':         id,
      'email':      email,
      'username':   username,
      'role':       role,
      'is_active':  isActive,
      'fcm_token':  fcmToken,
      'date_joined': dateJoined,
      'last_login':  lastLogin,
    };
  }

  /// copyWith creates a new UserModel with some fields changed.
  /// This is the correct way to update a model in Flutter —
  /// models should be immutable so instead of changing fields
  /// directly we create a new instance with updated values.
  UserModel copyWith({
    int?    id,
    String? email,
    String? username,
    String? role,
    bool?   isActive,
    String? fcmToken,
    String? dateJoined,
    String? lastLogin,
  }) {
    return UserModel(
      id:         id         ?? this.id,
      email:      email      ?? this.email,
      username:   username   ?? this.username,
      role:       role       ?? this.role,
      isActive:   isActive   ?? this.isActive,
      fcmToken:   fcmToken   ?? this.fcmToken,
      dateJoined: dateJoined ?? this.dateJoined,
      lastLogin:  lastLogin  ?? this.lastLogin,
    );
  }
}