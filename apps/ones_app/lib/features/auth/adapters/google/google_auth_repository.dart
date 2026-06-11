import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';

class GoogleAuthRepository implements AuthRepository {
  final String? webClientId;

  GoogleSignIn? _googleSignIn;

  GoogleAuthRepository({required this.webClientId});

  GoogleSignIn get _signIn {
    final effectiveWebClientId =
        (webClientId != null && webClientId!.trim().isNotEmpty)
            ? webClientId
            : null;
    return _googleSignIn ??= GoogleSignIn(
      clientId: kIsWeb ? effectiveWebClientId : null,
      serverClientId: kIsWeb ? null : effectiveWebClientId,
      scopes: const ['email', 'profile', 'openid'],
    );
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
    GoogleSignInAccount? account = await _signIn.signIn();
    if (account == null) {
      throw StateError('Sign-in aborted');
    }

    String? idToken = await _getIdTokenWithRetries(
      account,
      attempts: kIsWeb ? 8 : 1,
      baseDelayMs: 120,
    );

    if (kIsWeb && (idToken == null || idToken.isEmpty)) {
      for (var i = 0; i < 2 && (idToken == null || idToken.isEmpty); i++) {
        await _signIn.signOut();
        await Future<void>.delayed(Duration(milliseconds: 150 * (i + 1)));
        account = await _signIn.signIn();
        if (account == null) {
          break;
        }
        idToken = await _getIdTokenWithRetries(
          account,
          attempts: 8,
          baseDelayMs: 120,
        );
      }
    }

    if (idToken == null || idToken.isEmpty) {
      for (var i = 0; i < 5 && (idToken == null || idToken.isEmpty); i++) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (i + 1)));
        await _signIn.signInSilently(reAuthenticate: true);
        final current = _signIn.currentUser;
        if (current != null) {
          final auth = await current.authentication;
          idToken = auth.idToken;
        }
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
    if (kIsWeb) {
      await _signIn.signOut();
      return;
    }

    try {
      await _signIn.disconnect();
      return;
    } catch (_) {
      // Best-effort: if disconnect fails (e.g. not connected), fall back to signOut.
    }
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
