import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleTokenRefreshService {
  final String? webClientId;

  GoogleSignIn? _googleSignIn;

  GoogleTokenRefreshService({
    required this.webClientId,
  });

  GoogleSignIn get _signIn {
    return _googleSignIn ??= GoogleSignIn(
      clientId: kIsWeb ? webClientId : null,
      serverClientId: kIsWeb ? null : webClientId,
      scopes: const ['email', 'profile', 'openid'],
    );
  }

  /// Refresh the Google ID token using silent sign-in
  Future<String?> refreshIdToken() async {
    try {
      // First, try to get a fresh ID token from the current session
      final account = _signIn.currentUser;
      if (account != null) {
        final auth = await account.authentication;
        if (auth.idToken != null && auth.idToken!.isNotEmpty) {
          return auth.idToken;
        }
      }

      // If that fails, try silent sign-in to obtain a new ID token
      await _signIn.signInSilently(reAuthenticate: false);
      final current = _signIn.currentUser;
      if (current != null) {
        final auth = await current.authentication;
        final newIdToken = auth.idToken;
        return newIdToken;
      }

      return null;
    } catch (e) {
      debugPrint('Failed to refresh Google ID token: $e');
      return null;
    }
  }
}
