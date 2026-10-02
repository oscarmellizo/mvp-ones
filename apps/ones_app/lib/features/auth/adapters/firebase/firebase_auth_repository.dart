import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/auth_failure.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';
import 'firebase_auth_failures.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;

  /// Client OAuth web del proyecto: en Android define la audiencia del idToken de Google.
  final String? googleServerClientId;

  AuthCredential? _lastGoogleCredential;
  Future<void>? _googleInit;

  FirebaseAuthRepository({FirebaseAuth? auth, required this.googleServerClientId})
      : _auth = auth ?? FirebaseAuth.instance;

  /// SharedPreferences se borra al desinstalar; el Keychain de iOS no.
  static const _installedKey = 'ones.auth.installed_v1';

  @override
  Future<void> clearSessionIfFreshInstall() async {
    if (kIsWeb) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_installedKey) == true) return;
    await prefs.setBool(_installedKey, true);
    if (_auth.currentUser != null) await _auth.signOut();
  }

  @override
  Future<AuthUser?> currentUser() async {
    final u = _auth.currentUser;
    return u == null ? null : _toAuthUser(u);
  }

  @override
  Future<AuthUser> signInWithGoogle() => _guard(() async {
        if (kIsWeb) {
          // Sin awaits antes del popup: debe abrirse dentro del clic o el navegador lo bloquea.
          final result = await _auth.signInWithPopup(GoogleAuthProvider()..addScope('email'));
          _lastGoogleCredential = result.credential;
          return _toAuthUser(result.user!);
        }
        await _ensureGoogleInitialized();
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const AuthException(AuthFailure.unknown, 'Google no devolvió idToken');
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        final result = await _auth.signInWithCredential(credential);
        _lastGoogleCredential = credential;
        return _toAuthUser(result.user!);
      });

  @override
  Future<AuthUser> signInWithApple() => _guard(() async {
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
          throw const AuthException(AuthFailure.unsupported);
        }
        final provider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        final result = await _auth.signInWithProvider(provider);
        return _toAuthUser(result.user!);
      });

  @override
  Future<AuthUser> signInWithEmail(String email, String password) => _guard(() async {
        final result = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        return _toAuthUser(result.user!);
      });

  @override
  Future<AuthUser> registerWithEmail(String email, String password) => _guard(() async {
        final result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        await result.user!.sendEmailVerification(_actionCodeSettings());
        return _toAuthUser(result.user!);
      });

  @override
  Future<void> sendEmailVerification() => _guard(() async {
        await _auth.currentUser?.sendEmailVerification(_actionCodeSettings());
      });

  @override
  Future<AuthUser?> reloadUser() => _guard(() async {
        final current = _auth.currentUser;
        if (current == null) return null;
        await current.reload();
        final fresh = _auth.currentUser;
        return fresh == null ? null : _toAuthUser(fresh);
      });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim(), actionCodeSettings: _actionCodeSettings()));

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) => _guard(() async {
        final u = _auth.currentUser;
        if (u == null) return null;
        return u.getIdToken(forceRefresh);
      });

  @override
  Future<AuthUser> signInAgainAfterMigration() => _guard(() async {
        final credential = _lastGoogleCredential;
        if (credential == null) {
          throw const AuthException(AuthFailure.unknown, 'Sin credencial de Google para reintentar');
        }
        await _auth.signOut();
        final result = await _auth.signInWithCredential(credential);
        return _toAuthUser(result.user!);
      });

  @override
  Future<void> signOut() async {
    _lastGoogleCredential = null;
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await _ensureGoogleInitialized();
        // disconnect obliga a elegir cuenta la próxima vez (comportamiento anterior).
        await GoogleSignIn.instance.disconnect();
      } catch (_) {
        // Best-effort.
      }
    }
  }

  /// En web, el botón "Continuar" de la página de Firebase devuelve al usuario a la app
  /// (el dominio debe estar autorizado en Firebase). En móvil se usa la página por defecto.
  static ActionCodeSettings? _actionCodeSettings() =>
      kIsWeb ? ActionCodeSettings(url: Uri.base.origin) : null;

  Future<void> _ensureGoogleInitialized() {
    final serverClientId = googleServerClientId?.trim();
    return _googleInit ??= GoogleSignIn.instance.initialize(
      serverClientId: (serverClientId == null || serverClientId.isEmpty) ? null : serverClientId,
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(authFailureFromCode(e.code), e.message);
    } on GoogleSignInException catch (e) {
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled ? AuthFailure.cancelled : AuthFailure.unknown,
        e.description,
      );
    }
  }

  static AuthUser _toAuthUser(User u) {
    final providers = u.providerData.map((p) => p.providerId).toSet();
    final provider = providers.contains('google.com')
        ? 'google.com'
        : providers.contains('apple.com')
            ? 'apple.com'
            : 'password';
    return AuthUser(
      userId: u.uid,
      email: u.email,
      displayName: u.displayName,
      pictureUrl: u.photoURL,
      provider: provider,
      emailVerified: u.emailVerified,
    );
  }
}
