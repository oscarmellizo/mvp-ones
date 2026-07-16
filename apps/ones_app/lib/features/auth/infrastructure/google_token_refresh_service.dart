import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

import 'google_sign_in_initializer.dart';

class GoogleTokenRefreshService {
  final String? webClientId;

  Future<String?>? _refreshInFlight;

  GoogleTokenRefreshService({
    required this.webClientId,
  });

  GoogleSignIn get _signIn => GoogleSignIn.instance;

  Future<void> _ensureInitialized() async {
    await GoogleSignInInitializer.ensureInitialized(webClientId: webClientId);
  }

  Future<void> ensureInitialized() async {
    await _ensureInitialized();
  }

  /// Refresh the Google ID token using silent sign-in
  Future<String?> refreshIdToken() async {
    final existing = _refreshInFlight;
    if (existing != null) {
      return existing;
    }

    final f = _refreshIdTokenInternal();
    _refreshInFlight = f;
    try {
      return await f;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<String?> _refreshIdTokenInternal() async {
    try {
      await _ensureInitialized();

      final current = await _signIn.attemptLightweightAuthentication();
      if (current != null) {
        final auth = await current.authentication;
        return auth.idToken;
      }

      return null;
    } catch (e) {
      debugPrint('Failed to refresh Google ID token: $e');
      return null;
    }
  }
}
