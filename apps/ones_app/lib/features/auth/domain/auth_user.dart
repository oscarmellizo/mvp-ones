class AuthUser {
  final String userId;
  final String? email;
  final String? displayName;

  const AuthUser({
    required this.userId,
    required this.email,
    required this.displayName,
  });
}
