class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.firstName,
    required this.lastName,
    required this.phone,
    required this.email,
    required this.role,
  });

  final int id;
  final String username;
  final String firstName;
  final String lastName;
  final String phone;
  final String email;
  final String role;

  bool get isSupervisor => role.toLowerCase() == 'supervisor';
  String get fullName {
    final name = "${firstName.trim()} ${lastName.trim()}".trim();
    return name.isEmpty ? username : name;
  }

  factory AppUser.fromMap(Map<String, Object?> row) {
    return AppUser(
      id: (row['id'] as int?) ?? 0,
      username: (row['username'] ?? '').toString(),
      firstName: (row['first_name'] ?? '').toString(),
      lastName: (row['last_name'] ?? '').toString(),
      phone: (row['phone'] ?? '').toString(),
      email: (row['email'] ?? '').toString(),
      role: (row['role'] ?? 'agent').toString(),
    );
  }
}
