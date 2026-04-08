class User {
  final String id;
  final String name;
  final String email;
  final String role;
  final bool isActive;
  final String? avatarPath;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.isActive,
    this.avatarPath,
  });

  bool get isAdmin => role == 'admin';

  /// Extracts just the filename from the full server path.
  String? get avatarFileName {
    if (avatarPath == null) return null;
    return avatarPath!.split('/').last;
  }

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'],
        name: json['name'],
        email: json['email'],
        role: json['role'],
        isActive: json['is_active'],
        avatarPath: json['avatar_path'],
      );
}
