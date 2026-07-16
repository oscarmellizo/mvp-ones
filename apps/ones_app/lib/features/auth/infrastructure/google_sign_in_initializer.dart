import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:async';

class GoogleSignInInitializer {
  static bool _initialized = false;
  static Future<void>? _inFlight;

  static GoogleSignInAccount? _lastWebUser;
  static StreamSubscription<GoogleSignInAuthenticationEvent>? _webAuthSub;

  static GoogleSignInAccount? get lastWebUser => _lastWebUser;

  static void recordWebUser(GoogleSignInAccount user) {
    _lastWebUser = user;
  }

  static Future<void> ensureInitialized({required String? webClientId}) async {
    if (_initialized) return;
    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return;
    }

    final effectiveWebClientId =
        (webClientId != null && webClientId.trim().isNotEmpty)
            ? webClientId.trim()
            : null;

    final f = GoogleSignIn.instance.initialize(
      clientId: kIsWeb ? effectiveWebClientId : null,
      serverClientId: kIsWeb ? null : effectiveWebClientId,
    );

    _inFlight = f;
    try {
      await f;
      if (kIsWeb && _webAuthSub == null) {
        _webAuthSub = GoogleSignIn.instance.authenticationEvents.listen((e) {
          if (e is GoogleSignInAuthenticationEventSignIn) {
            _lastWebUser = e.user;
          } else if (e is GoogleSignInAuthenticationEventSignOut) {
            _lastWebUser = null;
          }
        });
      }
      _initialized = true;
    } finally {
      _inFlight = null;
    }
  }
}
