import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../../users/application/ensure_user_use_case.dart';
import '../../users/domain/users_repository.dart';
import '../../admin/application/get_admin_me_use_case.dart';

enum AuthNextStep {
  signedIn,
  needsRegistration,
  needsEmailVerification,
  failed,
}

class AuthController extends ChangeNotifier {
  final AuthRepository authRepository;
  final EnsureUserUseCase ensureUser;
  final GetUserPreferencesUseCase getUserPreferences;
  final UpdateUserPreferencesUseCase updateUserPreferences;
  final LookupUserByEmailUseCase lookupUserByEmailUseCase;
  final GetAdminMeUseCase getAdminMe;

  AuthUser? _user;
  String? _idToken;
  String? _preferredName;
  String? _languagePreference;
  bool _termsAccepted = false;
  bool _isAdmin = false;
  bool _isRegistered = false;
  bool _needsEmailVerification = false;
  bool _isLoading = false;
  Object? _error;

  Future<void>? _restoreInFlight;
  Future<AuthNextStep>? _signInInFlight;

  AuthController({
    required this.authRepository,
    required this.ensureUser,
    required this.getUserPreferences,
    required this.updateUserPreferences,
    required this.lookupUserByEmailUseCase,
    required this.getAdminMe,
  });

  AuthUser? get user => _user;
  String? get idToken => _idToken;
  String? get preferredName => _preferredName;
  String? get languagePreference => _languagePreference;
  bool get termsAccepted => _termsAccepted;
  bool get isAdmin => _isAdmin;
  bool get isSignedIn => _user != null;
  bool get isRegistered => _isRegistered;
  bool get needsEmailVerification => _needsEmailVerification;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> signIn() async {
    await signInExisting();
  }

  /// Compatibilidad: login e invitaciones usan este nombre para Google.
  Future<AuthNextStep> signInExisting() => signInWithGoogle();

  Future<AuthNextStep> signInWithGoogle() => _signIn(authRepository.signInWithGoogle);

  Future<AuthNextStep> signInWithApple() => _signIn(authRepository.signInWithApple);

  Future<AuthNextStep> signInWithEmail(String email, String password) =>
      _signIn(() => authRepository.signInWithEmail(email, password));

  Future<AuthNextStep> registerWithEmail(String email, String password) =>
      _signIn(() => authRepository.registerWithEmail(email, password));

  /// Registro con Google: si la cuenta ya existe en Ones devuelve signedIn.
  Future<AuthNextStep> beginRegistration() => signInWithGoogle();

  Future<AuthNextStep> beginRegistrationWithApple() => signInWithApple();

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
    var current = await authRepository.currentUser();
    if (current == null) return;

    _setLoading(true);
    try {
      _error = null;
      if (current.needsEmailVerification) {
        // Pudo verificar desde el correo mientras la app estaba cerrada.
        current = await authRepository.reloadUser() ?? current;
      }
      _user = current;
      final step = await _loadSession();
      // Google/Apple sin registro vuelven al login (como antes); correo sigue al formulario de registro.
      if (step == AuthNextStep.needsRegistration && current.provider != 'password') {
        _clearSession();
      }
    } catch (e) {
      _error = _formatDioOrRawError(e);
      _clearSession();
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthNextStep> _signIn(Future<AuthUser> Function() action) {
    return _signInInFlight ??= _runSignIn(action).whenComplete(() => _signInInFlight = null);
  }

  Future<AuthNextStep> _runSignIn(Future<AuthUser> Function() action) async {
    _setLoading(true);
    try {
      _error = null;
      _user = await action();
      return await _loadSession();
    } on AuthException catch (e) {
      _clearSession();
      _error = e.failure == AuthFailure.cancelled ? null : authFailureMessage(e.failure);
      return AuthNextStep.failed;
    } catch (e) {
      if (_errorCode(e) == 'EMAIL_CONFLICT') {
        await _safeSignOut();
      }
      _clearSession();
      _error = _formatDioOrRawError(e);
      return AuthNextStep.failed;
    } finally {
      _setLoading(false);
    }
  }

  /// Con [_user] autenticado en Firebase, decide el siguiente paso consultando el API.
  Future<AuthNextStep> _loadSession() async {
    if (_user!.needsEmailVerification) {
      _needsEmailVerification = true;
      _isRegistered = false;
      return AuthNextStep.needsEmailVerification;
    }
    _needsEmailVerification = false;

    final token = await _requireToken();
    try {
      return await _loadPreferences(token);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final code = _errorCode(e);
      if (status == 409 && code == 'ACCOUNT_MIGRATED') {
        // El backend reasignó la cuenta al uid legado: se entra de nuevo con la misma credencial.
        // Un segundo ACCOUNT_MIGRATED se propaga como error (sin bucle).
        _user = await authRepository.signInAgainAfterMigration();
        return await _loadPreferences(await _requireToken(forceRefresh: true));
      }
      if (status == 403 && code == 'EMAIL_NOT_VERIFIED') {
        _needsEmailVerification = true;
        return AuthNextStep.needsEmailVerification;
      }
      rethrow;
    }
  }

  Future<AuthNextStep> _loadPreferences(String token) async {
    try {
      final prefs = await getUserPreferences.execute(token);
      _preferredName = prefs?.preferredName;
      final lp = prefs?.languagePreference;
      _languagePreference = (lp != null && lp.trim().isNotEmpty) ? lp.trim().toLowerCase() : 'es';
      _termsAccepted = prefs?.termsAccepted ?? false;
      _isAdmin = await _safeLoadIsAdmin(token);
      _isRegistered = true;
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
  }

  Future<String> _requireToken({bool forceRefresh = false}) async {
    final token = await authRepository.getIdToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw StateError('Missing idToken');
    }
    _idToken = token;
    return token;
  }

  /// "Ya verifiqué": recarga el usuario y, si está verificado, continúa con un token nuevo.
  Future<AuthNextStep> confirmEmailVerified() async {
    _setLoading(true);
    try {
      _error = null;
      final user = await authRepository.reloadUser();
      if (user == null) {
        _clearSession();
        return AuthNextStep.failed;
      }
      _user = user;
      if (user.needsEmailVerification) {
        _error = 'Aún no vemos tu correo verificado. Abre el enlace que te enviamos y vuelve a intentarlo.';
        return AuthNextStep.needsEmailVerification;
      }
      // El token anterior no trae email_verified=true.
      await _requireToken(forceRefresh: true);
      return await _loadSession();
    } on AuthException catch (e) {
      _error = authFailureMessage(e.failure);
      return AuthNextStep.failed;
    } catch (e) {
      _error = _formatDioOrRawError(e);
      return AuthNextStep.failed;
    } finally {
      _setLoading(false);
    }
  }

  /// Revisión silenciosa al volver a la app: si ya verificó, continúa; si no, no muestra nada.
  Future<void> refreshEmailVerification() async {
    if (!_needsEmailVerification || _isLoading) return;
    try {
      final user = await authRepository.reloadUser();
      if (user == null || user.needsEmailVerification) return;
      _user = user;
      await _requireToken(forceRefresh: true);
      await _loadSession();
      notifyListeners();
    } catch (_) {
      // El botón "Ya verifiqué" muestra el error si el usuario lo intenta a mano.
    }
  }

  Future<bool> resendEmailVerification() async {
    try {
      _error = null;
      await authRepository.sendEmailVerification();
      return true;
    } on AuthException catch (e) {
      _error = authFailureMessage(e.failure);
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      _error = null;
      await authRepository.sendPasswordReset(email);
      return true;
    } on AuthException catch (e) {
      _error = authFailureMessage(e.failure);
      notifyListeners();
      return false;
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
      final updated = await updateUserPreferences.execute(token, trimmed, lang, termsAccepted);
      _preferredName = (updated?.preferredName ?? trimmed).trim();
      _languagePreference = (updated?.languagePreference ?? lang).trim().toLowerCase();
      _termsAccepted = updated?.termsAccepted ?? termsAccepted;
      _isAdmin = await _safeLoadIsAdmin(token);
      _isRegistered = true;
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
      final updated = await updateUserPreferences.execute(token, pn, lang, _termsAccepted);
      _preferredName = updated?.preferredName ?? pn;
      _languagePreference = (updated?.languagePreference ?? lang).trim().toLowerCase();
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

  /// Usado por el interceptor 401 de OnesApiFactory.
  Future<String?> refreshIdToken() async {
    try {
      final token = await authRepository.getIdToken(forceRefresh: true);
      if (token == null || token.isEmpty) return null;
      _idToken = token;
      if (_isRegistered) {
        _isAdmin = await _safeLoadIsAdmin(token);
      }
      notifyListeners();
      return token;
    } catch (_) {
      return null;
    }
  }

  /// "Intentar con otra cuenta" en el login.
  Future<void> clearGoogleSession() async {
    await _safeSignOut();
    _clearSession();
    notifyListeners();
  }

  Future<void>? _accountBlockedSignOutInFlight;

  /// Cierra la sesión porque el API rechazó la cuenta (ACCOUNT_DISABLED / ACCOUNT_CLOSED)
  /// y deja un mensaje en [error] para que la pantalla de login lo muestre.
  Future<void> signOutBecauseAccountBlocked(String code) {
    return _accountBlockedSignOutInFlight ??= _doSignOutBecauseAccountBlocked(code).whenComplete(() {
      _accountBlockedSignOutInFlight = null;
    });
  }

  Future<void> _doSignOutBecauseAccountBlocked(String code) async {
    await logout();
    _error = code == 'ACCOUNT_CLOSED'
        ? 'Tu cuenta fue cerrada porque pasaron más de 30 días desde su desactivación.'
        : 'Tu cuenta está desactivada. Vuelve a iniciar sesión para reactivarla.';
    notifyListeners();
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      _error = null;
      await authRepository.signOut();
    } catch (e) {
      _error = e;
    } finally {
      _clearSession();
      _setLoading(false);
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await authRepository.signOut();
    } catch (_) {}
  }

  void _clearSession() {
    _user = null;
    _idToken = null;
    _preferredName = null;
    _languagePreference = null;
    _termsAccepted = false;
    _isAdmin = false;
    _isRegistered = false;
    _needsEmailVerification = false;
  }

  static String? _errorCode(Object e) {
    if (e is! DioException) return null;
    final data = e.response?.data;
    return data is Map ? data['code']?.toString() : null;
  }

  Object _formatDioOrRawError(Object e) {
    if (e is DioException) {
      if (_errorCode(e) == 'EMAIL_CONFLICT') {
        return 'Ya existe una cuenta de Ones con este correo. Entra con Google.';
      }
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
    if (e is AuthException) return authFailureMessage(e.failure);
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
}
