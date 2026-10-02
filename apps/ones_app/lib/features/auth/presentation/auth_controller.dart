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

  /// Reactiva una cuenta dada de baja dentro del plazo (POST /v1/account/reactivate).
  /// Devuelve false si el backend la rechaza (cuenta ya cerrada).
  final Future<bool> Function(String idToken)? reactivateAccount;

  AuthUser? _user;
  String? _idToken;
  String? _preferredName;
  String? _languagePreference;
  bool _termsAccepted = false;
  bool _isAdmin = false;
  bool _isRegistered = false;
  bool _needsEmailVerification = false;
  bool _isLoading = false;
  bool _isRestoring = false;
  bool _needsConnection = false;
  Object? _error;

  Future<void>? _restoreInFlight;
  Future<AuthNextStep>? _signInInFlight;
  Future<void>? _refreshVerificationInFlight;

  AuthController({
    required this.authRepository,
    required this.ensureUser,
    required this.getUserPreferences,
    required this.updateUserPreferences,
    required this.lookupUserByEmailUseCase,
    required this.getAdminMe,
    this.reactivateAccount,
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

  /// Restaurando la sesión al abrir la app (el router muestra el splash solo en este caso).
  bool get isRestoring => _isRestoring;

  /// Hay sesión pero no se pudo hablar con el API al abrir la app (sin internet o servicio caído).
  bool get needsConnection => _needsConnection;
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
    _isRestoring = true;
    _needsConnection = false;
    try {
      await authRepository.clearSessionIfFreshInstall();
    } catch (_) {
      // Si no se puede comprobar, se sigue con la sesión que haya.
    }
    var current = await authRepository.currentUser();
    if (current == null) {
      _isRestoring = false;
      notifyListeners();
      return;
    }

    _setLoading(true);
    try {
      _error = null;
      if (current.needsEmailVerification) {
        // Pudo verificar desde el correo mientras la app estaba cerrada.
        final reloaded = await authRepository.reloadUser();
        if (reloaded != null && !reloaded.needsEmailVerification) {
          current = reloaded;
          // El token en caché aún dice email_verified=false.
          _user = reloaded;
          await _requireToken(forceRefresh: true);
        }
      }
      _user = current;
      final step = await _loadSession();
      // Google/Apple sin registro vuelven al login (como antes); correo sigue al formulario de registro.
      if (step == AuthNextStep.needsRegistration && current.provider != 'password') {
        _clearSession();
      }
    } catch (e) {
      _error = _formatDioOrRawError(e);
      if (_isTransient(e)) {
        // Sesión válida pero sin conexión: no se saca al usuario; se le ofrece reintentar.
        _needsConnection = true;
      } else {
        _clearSession();
      }
    } finally {
      _isRestoring = false;
      _setLoading(false);
    }
  }

  /// "Reintentar" en la pantalla sin conexión.
  Future<void> retryConnection() => restoreSessionIfPossible();

  static bool _isTransient(Object e) {
    if (e is AuthException) return e.failure == AuthFailure.network;
    if (e is! DioException) return false;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return true;
    }
    final status = e.response?.statusCode;
    return status != null && status >= 500;
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
    final token = await _requireToken();
    try {
      return await _loadPreferences(token);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final code = _errorCode(e);
      if (status == 409 && code == 'ACCOUNT_MIGRATED') {
        // El backend reasignó la cuenta al uid legado: se entra de nuevo con la misma credencial.
        // Si no se puede (sin credencial guardada, o un segundo ACCOUNT_MIGRATED), se cierra la
        // sesión y se pide entrar con Google, sin bucles.
        try {
          _user = await authRepository.signInAgainAfterMigration();
          return await _loadPreferences(await _requireToken(forceRefresh: true));
        } catch (_) {
          await _safeSignOut();
          throw const _AuthMessage(_migratedMessage);
        }
      }
      if (status == 403 && code == 'ACCOUNT_DISABLED') {
        // Dada de baja dentro del plazo: volver a entrar la reactiva (lo promete el diálogo de baja).
        final reactivate = reactivateAccount;
        final reactivated = reactivate != null && await reactivate(token);
        if (reactivated) {
          return await _loadPreferences(token);
        }
        await _safeSignOut();
        throw const _AuthMessage(_closedMessage);
      }
      if (status == 403 && code == 'ACCOUNT_CLOSED') {
        await _safeSignOut();
        throw const _AuthMessage(_closedMessage);
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
      _needsEmailVerification = false;
      return AuthNextStep.signedIn;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _needsEmailVerification = false;
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
  Future<void> refreshEmailVerification() {
    if (!_needsEmailVerification || _isLoading) return Future.value();
    return _refreshVerificationInFlight ??=
        _refreshEmailVerificationInternal().whenComplete(() => _refreshVerificationInFlight = null);
  }

  Future<void> _refreshEmailVerificationInternal() async {
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
      if (_errorCode(e) == 'EMAIL_CONFLICT') {
        // El correo ya es de otra cuenta (p. ej. de Google): se vuelve al login con el aviso.
        await _safeSignOut();
        _clearSession();
      }
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

  /// Usado por el interceptor 401 de OnesApiFactory. Si la sesión murió (cuenta borrada o
  /// deshabilitada, sesión revocada o Firebase sin usuario) vuelve al login con un aviso;
  /// ante fallas pasajeras (sin internet) conserva la sesión.
  Future<String?> refreshIdToken() async {
    try {
      final String? token;
      try {
        // Firebase ya renueva el token antes de que venza. Forzar uno nuevo en cada llamada
        // cambia el token siempre, y los controladores borran su estado al ver un token distinto.
        token = await authRepository.getIdToken();
      } on AuthException catch (e) {
        if (_sessionIsOver(e.failure)) await _endSession(authFailureMessage(e.failure));
        return null;
      }
      if (token == null || token.isEmpty) {
        if (_user != null) await _endSession(authFailureMessage(AuthFailure.sessionExpired));
        return null;
      }
      if (token == _idToken) return token;
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

  /// Al volver a la app: si Firebase ya no tiene usuario, la sesión murió mientras estaba en segundo plano.
  Future<void> checkSessionOnResume() async {
    if (_needsConnection && !_isLoading) {
      await retryConnection();
      return;
    }
    if (_user == null || _isLoading) return;
    try {
      final current = await authRepository.currentUser();
      if (current == null && _user != null && !_isLoading) {
        await _endSession(authFailureMessage(AuthFailure.sessionExpired));
      }
    } catch (_) {
      // Si no se puede comprobar, se mantiene la sesión.
    }
  }

  static bool _sessionIsOver(AuthFailure failure) =>
      failure == AuthFailure.sessionExpired ||
      failure == AuthFailure.userDisabled ||
      failure == AuthFailure.invalidCredentials;

  Future<void>? _endSessionInFlight;

  Future<void> _endSession(String message) {
    return _endSessionInFlight ??= () async {
      await _safeSignOut();
      _clearSession();
      _error = message;
      notifyListeners();
    }()
        .whenComplete(() => _endSessionInFlight = null);
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
    // Durante un inicio de sesión o la restauración, el propio flujo maneja la cuenta bloqueada
    // (y reactiva si corresponde); cerrar sesión aquí competiría con él.
    if (_isLoading || _isRestoring) return Future.value();
    return _accountBlockedSignOutInFlight ??= _doSignOutBecauseAccountBlocked(code).whenComplete(() {
      _accountBlockedSignOutInFlight = null;
    });
  }

  Future<void> _doSignOutBecauseAccountBlocked(String code) async {
    await logout();
    _error = code == 'ACCOUNT_CLOSED' ? _closedMessage : _disabledMessage;
    notifyListeners();
  }

  /// Revoca el acceso de Sign in with Apple (no-op en otros proveedores). Lo usa la baja de cuenta.
  Future<void> revokeAppleAccessIfNeeded() => authRepository.revokeAppleAccessIfNeeded();

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
    _needsConnection = false;
  }

  static String? _errorCode(Object e) {
    if (e is! DioException) return null;
    final data = e.response?.data;
    return data is Map ? data['code']?.toString() : null;
  }

  Object _formatDioOrRawError(Object e) {
    if (e is _AuthMessage) return e.message;
    if (e is DioException) {
      final status = e.response?.statusCode;
      switch (_errorCode(e)) {
        case 'EMAIL_CONFLICT':
          return 'Ya existe una cuenta de Ones con este correo. Entra con Google.';
        case 'ACCOUNT_MIGRATED':
          return _migratedMessage;
        case 'ACCOUNT_DISABLED':
          return _disabledMessage;
        case 'ACCOUNT_CLOSED':
          return _closedMessage;
        case 'ACCOUNT_MIGRATION_FAILED':
          return 'No pudimos actualizar tu cuenta en este momento. Inténtalo de nuevo en unos minutos.';
      }
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return authFailureMessage(AuthFailure.network);
      }
      if (status != null && status >= 500) {
        return 'El servicio no está disponible en este momento. Inténtalo de nuevo en unos minutos.';
      }
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

const _migratedMessage = 'Actualizamos tu cuenta. Vuelve a entrar con Google para continuar.';
const _closedMessage = 'Tu cuenta fue cerrada porque pasaron más de 30 días desde su desactivación.';
const _disabledMessage = 'Tu cuenta está desactivada. Vuelve a iniciar sesión para reactivarla.';

/// Error con un mensaje ya listo para mostrar.
class _AuthMessage implements Exception {
  final String message;

  const _AuthMessage(this.message);

  @override
  String toString() => message;
}
