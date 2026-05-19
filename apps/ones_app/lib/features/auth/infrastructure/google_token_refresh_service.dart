import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'secure_storage.dart';

class GoogleTokenRefreshService {
  final String? webClientId;
  final SecureStorage secureStorage;

  GoogleSignIn? _googleSignIn;

  GoogleTokenRefreshService({
    required this.webClientId,
    required this.secureStorage,
  });

  GoogleSignIn get _signIn {
    return _googleSignIn ??= GoogleSignIn(
      clientId: kIsWeb ? webClientId : null,
      serverClientId: kIsWeb ? null : webClientId,
      scopes: const ['email', 'profile', 'openid', 'offline_access'],
    );
  }

  /// Refresh the Google ID token using the stored refresh token
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

      // If that fails, try silent sign-in with the stored refresh token
      await _signIn.signInSilently(reAuthenticate: true);
      final current = _signIn.currentUser;
      if (current != null) {
        final auth = await current.authentication;
        final newIdToken = auth.idToken;
        final newRefreshToken = auth.serverAuthCode;

        // Save the new refresh token if provided
        if (newRefreshToken != null && newRefreshToken.isNotEmpty) {
          await secureStorage.saveRefreshToken(newRefreshToken);
        }

        return newIdToken;
      }

      return null;
    } catch (e) {
      debugPrint('Failed to refresh Google ID token: $e');
      return null;
    }
  }
}
