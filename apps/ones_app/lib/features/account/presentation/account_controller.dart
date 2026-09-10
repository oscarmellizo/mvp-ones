import 'package:flutter/foundation.dart';

import '../../../core/http/ones_api_factory.dart';
import '../../auth/presentation/auth_controller.dart';
import '../adapters/api/account_api_repository.dart';

class AccountController extends ChangeNotifier {
  final AccountApiRepository repository;

  String? _idToken;
  String? _ensuredForToken;
  AccountStatus? _status;
  bool _loading = false;
  Object? _error;

  AccountController({required OnesApiFactory apiFactory})
      : repository = AccountApiRepository(apiFactory);

  void setIdToken(String? idToken) {
    if (_idToken == idToken) {
      return;
    }
    _idToken = idToken;
    // Ensure reactivation only once per token assignment (i.e., on fresh login)
    if (_idToken != null && _idToken!.isNotEmpty) {
      if (_ensuredForToken != _idToken) {
        _ensuredForToken = _idToken;
        // Fire-and-forget; errors are ignored by design here
        // to avoid blocking app startup
        // ignore: discarded_futures
        ensureReactivatedIfEligible();
      }
    }
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

  Future<void> ensureReactivatedIfEligible() async {
    final token = _idToken;
    if (token == null || token.isEmpty) return;
    try {
      await repository.reactivate(token);
      _status = await repository.getStatus(token);
      notifyListeners();
    } catch (_) {}
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
