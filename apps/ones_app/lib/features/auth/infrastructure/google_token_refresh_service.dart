import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class GoogleTokenRefreshService {
  final String? webClientId;

  bool _initialized = false;

  GoogleTokenRefreshService({
    required this.webClientId,
  });

  GoogleSignIn get _signIn => GoogleSignIn.instance;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    final effectiveWebClientId =
        (webClientId != null && webClientId!.trim().isNotEmpty)
            ? webClientId
            : null;
    await _signIn.initialize(
      clientId: kIsWeb ? effectiveWebClientId : null,
      serverClientId: kIsWeb ? null : effectiveWebClientId,
    );
    _initialized = true;
  }

  /// Refresh the Google ID token using silent sign-in
  Future<String?> refreshIdToken() async {
    try {
      await _ensureInitialized();

      final current = await _signIn.attemptLightweightAuthentication();
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
