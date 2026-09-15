import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/features/admin/application/get_admin_me_use_case.dart';
import 'package:ones_app/features/auth/application/get_id_token_use_case.dart';
import 'package:ones_app/features/auth/application/sign_in_with_google_use_case.dart';
import 'package:ones_app/features/auth/application/sign_out_use_case.dart';
import 'package:ones_app/features/auth/infrastructure/google_token_refresh_service.dart';
import 'package:ones_app/features/auth/presentation/auth_controller.dart';
import 'package:ones_app/features/users/application/ensure_user_use_case.dart';
import 'package:ones_app/features/users/domain/users_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSignIn extends Mock implements SignInWithGoogleUseCase {}
class _MockSignOut extends Mock implements SignOutUseCase {}
class _MockGetIdToken extends Mock implements GetIdTokenUseCase {}
class _MockEnsureUser extends Mock implements EnsureUserUseCase {}
class _MockGetPrefs extends Mock implements GetUserPreferencesUseCase {}
class _MockUpdatePrefs extends Mock implements UpdateUserPreferencesUseCase {}
class _MockLookup extends Mock implements LookupUserByEmailUseCase {}
class _MockGetAdminMe extends Mock implements GetAdminMeUseCase {}
class _MockTokenRefresh extends Mock implements GoogleTokenRefreshService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockSignOut signOut;
  late AuthController auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    signOut = _MockSignOut();
    when(() => signOut.execute()).thenAnswer((_) async {});
    auth = AuthController(
      signInWithGoogle: _MockSignIn(),
      signOut: signOut,
      getIdToken: _MockGetIdToken(),
      ensureUser: _MockEnsureUser(),
      getUserPreferences: _MockGetPrefs(),
      updateUserPreferences: _MockUpdatePrefs(),
      lookupUserByEmailUseCase: _MockLookup(),
      getAdminMe: _MockGetAdminMe(),
      tokenRefreshService: _MockTokenRefresh(),
    );
  });

  group('signOutBecauseAccountBlocked', () {
    test('signs out and exposes a closed-account message', () async {
      await auth.signOutBecauseAccountBlocked('ACCOUNT_CLOSED');

      verify(() => signOut.execute()).called(1);
      expect(auth.isRegistered, isFalse);
      expect(auth.idToken, isNull);
      expect(auth.error.toString(), contains('cerrada'));
    });

    test('exposes a disabled-account message for ACCOUNT_DISABLED', () async {
      await auth.signOutBecauseAccountBlocked('ACCOUNT_DISABLED');

      expect(auth.error.toString(), contains('desactivada'));
    });

    test('does not run twice concurrently', () async {
      await Future.wait([
        auth.signOutBecauseAccountBlocked('ACCOUNT_CLOSED'),
        auth.signOutBecauseAccountBlocked('ACCOUNT_CLOSED'),
      ]);

      verify(() => signOut.execute()).called(1);
    });
  });
}
