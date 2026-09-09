import 'package:flutter/foundation.dart';

import '../../../core/http/ones_api_factory.dart';
import '../../auth/presentation/auth_controller.dart';
import '../adapters/api/account_api_repository.dart';

class AccountController extends ChangeNotifier {
  final AccountApiRepository repository;

  String? _idToken;
  AccountStatus? _status;
  bool _loading = false;
  Object? _error;

  AccountController({required OnesApiFactory apiFactory})
      : repository = AccountApiRepository(apiFactory);

  void setIdToken(String? idToken) {
    _idToken = idToken;
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
      final st = await repository.getStatus(token);
      if (st != null && st.status.toUpperCase() == 'DISABLED') {
        await repository.reactivate(token);
      }
    } catch (_) {}
  }

  void _setLoading(bool v) {
    _loading = v;
    notifyListeners();
  }
}
