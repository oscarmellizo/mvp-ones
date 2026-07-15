import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';
import '../../infrastructure/google_sign_in_initializer.dart';

class GoogleAuthRepository implements AuthRepository {
  final String? webClientId;

  GoogleAuthRepository({required this.webClientId});

  GoogleSignIn get _signIn => GoogleSignIn.instance;

  Future<void> _ensureInitialized() async {
    await GoogleSignInInitializer.ensureInitialized(webClientId: webClientId);
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
      account = GoogleSignInInitializer.lastWebUser;
      // Web: interactive sign-in is driven by the GIS button; when this method is
      // called we expect a session to exist. Allow a short retry window to absorb
      // race conditions right after the popup completes.
      if (account == null) {
        for (var i = 0; i < 12; i++) {
          account = await _signIn.attemptLightweightAuthentication();
          if (account != null) break;
          await Future<void>.delayed(Duration(milliseconds: 120 * (i + 1)));
        }
      }
      if (account == null) {
        throw StateError(
          'Missing Google session on Web. Use the official Google Sign-In button rendered by the GIS SDK before calling signInWithGoogle().',
        );
      }
    } else {
      // Mobile: avoid repeated interactive prompts by attempting a lightweight
      // (silent) authentication first.
      account = await _signIn.attemptLightweightAuthentication();
      account ??= await _signIn.authenticate();
    }

    String? idToken = await _getIdTokenWithRetries(
      account,
      attempts: kIsWeb ? 12 : 5,
      baseDelayMs: 200,
    );

    // On Web, account.authentication.idToken may arrive slightly delayed.

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
      // On mobile, disconnect clears the granted scopes and forces the account
      // chooser next time. On web it can be disruptive, so keep signOut.
      if (kIsWeb) {
        await _signIn.signOut();
      } else {
        await _signIn.disconnect();
      }
    } catch (_) {
      // Best-effort: ignore errors on sign-out.
    }
  }

  @override
  Future<String?> getIdToken() async {
    await _ensureInitialized();

    GoogleSignInAccount? account;
    if (kIsWeb) {
      account = GoogleSignInInitializer.lastWebUser;
      account ??= await _signIn.attemptLightweightAuthentication();
    } else {
      account = await _signIn.attemptLightweightAuthentication();
    }

    if (account == null) return null;

    final token = await _getIdTokenWithRetries(
      account,
      attempts: kIsWeb ? 16 : 6,
      baseDelayMs: 180,
    );

    return (token != null && token.isNotEmpty) ? token : null;
  }
}
