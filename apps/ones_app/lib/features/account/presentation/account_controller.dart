import 'package:flutter/foundation.dart';

import '../../../core/http/ones_api_factory.dart';
import '../../auth/domain/auth_failure.dart';
import '../../auth/presentation/auth_controller.dart';
import '../adapters/api/account_api_repository.dart';

class AccountController extends ChangeNotifier {
  final AccountApiRepository repository;

  String? _idToken;
  AccountStatus? _status;
  bool _loading = false;
  Object? _error;

  AccountController({OnesApiFactory? apiFactory, AccountApiRepository? repository})
      : assert(apiFactory != null || repository != null, 'apiFactory or repository is required'),
        repository = repository ?? AccountApiRepository(apiFactory!);

  /// Sesión para la que ya se revisó la reactivación (se reinicia al cerrar sesión).
  String? _reactivationCheckedFor;

  void setIdToken(String? idToken) {
    _idToken = idToken;
    if (idToken == null || idToken.isEmpty) _reactivationCheckedFor = null;
  }

  AccountStatus? get status => _status;
  bool get loading => _loading;
  Object? get error => _error;

  Future<void> refreshStatus() async {
    final token = _idToken;
    if (token == null || token.isEmpty) return;
    _setLoading(true);
    try {
      _error = null;
      _status = await repository.getStatus(token);
    } catch (e) {
      _error = e;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deactivateAndSignOut(AuthController auth) async {
    final token = _idToken;
    if (token == null || token.isEmpty) return false;
    _setLoading(true);
    try {
      _error = null;
      try {
        await auth.revokeAppleAccessIfNeeded();
      } on AuthException catch (e) {
        if (e.failure == AuthFailure.cancelled) return false;
        debugPrint('[account] no se pudo revocar el acceso de Apple: $e');
      } catch (e) {
        debugPrint('[account] no se pudo revocar el acceso de Apple: $e');
      }
      final ok = await repository.deactivate(token);
      if (!ok) return false;
      await auth.logout();
      return true;
    } catch (e) {
      _error = e;
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Reactiva la cuenta si está DISABLED y sigue dentro de la ventana.
  /// Si el API rechaza la reactivación (ventana vencida), invoca [onClosed].
  /// Se llama en cada cambio de la sesión; con [sessionKey] solo consulta una vez por sesión
  /// (renovar el token cada hora no vuelve a disparar la consulta).
  Future<void> ensureReactivatedIfEligible({Future<void> Function()? onClosed, String? sessionKey}) async {
    final token = _idToken;
    if (token == null || token.isEmpty) return;
    if (sessionKey != null) {
      if (_reactivationCheckedFor == sessionKey) return;
      _reactivationCheckedFor = sessionKey;
    }
    try {
      final st = await repository.getStatus(token);
      if (st != null && st.status.toUpperCase() == 'DISABLED') {
        final reactivated = await repository.reactivate(token);
        if (reactivated == null && onClosed != null) {
          await onClosed();
        }
      }
    } catch (_) {}
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
