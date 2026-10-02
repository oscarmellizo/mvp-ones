import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/features/admin/application/get_admin_me_use_case.dart';
import 'package:ones_app/features/auth/domain/auth_failure.dart';
import 'package:ones_app/features/auth/presentation/auth_controller.dart';
import 'package:ones_app/features/users/application/ensure_user_use_case.dart';
import 'package:ones_app/features/users/domain/users_repository.dart';

import '../fake_auth_repository.dart';

class _MockEnsureUser extends Mock implements EnsureUserUseCase {}
class _MockGetPrefs extends Mock implements GetUserPreferencesUseCase {}
class _MockUpdatePrefs extends Mock implements UpdateUserPreferencesUseCase {}
class _MockLookup extends Mock implements LookupUserByEmailUseCase {}
class _MockGetAdminMe extends Mock implements GetAdminMeUseCase {}

DioException apiError(int status, [String? code]) {
  final req = RequestOptions(path: '/v1/users/me');
  return DioException(
    requestOptions: req,
    response: Response(requestOptions: req, statusCode: status, data: code == null ? null : {'code': code}),
    type: DioExceptionType.badResponse,
  );
}

const registeredPrefs = UserPreferences(preferredName: 'Ana', languagePreference: 'ES', termsAccepted: true);

void main() {
  late FakeAuthRepository repo;
  late _MockGetPrefs getPrefs;
  late _MockEnsureUser ensureUser;
  late _MockUpdatePrefs updatePrefs;
  late AuthController auth;

  setUp(() {
    repo = FakeAuthRepository();
    getPrefs = _MockGetPrefs();
    ensureUser = _MockEnsureUser();
    updatePrefs = _MockUpdatePrefs();
    final getAdminMe = _MockGetAdminMe();
    when(() => getAdminMe.execute(any())).thenAnswer((_) async => false);
    when(() => getPrefs.execute(any())).thenAnswer((_) async => registeredPrefs);
    auth = AuthController(
      authRepository: repo,
      ensureUser: ensureUser,
      getUserPreferences: getPrefs,
      updateUserPreferences: updatePrefs,
      lookupUserByEmailUseCase: _MockLookup(),
      getAdminMe: getAdminMe,
    );
  });

  group('inicio de sesión', () {
    test('cuenta registrada entra directo', () async {
      expect(await auth.signInWithGoogle(), AuthNextStep.signedIn);
      expect(auth.isRegistered, isTrue);
      expect(auth.idToken, 'token-1');
      expect(auth.languagePreference, 'es');
    });

    test('signInExisting sigue siendo Google', () async {
      expect(await auth.signInExisting(), AuthNextStep.signedIn);
    });

    test('404 en /v1/users/me pide registro', () async {
      when(() => getPrefs.execute(any())).thenThrow(apiError(404));

      expect(await auth.signInWithApple(), AuthNextStep.needsRegistration);
      expect(auth.isRegistered, isFalse);
      expect(auth.isSignedIn, isTrue);
    });

    test('correo sin verificar no llama al API', () async {
      repo.signInResult = fakeUser(provider: 'password', verified: false);

      expect(await auth.signInWithEmail('a@b.co', 'secreto123'), AuthNextStep.needsEmailVerification);
      expect(auth.needsEmailVerification, isTrue);
      verifyNever(() => getPrefs.execute(any()));
    });

    test('403 EMAIL_NOT_VERIFIED del API también pide verificación', () async {
      repo.signInResult = fakeUser(provider: 'password');
      when(() => getPrefs.execute(any())).thenThrow(apiError(403, 'EMAIL_NOT_VERIFIED'));

      expect(await auth.signInWithEmail('a@b.co', 'secreto123'), AuthNextStep.needsEmailVerification);
      expect(auth.needsEmailVerification, isTrue);
    });

    test('409 ACCOUNT_MIGRATED reintenta una vez con token forzado', () async {
      var calls = 0;
      when(() => getPrefs.execute(any())).thenAnswer((_) async {
        calls++;
        if (calls == 1) throw apiError(409, 'ACCOUNT_MIGRATED');
        return registeredPrefs;
      });
      repo.afterMigration = fakeUser(id: 'google-sub-1');

      expect(await auth.signInWithGoogle(), AuthNextStep.signedIn);
      expect(repo.migrationRetries, 1);
      expect(repo.tokenRequests, contains(true));
      expect(auth.user!.userId, 'google-sub-1');
    });

    test('segundo ACCOUNT_MIGRATED termina en error, sin bucle', () async {
      when(() => getPrefs.execute(any())).thenThrow(apiError(409, 'ACCOUNT_MIGRATED'));

      expect(await auth.signInWithGoogle(), AuthNextStep.failed);
      expect(repo.migrationRetries, 1);
      expect(auth.error, isNotNull);
      expect(auth.isSignedIn, isFalse);
    });

    test('409 EMAIL_CONFLICT pide entrar con Google y cierra la sesión de Firebase', () async {
      when(() => getPrefs.execute(any())).thenThrow(apiError(409, 'EMAIL_CONFLICT'));

      expect(await auth.signInWithApple(), AuthNextStep.failed);
      expect(auth.error.toString(), contains('Google'));
      expect(repo.signOutCalls, 1);
    });

    test('cancelar no muestra error', () async {
      repo.signInError = const AuthException(AuthFailure.cancelled);

      expect(await auth.signInWithGoogle(), AuthNextStep.failed);
      expect(auth.error, isNull);
    });

    test('credenciales inválidas muestran mensaje', () async {
      repo.signInError = const AuthException(AuthFailure.invalidCredentials);

      expect(await auth.signInWithEmail('a@b.co', 'mala'), AuthNextStep.failed);
      expect(auth.error, 'Correo o contraseña incorrectos.');
    });
  });

  group('verificación de correo', () {
    test('registro con correo envía verificación y espera', () async {
      repo.signInResult = fakeUser(provider: 'password', verified: false);

      expect(await auth.registerWithEmail('a@b.co', 'secreto123'), AuthNextStep.needsEmailVerification);
      expect(repo.verificationEmails, 1);
    });

    test('confirmar sin haber verificado mantiene la pantalla con aviso', () async {
      repo.signInResult = fakeUser(provider: 'password', verified: false);
      await auth.registerWithEmail('a@b.co', 'secreto123');

      expect(await auth.confirmEmailVerified(), AuthNextStep.needsEmailVerification);
      expect(auth.error, isNotNull);
    });

    test('confirmar verificado fuerza token nuevo y sigue al registro', () async {
      repo.signInResult = fakeUser(provider: 'password', verified: false);
      await auth.registerWithEmail('a@b.co', 'secreto123');
      repo.afterReload = fakeUser(provider: 'password', verified: true);
      when(() => getPrefs.execute(any())).thenThrow(apiError(404));

      expect(await auth.confirmEmailVerified(), AuthNextStep.needsRegistration);
      expect(auth.needsEmailVerification, isFalse);
      expect(repo.tokenRequests, contains(true));
    });

    test('al volver a la app detecta la verificación sin mostrar errores', () async {
      repo.signInResult = fakeUser(provider: 'password', verified: false);
      await auth.registerWithEmail('a@b.co', 'secreto123');

      await auth.refreshEmailVerification();
      expect(auth.needsEmailVerification, isTrue);
      expect(auth.error, isNull);

      repo.afterReload = fakeUser(provider: 'password', verified: true);
      await auth.refreshEmailVerification();
      expect(auth.needsEmailVerification, isFalse);
      expect(auth.isRegistered, isTrue);
    });

    test('reenviar y restablecer contraseña', () async {
      repo.current = fakeUser(provider: 'password', verified: false);

      expect(await auth.resendEmailVerification(), isTrue);
      expect(await auth.sendPasswordReset(' a@b.co '), isTrue);
      expect(repo.verificationEmails, 1);
      expect(repo.passwordResets, [' a@b.co ']);
    });
  });

  group('sesión', () {
    test('sin usuario de Firebase no restaura nada', () async {
      await auth.restoreSessionIfPossible();

      expect(auth.isSignedIn, isFalse);
      verifyNever(() => getPrefs.execute(any()));
    });

    test('restaura un usuario registrado', () async {
      repo.current = fakeUser();

      await auth.restoreSessionIfPossible();

      expect(auth.isRegistered, isTrue);
    });

    test('restaura correo sin verificar en la pantalla de verificación', () async {
      repo.current = fakeUser(provider: 'password', verified: false);

      await auth.restoreSessionIfPossible();

      expect(auth.needsEmailVerification, isTrue);
    });

    test('al restaurar recarga el usuario por si verificó mientras la app estaba cerrada', () async {
      repo.current = fakeUser(provider: 'password', verified: false);
      repo.afterReload = fakeUser(provider: 'password', verified: true);

      await auth.restoreSessionIfPossible();

      expect(auth.needsEmailVerification, isFalse);
      expect(auth.isRegistered, isTrue);
      // El token en caché aún dice email_verified=false: hay que pedir uno nuevo.
      expect(repo.tokenRequests, contains(true));
    });

    test('refreshIdToken fuerza refresh', () async {
      repo.current = fakeUser();

      expect(await auth.refreshIdToken(), 'token-1');
      expect(repo.tokenRequests.last, isTrue);
    });

    test('logout limpia todo, incluido idioma y términos', () async {
      await auth.signInWithGoogle();

      await auth.logout();

      expect(repo.signOutCalls, 1);
      expect(auth.isSignedIn, isFalse);
      expect(auth.languagePreference, isNull);
      expect(auth.termsAccepted, isFalse);
    });
  });

  group('signOutBecauseAccountBlocked', () {
    test('signs out and exposes a closed-account message', () async {
      await auth.signOutBecauseAccountBlocked('ACCOUNT_CLOSED');

      expect(repo.signOutCalls, 1);
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

      expect(repo.signOutCalls, 1);
    });
  });

  group('fallas de la revisión final', () {
    test('EMAIL_CONFLICT al completar el registro cierra la sesión y pide entrar con Google', () async {
      when(() => getPrefs.execute(any())).thenThrow(apiError(404));
      await auth.signInWithApple();
      when(() => ensureUser.execute(any())).thenThrow(apiError(409, 'EMAIL_CONFLICT'));

      await expectLater(auth.completeRegistration('Ana', termsAccepted: true), throwsA(anything));

      expect(repo.signOutCalls, 1);
      expect(auth.isSignedIn, isFalse);
      expect(auth.error.toString(), contains('Google'));
    });

    test('segundo ACCOUNT_MIGRATED cierra la sesión de Firebase y pide entrar con Google', () async {
      when(() => getPrefs.execute(any())).thenThrow(apiError(409, 'ACCOUNT_MIGRATED'));

      expect(await auth.signInWithGoogle(), AuthNextStep.failed);
      expect(repo.signOutCalls, 1);
      expect(auth.error.toString(), contains('Google'));
      expect(auth.error.toString(), isNot(contains('HTTP')));
    });

    test('migración sin credencial guardada cierra la sesión y pide entrar con Google', () async {
      when(() => getPrefs.execute(any())).thenThrow(apiError(409, 'ACCOUNT_MIGRATED'));
      repo.migrationError = const AuthException(AuthFailure.unknown, 'Sin credencial');

      expect(await auth.signInWithGoogle(), AuthNextStep.failed);
      expect(repo.signOutCalls, 1);
      expect(auth.error.toString(), contains('Google'));
    });

    test('ACCOUNT_MIGRATION_FAILED muestra un mensaje claro', () async {
      when(() => getPrefs.execute(any())).thenThrow(apiError(503, 'ACCOUNT_MIGRATION_FAILED'));

      expect(await auth.signInWithGoogle(), AuthNextStep.failed);
      expect(auth.error.toString(), isNot(contains('HTTP')));
      expect(auth.error.toString(), contains('Inténtalo de nuevo'));
    });

    test('sin conexión muestra el mensaje de red', () async {
      when(() => getPrefs.execute(any())).thenThrow(DioException(
        requestOptions: RequestOptions(path: '/v1/users/me'),
        type: DioExceptionType.connectionError,
      ));

      expect(await auth.signInWithGoogle(), AuthNextStep.failed);
      expect(auth.error, authFailureMessage(AuthFailure.network));
    });

    test('si el API falla al revisar la verificación, se queda en la pantalla de verificación', () async {
      repo.signInResult = fakeUser(provider: 'password', verified: false);
      await auth.registerWithEmail('a@b.co', 'secreto123');
      repo.afterReload = fakeUser(provider: 'password', verified: true);
      when(() => getPrefs.execute(any())).thenThrow(apiError(500));

      await auth.refreshEmailVerification();

      expect(auth.needsEmailVerification, isTrue);
    });

    test('refreshEmailVerification no corre dos veces a la vez', () async {
      repo.signInResult = fakeUser(provider: 'password', verified: false);
      await auth.registerWithEmail('a@b.co', 'secreto123');

      await Future.wait([auth.refreshEmailVerification(), auth.refreshEmailVerification()]);

      expect(repo.reloadCalls, 1);
    });
  });

  group('sesión que muere', () {
    setUp(() async {
      await auth.signInWithGoogle();
      expect(auth.isRegistered, isTrue);
    });

    test('sesión expirada al renovar el token: cierra sesión y avisa', () async {
      repo.tokenError = const AuthException(AuthFailure.sessionExpired);

      expect(await auth.refreshIdToken(), isNull);

      expect(auth.isSignedIn, isFalse);
      expect(repo.signOutCalls, 1);
      expect(auth.error, 'Tu sesión expiró. Inicia sesión de nuevo.');
    });

    test('cuenta deshabilitada o borrada en Firebase: cierra sesión', () async {
      repo.tokenError = const AuthException(AuthFailure.userDisabled);
      await auth.refreshIdToken();
      expect(auth.isSignedIn, isFalse);
      expect(auth.error, authFailureMessage(AuthFailure.userDisabled));
    });

    test('sin internet al renovar: mantiene la sesión', () async {
      repo.tokenError = const AuthException(AuthFailure.network);

      expect(await auth.refreshIdToken(), isNull);

      expect(auth.isSignedIn, isTrue);
      expect(auth.isRegistered, isTrue);
      expect(repo.signOutCalls, 0);
    });

    test('Firebase ya no tiene usuario: cierra sesión', () async {
      repo.current = null;

      expect(await auth.refreshIdToken(), isNull);

      expect(auth.isSignedIn, isFalse);
      expect(auth.error, 'Tu sesión expiró. Inicia sesión de nuevo.');
    });

    test('al volver a la app sin usuario en Firebase: cierra sesión', () async {
      repo.current = null;

      await auth.checkSessionOnResume();

      expect(auth.isSignedIn, isFalse);
    });

    test('al volver a la app con la sesión viva: no hace nada', () async {
      await auth.checkSessionOnResume();

      expect(auth.isSignedIn, isTrue);
      expect(repo.signOutCalls, 0);
    });
  });

  group('instalación nueva', () {
    test('la primera apertura tras instalar descarta la sesión guardada', () async {
      repo.current = fakeUser();
      repo.freshInstall = true;

      await auth.restoreSessionIfPossible();

      expect(repo.freshInstallChecks, 1);
      expect(auth.isSignedIn, isFalse);
    });

    test('en aperturas normales restaura la sesión', () async {
      repo.current = fakeUser();

      await auth.restoreSessionIfPossible();

      expect(repo.freshInstallChecks, 1);
      expect(auth.isRegistered, isTrue);
    });
  });
}
