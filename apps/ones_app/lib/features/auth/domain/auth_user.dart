class AuthUser {
  final String userId;
  final String? email;
  final String? displayName;
  final String? pictureUrl;

  const AuthUser({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.pictureUrl,
  });
}
