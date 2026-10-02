import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_api_client/ones_api_client.dart';
// ignore: implementation_imports
import 'package:ones_api_client/src/auth/bearer_auth.dart' show BearerAuthInterceptor;
import 'package:ones_app/core/i18n/translations_service.dart';
import 'package:ones_app/features/admin/application/get_admin_me_use_case.dart';
import 'package:ones_app/features/auth/presentation/auth_controller.dart';
import 'package:ones_app/features/users/application/ensure_user_use_case.dart';
import 'package:ones_app/features/users/domain/users_repository.dart';

import '../../features/auth/fake_auth_repository.dart';

class _MockGetPrefs extends Mock implements GetUserPreferencesUseCase {}
class _MockGetAdminMe extends Mock implements GetAdminMeUseCase {}
class _MockEnsureUser extends Mock implements EnsureUserUseCase {}
class _MockUpdatePrefs extends Mock implements UpdateUserPreferencesUseCase {}
class _MockLookup extends Mock implements LookupUserByEmailUseCase {}

void main() {
  test('al cerrar sesión, las traducciones dejan de enviar el token viejo', () async {
    final getPrefs = _MockGetPrefs();
    when(() => getPrefs.execute(any()))
        .thenAnswer((_) async => const UserPreferences(preferredName: 'Ana', languagePreference: 'es'));
    final admin = _MockGetAdminMe();
    when(() => admin.execute(any())).thenAnswer((_) async => false);
    final auth = AuthController(
      authRepository: FakeAuthRepository(),
      ensureUser: _MockEnsureUser(),
      getUserPreferences: getPrefs,
      updateUserPreferences: _MockUpdatePrefs(),
      lookupUserByEmailUseCase: _MockLookup(),
      getAdminMe: admin,
    );
    final client = OnesApiClient(basePathOverride: 'http://localhost');
    final service = TranslationsService(client);
    Map<String, String> tokens() =>
        client.dio.interceptors.whereType<BearerAuthInterceptor>().first.tokens;

    await auth.signInWithGoogle();
    service.setAuthController(auth);
    expect(tokens()['bearerAuth'], 'token-1');

    await auth.logout();
    service.setAuthController(auth);
    expect(tokens().containsKey('bearerAuth'), isFalse);
  });
}
