class UserModel {
  final int id;
  final String? email;
  final String firstName;
  final String? lastName;
  final String? phone;
  final int? roleId;
  final String? lastSeen;
  final String? prefLanguage;
  final RoleModel? role;

  const UserModel({
    required this.id,
    this.email,
    required this.firstName,
    this.lastName,
    this.phone,
    this.roleId,
    this.lastSeen,
    this.prefLanguage,
    this.role,
  });

  String get fullName => '$firstName ${lastName ?? ''}'.trim();

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      email: json['email'] as String?,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String?,
      phone: json['phone'] as String?,
      roleId: json['role_id'] as int?,
      lastSeen: json['last_seen'] as String?,
      prefLanguage: json['pref_language'] as String?,
      role: json['role'] != null
          ? RoleModel.fromJson(json['role'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'role_id': roleId,
      'last_seen': lastSeen,
      'pref_language': prefLanguage,
      'role': role?.toJson(),
    };
  }
}

class RoleModel {
  final int roleId;
  final String? roleSystem;
  final String? roleType;
  final String roleName;

  const RoleModel({
    required this.roleId,
    this.roleSystem,
    this.roleType,
    required this.roleName,
  });

  factory RoleModel.fromJson(Map<String, dynamic> json) {
    return RoleModel(
      roleId: json['role_id'] as int,
      roleSystem: json['role_system'] as String?,
      roleType: json['role_type'] as String?,
      roleName: json['role_name'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role_id': roleId,
      'role_system': roleSystem,
      'role_type': roleType,
      'role_name': roleName,
    };
  }
}
