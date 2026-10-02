class AuthUser {
  final String userId;
  final String? email;
  final String? displayName;
  final String? pictureUrl;

  /// Proveedor con el que se autenticó: google.com, apple.com o password.
  final String provider;
  final bool emailVerified;

  const AuthUser({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.pictureUrl,
    this.provider = 'google.com',
    this.emailVerified = true,
  });

  /// Las cuentas de correo/contraseña deben verificar el correo antes de usar el API.
  bool get needsEmailVerification => provider == 'password' && !emailVerified;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String? ?? json['name'] as String?,
      pictureUrl: json['pictureUrl'] as String? ?? json['picture'] as String?,
    );
  }
}
