import 'package:flutter/foundation.dart';
import 'dart:convert';

import '../application/get_id_token_use_case.dart';
import '../application/sign_in_with_google_use_case.dart';
import '../application/sign_out_use_case.dart';
import '../domain/auth_user.dart';
import '../../users/application/ensure_user_use_case.dart';

class AuthController extends ChangeNotifier {
  final SignInWithGoogleUseCase signInWithGoogle;
  final SignOutUseCase signOut;
  final GetIdTokenUseCase getIdToken;
  final EnsureUserUseCase ensureUser;

  AuthUser? _user;
  String? _idToken;
  bool _isLoading = false;
  Object? _error;

  AuthController({
    required this.signInWithGoogle,
    required this.signOut,
    required this.getIdToken,
    required this.ensureUser,
  });

  AuthUser? get user => _user;
  String? get idToken => _idToken;
  bool get isSignedIn => _user != null;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> signIn() async {
    _setLoading(true);
    try {
      _error = null;
      _user = await signInWithGoogle.execute();
      _idToken = await getIdToken.execute();
      print(_idToken);

      final tokenForClaims = _idToken;
      if (_user != null &&
          tokenForClaims != null &&
          tokenForClaims.isNotEmpty) {
        final picture = _tryGetPictureFromIdToken(tokenForClaims);
        if ((_user?.pictureUrl == null || _user!.pictureUrl!.isEmpty) &&
            picture != null &&
            picture.isNotEmpty) {
          final u = _user!;
          _user = AuthUser(
            userId: u.userId,
            email: u.email,
            displayName: u.displayName,
            pictureUrl: picture,
          );
        }
      }

      final token = _idToken;
      if (token != null && token.isNotEmpty) {
        try {
          await ensureUser.execute(token);
        } catch (_) {
          // Intentionally ignored: user should still be signed in even if persistence fails.
        }
      }
    } catch (e) {
      _error = e;
      _user = null;
      _idToken = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      _error = null;
      await signOut.execute();
      _user = null;
      _idToken = null;
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String? _tryGetPictureFromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final jsonStr = utf8.decode(base64Url.decode(normalized));
      final map = json.decode(jsonStr);
      if (map is Map<String, dynamic>) {
        final v = map['picture'];
        if (v is String) return v;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
