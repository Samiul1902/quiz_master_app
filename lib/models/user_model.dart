enum UserRole { admin, student }

class UserModel {
  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.password = '',
    required this.role,
    this.photoUrl = '',
    this.phone = '',
    this.organization = '',
    this.department = '',
    this.bio = '',
  });

  final String id;
  final String name;
  final String email;
  final String password;
  final UserRole role;
  final String photoUrl;
  final String phone;
  final String organization;
  final String department;
  final String bio;

  bool get isAdmin => role == UserRole.admin;
  bool get isStudent => role == UserRole.student;

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? password,
    UserRole? role,
    String? photoUrl,
    String? phone,
    String? organization,
    String? department,
    String? bio,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      password: password ?? this.password,
      role: role ?? this.role,
      photoUrl: photoUrl ?? this.photoUrl,
      phone: phone ?? this.phone,
      organization: organization ?? this.organization,
      department: department ?? this.department,
      bio: bio ?? this.bio,
    );
  }

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{
      'id': id,
      'name': name,
      'email': email,
      'role': role.name,
      'photoUrl': photoUrl,
      'phone': phone,
      'organization': organization,
      'department': department,
      'bio': bio,
    };

    if (password.isNotEmpty) {
      data['password'] = password;
    }

    return data;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final roleName = (json['role'] as String? ?? 'student').toLowerCase();
    final role = roleName == 'admin' ? UserRole.admin : UserRole.student;

    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      password: json['password'] as String? ?? '',
      role: role,
      photoUrl: json['photoUrl'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      organization: json['organization'] as String? ?? '',
      department: json['department'] as String? ?? '',
      bio: json['bio'] as String? ?? '',
    );
  }
}
