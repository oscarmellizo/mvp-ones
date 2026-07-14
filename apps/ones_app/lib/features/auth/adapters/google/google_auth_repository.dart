import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';

class GoogleAuthRepository implements AuthRepository {
  final String? webClientId;

  bool _initialized = false;

  GoogleAuthRepository({required this.webClientId});

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

  Future<String?> _getIdTokenWithRetries(
    GoogleSignInAccount account, {
    required int attempts,
    required int baseDelayMs,
  }) async {
    String? idToken;
    for (var i = 0; i < attempts && (idToken == null || idToken.isEmpty); i++) {
      final auth = await account.authentication;
      idToken = auth.idToken;
      if (idToken != null && idToken.isNotEmpty) {
        break;
      }
      await Future<void>.delayed(
        Duration(milliseconds: baseDelayMs * (i + 1)),
      );
    }
    return idToken;
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    await _ensureInitialized();

    GoogleSignInAccount? account;
    if (kIsWeb) {
      account = await _signIn.attemptLightweightAuthentication();
      if (account == null) {
        throw StateError(
          'Missing Google session on Web. Use the official Google Sign-In button rendered by the GIS SDK before calling signInWithGoogle().',
        );
      }
    } else {
      account = await _signIn.authenticate();
    }

    String? idToken = await _getIdTokenWithRetries(
      account,
      attempts: kIsWeb ? 12 : 5,
      baseDelayMs: 200,
    );

    if (kIsWeb && (idToken == null || idToken.isEmpty)) {
      final current = await _signIn.attemptLightweightAuthentication();
      if (current != null) {
        idToken = await _getIdTokenWithRetries(
          current,
          attempts: 12,
          baseDelayMs: 140,
        );
      }
    }

    if (idToken == null || idToken.isEmpty) {
      throw StateError(
        'Missing Google idToken (GOOGLE_WEB_CLIENT_ID=${webClientId ?? 'null'}). '
        'Ensure you are using the OAuth Web client ID and that it is provided via --dart-define=GOOGLE_WEB_CLIENT_ID=... '
        '(Android uses serverClientId; Web uses clientId).',
      );
    }

    return AuthUser(
      userId: account.id,
      email: account.email,
      displayName: account.displayName,
      pictureUrl: account.photoUrl,
    );
  }

  @override
  Future<void> signOut() async {
    try {
      await _ensureInitialized();
      await _signIn.signOut();
    } catch (_) {
      // Best-effort: ignore errors on sign-out.
    }
  }

  @override
  Future<String?> getIdToken() async {
    await _ensureInitialized();
    final account = await _signIn.attemptLightweightAuthentication();
    if (account == null) return null;
    final auth = await account.authentication;
    return auth.idToken;
  }
}
