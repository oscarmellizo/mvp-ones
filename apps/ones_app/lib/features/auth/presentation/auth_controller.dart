import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/get_id_token_use_case.dart';
import '../application/sign_in_with_google_use_case.dart';
import '../application/sign_out_use_case.dart';
import '../domain/auth_user.dart';
import '../../users/application/ensure_user_use_case.dart';
import '../../users/domain/users_repository.dart';
import '../../admin/application/get_admin_me_use_case.dart';
import '../infrastructure/google_token_refresh_service.dart';

enum AuthNextStep {
  signedIn,
  needsRegistration,
  failed,
}

class AuthController extends ChangeNotifier {
  final SignInWithGoogleUseCase signInWithGoogle;
  final SignOutUseCase signOut;
  final GetIdTokenUseCase getIdToken;
  final EnsureUserUseCase ensureUser;
  final GetUserPreferencesUseCase getUserPreferences;
  final UpdateUserPreferencesUseCase updateUserPreferences;
  final LookupUserByEmailUseCase lookupUserByEmailUseCase;
  final GetAdminMeUseCase getAdminMe;
  final GoogleTokenRefreshService tokenRefreshService;

  AuthUser? _user;
  String? _idToken;
  String? _preferredName;
  String? _languagePreference;
  bool _termsAccepted = false;
  bool _isAdmin = false;
  bool _isRegistered = false;
  bool _isLoading = false;
  Object? _error;

  SharedPreferences? _prefs;
  Future<void>? _restoreInFlight;

  static const String _lastInteractiveSignInAtKey =
      'ones.auth.last_interactive_signin_at_v1';
  static const Duration _interactiveSessionTtl = Duration(hours: 24);

  AuthController({
    required this.signInWithGoogle,
    required this.signOut,
    required this.getIdToken,
    required this.ensureUser,
    required this.getUserPreferences,
    required this.updateUserPreferences,
    required this.lookupUserByEmailUseCase,
    required this.getAdminMe,
    required this.tokenRefreshService,
  });

  AuthUser? get user => _user;
  String? get idToken => _idToken;
  String? get preferredName => _preferredName;
  String? get languagePreference => _languagePreference;
  bool get termsAccepted => _termsAccepted;
  bool get isAdmin => _isAdmin;
  bool get isSignedIn => _user != null;
  bool get isRegistered => _isRegistered;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> signIn() async {
    await signInExisting();
  }

  Future<void> warmUpGoogleSignIn() async {
    try {
      await tokenRefreshService.ensureInitialized();
    } catch (_) {}
  }

  Future<void> restoreSessionIfPossible() async {
    final existing = _restoreInFlight;
    if (existing != null) {
      await existing;
      return;
    }

    final f = _restoreSessionInternal();
    _restoreInFlight = f;
    try {
      await f;
    } finally {
      _restoreInFlight = null;
    }
  }

  Future<void> _restoreSessionInternal() async {
    _prefs ??= await SharedPreferences.getInstance();

    final last = _prefs!.getInt(_lastInteractiveSignInAtKey);
    if (last == null) {
      return;
    }

    final ageMs = DateTime.now().millisecondsSinceEpoch - last;
    if (ageMs > _interactiveSessionTtl.inMilliseconds) {
      await _prefs!.remove(_lastInteractiveSignInAtKey);
      return;
    }

    _setLoading(true);
    try {
      _error = null;
      final token = await tokenRefreshService.refreshIdToken();
      if (token == null || token.isEmpty) {
        return;
      }

      _idToken = token;
      _user = _userFromIdToken(token);

      try {
        final prefs = await getUserPreferences.execute(token);
        _preferredName = prefs?.preferredName;
        final lp = prefs?.languagePreference;
        _languagePreference = (lp != null && lp.trim().isNotEmpty)
            ? lp.trim().toLowerCase()
            : 'es';
        _termsAccepted = prefs?.termsAccepted ?? false;
        _isAdmin = await _safeLoadIsAdmin(token);
        _isRegistered = true;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          _user = null;
          _idToken = null;
          _preferredName = null;
          _languagePreference = null;
          _termsAccepted = false;
          _isAdmin = false;
          _isRegistered = false;
          _prefs ??= await SharedPreferences.getInstance();
          await _prefs!.remove(_lastInteractiveSignInAtKey);
          return;
        }
        rethrow;
      }
    } catch (e) {
      _error = _formatDioOrRawError(e);
      _user = null;
      _idToken = null;
      _preferredName = null;
      _languagePreference = null;
      _termsAccepted = false;
      _isAdmin = false;
      _isRegistered = false;
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthNextStep> signInExisting() async {
    _setLoading(true);
    try {
      _error = null;
      _isRegistered = false;

      _user = await signInWithGoogle.execute();
      _idToken = await getIdToken.execute();
      // ignore: avoid_print
      print('[AuthController] signInExisting userId=${_user?.userId} email=${_user?.email}');

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
      if (token == null || token.isEmpty) {
        throw StateError('Missing idToken');
      }

      try {
        final prefs = await getUserPreferences.execute(token);
        _preferredName = prefs?.preferredName;
        final lp = prefs?.languagePreference;
        _languagePreference = (lp != null && lp.trim().isNotEmpty)
            ? lp.trim().toLowerCase()
            : 'es';
        _termsAccepted = prefs?.termsAccepted ?? false;
        _isAdmin = await _safeLoadIsAdmin(token);
        _isRegistered = true;
        await _persistInteractiveSignInTimestamp();
        return AuthNextStep.signedIn;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          _preferredName = null;
          _languagePreference = null;
          _termsAccepted = false;
          _isAdmin = false;
          _isRegistered = false;
          return AuthNextStep.needsRegistration;
        }
        rethrow;
      }
    } catch (e) {
      // ignore: avoid_print
      print('[AuthController] signInExisting FAILED: $e');
      _error = _formatDioOrRawError(e);
      _user = null;
      _idToken = null;
      _preferredName = null;
      _languagePreference = null;
      _termsAccepted = false;
      _isAdmin = false;
      _isRegistered = false;
      return AuthNextStep.failed;
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthNextStep> beginRegistration() async {
    _setLoading(true);
    try {
      _error = null;
      _isRegistered = false;
      _user = await signInWithGoogle.execute();
      _idToken = await getIdToken.execute();

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
      if (token == null || token.isEmpty) {
        throw StateError('Missing idToken');
      }

      await _persistInteractiveSignInTimestamp();

      return AuthNextStep.needsRegistration;
    } catch (e) {
      _error = _formatDioOrRawError(e);
      _user = null;
      _idToken = null;
      _preferredName = null;
      _languagePreference = null;
      _termsAccepted = false;
      _isAdmin = false;
      _isRegistered = false;
      return AuthNextStep.failed;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> completeRegistration(
    String preferredName, {
    bool termsAccepted = false,
  }) async {
    final token = _idToken;
    if (token == null || token.isEmpty) {
      throw StateError('Missing idToken');
    }

    final trimmed = preferredName.trim();
    if (trimmed.isEmpty) {
      throw StateError('Preferred name is required');
    }

    _setLoading(true);
    try {
      _error = null;
      await ensureUser.execute(token);
      final lang = _languagePreference ?? 'es';
      final updated =
          await updateUserPreferences.execute(token, trimmed, lang, termsAccepted);
      _preferredName = (updated?.preferredName ?? trimmed).trim();
      _languagePreference =
          (updated?.languagePreference ?? lang).trim().toLowerCase();
      _termsAccepted = updated?.termsAccepted ?? termsAccepted;
      _isAdmin = await _safeLoadIsAdmin(token);
      _isRegistered = true;
      await _persistInteractiveSignInTimestamp();
    } catch (e) {
      _error = _formatDioOrRawError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> savePreferredName(String value) async {
    await savePreferences(preferredName: value, languagePreference: null);
  }

  Future<void> savePreferences({
    required String preferredName,
    required String? languagePreference,
  }) async {
    final token = _idToken;
    if (token == null || token.isEmpty) return;

    final pn = preferredName.trim();
    if (pn.isEmpty) {
      throw StateError('Preferred name is required');
    }

    final lang = (languagePreference ?? _languagePreference ?? 'es').trim();
    if (lang.isEmpty) {
      throw StateError('Language preference is required');
    }

    _setLoading(true);
    try {
      _error = null;
      final updated =
          await updateUserPreferences.execute(token, pn, lang, _termsAccepted);
      _preferredName = updated?.preferredName ?? pn;
      _languagePreference =
          (updated?.languagePreference ?? lang).trim().toLowerCase();
      _termsAccepted = updated?.termsAccepted ?? _termsAccepted;
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserLookup?> lookupUserByEmail(String email) async {
    final token = _idToken;
    if (token == null || token.isEmpty) return null;
    return lookupUserByEmailUseCase.execute(token, email);
  }

  Future<String?> refreshIdToken() async {
    try {
      final token = await tokenRefreshService.refreshIdToken();
      if (token != null && token.isNotEmpty) {
        _idToken = token;
        if (_isRegistered) {
          _isAdmin = await _safeLoadIsAdmin(token);
        }
        notifyListeners();
        return token;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> clearGoogleSession() async {
    try {
      await signOut.execute();
    } catch (_) {}
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      _error = null;
      await signOut.execute();
      _user = null;
      _idToken = null;
      _preferredName = null;
      _isAdmin = false;
      _isRegistered = false;
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_lastInteractiveSignInAtKey);
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _persistInteractiveSignInTimestamp() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.setInt(
      _lastInteractiveSignInAtKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  Object _formatDioOrRawError(Object e) {
    if (e is DioException) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map) {
        final code = data['code'] ?? data['error'];
        final msg = data['message'];
        return 'HTTP $status ${code ?? ''} ${msg ?? ''}'.trim();
      } else if (data is String && data.trim().isNotEmpty) {
        return 'HTTP $status ${data.trim()}'.trim();
      } else {
        return 'HTTP $status ${e.message ?? 'Request failed'}'.trim();
      }
    }
    return e;
  }

  Future<bool> _safeLoadIsAdmin(String token) async {
    try {
      return await getAdminMe.execute(token);
    } catch (_) {
      return false;
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

  AuthUser? _userFromIdToken(String idToken) {
    try {
      final parts = idToken.split('.');
      if (parts.length < 2) return null;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final jsonStr = utf8.decode(base64Url.decode(normalized));
      final decoded = json.decode(jsonStr);

      if (decoded is! Map) return null;

      final sub = decoded['sub']?.toString();
      final email = decoded['email']?.toString();
      final name = decoded['name']?.toString();
      final picture = decoded['picture']?.toString();

      if (sub == null || sub.isEmpty) return null;

      return AuthUser(
        userId: sub,
        email: email,
        displayName: name,
        pictureUrl: picture,
      );
    } catch (_) {
      return null;
    }
  }
}
