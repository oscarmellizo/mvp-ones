import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:dio/dio.dart';

import '../application/get_id_token_use_case.dart';
import '../application/sign_in_with_google_use_case.dart';
import '../application/sign_out_use_case.dart';
import '../domain/auth_user.dart';
import '../../users/application/ensure_user_use_case.dart';
import '../../users/domain/users_repository.dart';
import '../../admin/application/get_admin_me_use_case.dart';
import '../infrastructure/device_id_service.dart';
import '../infrastructure/ones_auth_api.dart';
import '../infrastructure/session_storage.dart';

class AuthController extends ChangeNotifier {
  final SignInWithGoogleUseCase signInWithGoogle;
  final SignOutUseCase signOut;
  final GetIdTokenUseCase getIdToken;
  final EnsureUserUseCase ensureUser;
  final GetPreferredNameUseCase getPreferredName;
  final UpdatePreferredNameUseCase updatePreferredName;
  final LookupUserByEmailUseCase lookupUserByEmailUseCase;
  final GetAdminMeUseCase getAdminMe;

  final OnesAuthApi onesAuthApi;
  final DeviceIdService deviceIdService;
  final SessionStorage sessionStorage;

  AuthUser? _user;
  String? _idToken;
  String? _refreshToken;
  String? _preferredName;
  bool _isAdmin = false;
  bool _isLoading = false;
  Object? _error;

  Future<String?>? _refreshInFlight;

  int _sessionExpiredSeq = 0;

  AuthController({
    required this.signInWithGoogle,
    required this.signOut,
    required this.getIdToken,
    required this.ensureUser,
    required this.getPreferredName,
    required this.updatePreferredName,
    required this.lookupUserByEmailUseCase,
    required this.getAdminMe,
    required this.onesAuthApi,
    required this.deviceIdService,
    required this.sessionStorage,
  });

  AuthUser? get user => _user;
  String? get idToken => _idToken;
  String? get preferredName => _preferredName;
  bool get isAdmin => _isAdmin;
  bool get isSignedIn => _idToken != null && _idToken!.isNotEmpty;
  bool get isLoading => _isLoading;
  Object? get error => _error;
  int get sessionExpiredSeq => _sessionExpiredSeq;

  Future<void> loadFromStorage() async {
    final access = await sessionStorage.readAccessToken();
    final refresh = await sessionStorage.readRefreshToken();

    if (access != null && access.isNotEmpty) {
      _idToken = access;
      _refreshToken = refresh;
      _isAdmin = await _safeLoadIsAdmin(access);
      notifyListeners();
    }
  }

  Future<void> signIn() async {
    _setLoading(true);
    try {
      _error = null;
      _user = await signInWithGoogle.execute();
      final googleIdToken = await getIdToken.execute();

      if (googleIdToken == null || googleIdToken.isEmpty) {
        throw StateError('Missing Google idToken');
      }

      final deviceId = await deviceIdService.getOrCreate();
      final session = await onesAuthApi.createSession(
        googleIdToken: googleIdToken,
        deviceId: deviceId,
      );

      _idToken = session.accessToken;
      _refreshToken = session.refreshToken;
      await sessionStorage.writeTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );

      final tokenForClaims = googleIdToken;
      if (_user != null && tokenForClaims.isNotEmpty) {
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
          _preferredName = await getPreferredName.execute(token);
          _isAdmin = await _safeLoadIsAdmin(token);
        } catch (_) {
          // Intentionally ignored: user should still be signed in even if persistence fails.
        }
      }
    } catch (e) {
      if (e is DioException) {
        final status = e.response?.statusCode;
        final data = e.response?.data;
        if (data is Map) {
          final code = data['code'];
          final msg = data['message'];
          _error = 'HTTP $status ${code ?? ''} ${msg ?? ''}'.trim();
        } else if (data is String && data.trim().isNotEmpty) {
          _error = 'HTTP $status ${data.trim()}'.trim();
        } else {
          _error = 'HTTP $status ${e.message ?? 'Request failed'}'.trim();
        }
      } else {
        _error = e;
      }
      _user = null;
      _idToken = null;
      _refreshToken = null;
      _preferredName = null;
      _isAdmin = false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> savePreferredName(String value) async {
    final token = _idToken;
    if (token == null || token.isEmpty) return;
    _setLoading(true);
    try {
      _error = null;
      final updated = await updatePreferredName.execute(token, value);
      _preferredName = updated ?? value;
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
    final inFlight = _refreshInFlight;
    if (inFlight != null) {
      return inFlight;
    }

    _refreshInFlight = _refreshAccessToken();
    try {
      return await _refreshInFlight;
    } finally {
      _refreshInFlight = null;
    }
  }

  Future<String?> _refreshAccessToken() async {
    try {
      final refresh = _refreshToken ?? await sessionStorage.readRefreshToken();
      if (refresh == null || refresh.isEmpty) {
        return null;
      }

      final deviceId = await deviceIdService.getOrCreate();
      final session = await onesAuthApi.refresh(
        refreshToken: refresh,
        deviceId: deviceId,
      );

      _idToken = session.accessToken;
      _refreshToken = session.refreshToken;
      await sessionStorage.writeTokens(
        accessToken: session.accessToken,
        refreshToken: session.refreshToken,
      );

      _isAdmin = await _safeLoadIsAdmin(session.accessToken);
      notifyListeners();
      return session.accessToken;
    } catch (e) {
      if (e is DioException && e.response?.statusCode == 401) {
        _sessionExpiredSeq++;
        notifyListeners();
      }
      return null;
    }
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      _error = null;
      final refresh = _refreshToken ?? await sessionStorage.readRefreshToken();
      if (refresh != null && refresh.isNotEmpty) {
        try {
          await onesAuthApi.logout(refreshToken: refresh);
        } catch (_) {
          // ignore
        }
      }
      await sessionStorage.clear();
      await signOut.execute();
      _user = null;
      _idToken = null;
      _refreshToken = null;
      _preferredName = null;
      _isAdmin = false;
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
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
}
