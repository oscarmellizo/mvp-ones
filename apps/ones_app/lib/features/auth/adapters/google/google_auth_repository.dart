import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';

class GoogleAuthRepository implements AuthRepository {
  final String? webClientId;

  GoogleSignIn? _googleSignIn;

  GoogleAuthRepository({required this.webClientId});

  GoogleSignIn get _signIn {
    return _googleSignIn ??= GoogleSignIn(
      clientId: webClientId,
      scopes: const ['email', 'profile', 'openid'],
    );
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    final account = await _signIn.signIn();
    if (account == null) {
      throw StateError('Sign-in aborted');
    }

    final auth = await account.authentication;
    final idToken = auth.idToken;
    if (idToken == null || idToken.isEmpty) {
      throw StateError('Missing Google idToken');
    }

    return AuthUser(
      userId: account.id,
      email: account.email,
      displayName: account.displayName,
    );
  }

  @override
  Future<void> signOut() async {
    await _signIn.signOut();
  }

  @override
  Future<String?> getIdToken() async {
    final account = _signIn.currentUser;
    if (account == null) {
      return null;
    }
    final auth = await account.authentication;
    return auth.idToken;
  }
}
