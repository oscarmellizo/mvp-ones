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

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String? ?? json['name'] as String?,
      pictureUrl: json['pictureUrl'] as String? ?? json['picture'] as String?,
    );
  }
}
