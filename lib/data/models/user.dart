class AppUser {
  const AppUser({
    required this.id,
    required this.username,
    required this.role,
  });

  final int id;
  final String username;
  final String role;

  bool get isSupervisor => role.toLowerCase() == 'supervisor';

  factory AppUser.fromMap(Map<String, Object?> row) {
    return AppUser(
      id: (row['id'] as int?) ?? 0,
      username: (row['username'] ?? '').toString(),
      role: (row['role'] ?? 'agent').toString(),
    );
  }
}
