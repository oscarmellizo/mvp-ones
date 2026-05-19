import 'auth_user.dart';

abstract interface class AuthRepository {
  Future<AuthUser> signInWithGoogle();

  Future<void> signOut();

  Future<String?> getIdToken();
}
