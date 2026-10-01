import 'auth_user.dart';

/// Errores: los métodos lanzan [AuthException] (ver auth_failure.dart).
abstract interface class AuthRepository {
  Future<AuthUser?> currentUser();

  Future<AuthUser> signInWithGoogle();

  /// Solo iOS; en otras plataformas lanza AuthException(AuthFailure.unsupported).
  Future<AuthUser> signInWithApple();

  Future<AuthUser> signInWithEmail(String email, String password);

  /// Crea la cuenta y envía el correo de verificación.
  Future<AuthUser> registerWithEmail(String email, String password);

  Future<void> sendEmailVerification();

  /// Recarga el usuario actual (p. ej. para leer emailVerified); null si no hay sesión.
  Future<AuthUser?> reloadUser();

  Future<void> sendPasswordReset(String email);

  Future<String?> getIdToken({bool forceRefresh = false});

  /// Tras 409 ACCOUNT_MIGRATED: vuelve a iniciar sesión con la última credencial de Google.
  Future<AuthUser> signInAgainAfterMigration();

  Future<void> signOut();
}
