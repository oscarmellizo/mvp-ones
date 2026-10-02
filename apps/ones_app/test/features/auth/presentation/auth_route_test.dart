import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/features/admin/application/get_admin_me_use_case.dart';
import 'package:ones_app/features/auth/presentation/auth_controller.dart';
import 'package:ones_app/features/auth/presentation/auth_route.dart';
import 'package:ones_app/features/users/application/ensure_user_use_case.dart';
import 'package:ones_app/features/users/domain/users_repository.dart';

import '../fake_auth_repository.dart';

class _MockGetPrefs extends Mock implements GetUserPreferencesUseCase {}
class _MockGetAdminMe extends Mock implements GetAdminMeUseCase {}
class _MockEnsureUser extends Mock implements EnsureUserUseCase {}
class _MockUpdatePrefs extends Mock implements UpdateUserPreferencesUseCase {}
class _MockLookup extends Mock implements LookupUserByEmailUseCase {}

void main() {
  late FakeAuthRepository repo;
  late _MockGetPrefs getPrefs;
  late AuthController auth;

  setUp(() {
    repo = FakeAuthRepository();
    getPrefs = _MockGetPrefs();
    final admin = _MockGetAdminMe();
    when(() => admin.execute(any())).thenAnswer((_) async => false);
    when(() => getPrefs.execute(any()))
        .thenAnswer((_) async => const UserPreferences(preferredName: 'Ana', languagePreference: 'es'));
    auth = AuthController(
      authRepository: repo,
      ensureUser: _MockEnsureUser(),
      getUserPreferences: getPrefs,
      updateUserPreferences: _MockUpdatePrefs(),
      lookupUserByEmailUseCase: _MockLookup(),
      getAdminMe: admin,
    );
  });

  void notRegistered() {
    final req = RequestOptions(path: '/v1/users/me');
    when(() => getPrefs.execute(any())).thenThrow(
        DioException(requestOptions: req, response: Response(requestOptions: req, statusCode: 404)));
  }

  test('sin sesión → login', () {
    expect(resolveAuthRoute(auth), AuthRoute.login);
  });

  test('registrado → home', () async {
    await auth.signInWithGoogle();
    expect(resolveAuthRoute(auth), AuthRoute.home);
  });

  test('correo sin verificar → verificación', () async {
    repo.signInResult = fakeUser(provider: 'password', verified: false);
    await auth.signInWithEmail('a@b.co', 'secreto123');
    expect(resolveAuthRoute(auth), AuthRoute.verifyEmail);
  });

  test('correo verificado sin registro → formulario de registro', () async {
    repo.signInResult = fakeUser(provider: 'password');
    notRegistered();
    await auth.signInWithEmail('a@b.co', 'secreto123');
    expect(resolveAuthRoute(auth), AuthRoute.completeRegistration);
  });

  test('correo verificado sin registro tras reabrir la app → formulario de registro', () async {
    repo.current = fakeUser(provider: 'password');
    notRegistered();
    await auth.restoreSessionIfPossible();
    expect(resolveAuthRoute(auth), AuthRoute.completeRegistration);
  });

  test('Google sin registro → login (la pantalla apilada de registro sigue el flujo)', () async {
    notRegistered();
    await auth.signInWithGoogle();
    expect(resolveAuthRoute(auth), AuthRoute.login);
  });

  test('durante un inicio de sesión interactivo se queda en el login (no splash)', () async {
    repo.signInGate = Completer<void>();
    final pending = auth.signInWithEmail('a@b.co', 'mala');

    expect(auth.isLoading, isTrue);
    expect(resolveAuthRoute(auth), AuthRoute.login);

    repo.signInGate!.complete();
    await pending;
  });

  test('al restaurar la sesión muestra el splash', () async {
    repo.current = fakeUser();
    final gate = Completer<UserPreferences?>();
    when(() => getPrefs.execute(any())).thenAnswer((_) => gate.future);
    final pending = auth.restoreSessionIfPossible();
    await Future<void>.delayed(Duration.zero);

    expect(resolveAuthRoute(auth), AuthRoute.splash);

    gate.complete(const UserPreferences(preferredName: 'Ana', languagePreference: 'es'));
    await pending;
    expect(resolveAuthRoute(auth), AuthRoute.home);
  });

  test('H1: sin conexión al abrir → pantalla de conexión, no login', () async {
    repo.current = fakeUser();
    when(() => getPrefs.execute(any())).thenThrow(DioException(
      requestOptions: RequestOptions(path: '/v1/users/me'),
      type: DioExceptionType.connectionError,
    ));
    await auth.restoreSessionIfPossible();
    expect(resolveAuthRoute(auth), AuthRoute.offline);
  });
}
