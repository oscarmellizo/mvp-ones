import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/features/admin/application/get_admin_me_use_case.dart';
import 'package:ones_app/features/auth/domain/auth_failure.dart';
import 'package:ones_app/features/auth/presentation/auth_controller.dart';
import 'package:ones_app/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:ones_app/features/auth/presentation/pages/login_page.dart';
import 'package:ones_app/features/auth/presentation/pages/register_page.dart';
import 'package:ones_app/features/auth/presentation/pages/verify_email_page.dart';
import 'package:ones_app/features/users/application/ensure_user_use_case.dart';
import 'package:ones_app/features/users/domain/users_repository.dart';
import 'package:provider/provider.dart';

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

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
      value: auth,
      child: MaterialApp(home: home),
    ));
    await tester.pump();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  group('LoginPage', () {
    testWidgets('Apple solo aparece en iOS', (tester) async {
      await pump(tester, const LoginPage());
      expect(find.byKey(const Key('auth.apple')), findsNothing);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      await pump(tester, const LoginPage());
      expect(find.byKey(const Key('auth.apple')), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('el formulario de correo empieza plegado', (tester) async {
      await pump(tester, const LoginPage());

      expect(find.byKey(const Key('auth.email')), findsNothing);
      await tapKey(tester, 'auth.emailToggle');
      expect(find.byKey(const Key('auth.email')), findsOneWidget);
      expect(find.byKey(const Key('auth.emailToggle')), findsNothing);
    });

    testWidgets('valida el correo antes de enviar', (tester) async {
      await pump(tester, const LoginPage());
      await tapKey(tester, 'auth.emailToggle');

      await tester.enterText(find.byKey(const Key('auth.email')), 'no-es-correo');
      await tester.enterText(find.byKey(const Key('auth.password')), 'x');
      await tapKey(tester, 'auth.submit');

      expect(find.text('Escribe un correo válido.'), findsOneWidget);
      expect(auth.isSignedIn, isFalse);
    });

    testWidgets('inicia sesión con correo', (tester) async {
      await pump(tester, const LoginPage());
      await tapKey(tester, 'auth.emailToggle');

      await tester.enterText(find.byKey(const Key('auth.email')), 'ana@example.com');
      await tester.enterText(find.byKey(const Key('auth.password')), 'secreto123');
      await tapKey(tester, 'auth.submit');

      expect(auth.isRegistered, isTrue);
    });

    testWidgets('muestra el error sin el prefijo "Error:"', (tester) async {
      repo.signInError = const AuthExceptionForTest();
      await pump(tester, const LoginPage());

      await tapKey(tester, 'auth.google');

      expect(find.text('Correo o contraseña incorrectos.'), findsOneWidget);
      expect(find.textContaining('Error:'), findsNothing);
    });

    testWidgets('abre "Olvidé mi contraseña"', (tester) async {
      await pump(tester, const LoginPage());
      await tapKey(tester, 'auth.emailToggle');

      await tapKey(tester, 'auth.forgot');

      expect(find.byType(ForgotPasswordPage), findsOneWidget);
    });
  });

  group('RegisterPage', () {
    testWidgets('exige contraseña de 8 caracteres', (tester) async {
      await pump(tester, const RegisterPage());
      await tapKey(tester, 'auth.emailToggle');

      expect(find.text('Mínimo 8 caracteres.'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('auth.email')), 'ana@example.com');
      await tester.enterText(find.byKey(const Key('auth.password')), 'corta');
      await tapKey(tester, 'auth.submit');

      expect(find.text('Usa al menos 8 caracteres.'), findsOneWidget);
    });

    testWidgets('Google con cuenta ya registrada vuelve a la raíz', (tester) async {
      await pump(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage())),
            child: const Text('abrir'),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tapKey(tester, 'auth.google');

      expect(find.byType(RegisterPage), findsNothing);
      expect(auth.isRegistered, isTrue);
    });

    testWidgets('Google sin cuenta muestra el formulario de nombre', (tester) async {
      final req = RequestOptions(path: '/v1/users/me');
      when(() => getPrefs.execute(any())).thenThrow(
          DioException(requestOptions: req, response: Response(requestOptions: req, statusCode: 404)));
      await pump(tester, const RegisterPage());

      await tapKey(tester, 'auth.google');

      expect(find.byKey(const Key('auth.emailToggle')), findsNothing);
      expect(auth.user, isNotNull);
    });
  });

  group('VerifyEmailPage', () {
    testWidgets('muestra el correo, reenvía y confirma', (tester) async {
      repo.signInResult = fakeUser(provider: 'password', verified: false);
      await auth.registerWithEmail('ana@example.com', 'secreto123');
      await pump(tester, const VerifyEmailPage());

      expect(find.text('uid-1@example.com'), findsOneWidget);

      await tapKey(tester, 'verify.resend');
      expect(repo.verificationEmails, 2);
      expect(find.text('Te enviamos un nuevo enlace a uid-1@example.com.'), findsOneWidget);

      repo.afterReload = fakeUser(provider: 'password', verified: true);
      await tapKey(tester, 'verify.confirm');
      expect(auth.needsEmailVerification, isFalse);
    });
  });

  group('ForgotPasswordPage', () {
    testWidgets('envía el enlace y muestra confirmación neutral', (tester) async {
      await pump(tester, const ForgotPasswordPage());

      await tester.enterText(find.byKey(const Key('forgot.email')), 'ana@example.com');
      await tapKey(tester, 'forgot.send');

      expect(repo.passwordResets, ['ana@example.com']);
      expect(find.byKey(const Key('forgot.sent')), findsOneWidget);
    });
  });

  group('RegisterPage como raíz (correo verificado sin registro)', () {
    late _MockEnsureUser ensureUser;
    late _MockUpdatePrefs updatePrefs;
    late AuthController rootAuth;

    setUp(() async {
      ensureUser = _MockEnsureUser();
      updatePrefs = _MockUpdatePrefs();
      final admin = _MockGetAdminMe();
      final prefs = _MockGetPrefs();
      final req = RequestOptions(path: '/v1/users/me');
      when(() => admin.execute(any())).thenAnswer((_) async => false);
      when(() => prefs.execute(any())).thenThrow(
          DioException(requestOptions: req, response: Response(requestOptions: req, statusCode: 404)));
      when(() => ensureUser.execute(any())).thenAnswer((_) async {});
      when(() => updatePrefs.execute(any(), any(), any(), any())).thenAnswer(
          (_) async => const UserPreferences(preferredName: 'Ana', languagePreference: 'es', termsAccepted: true));
      repo.signInResult = fakeUser(provider: 'password');
      rootAuth = AuthController(
        authRepository: repo,
        ensureUser: ensureUser,
        getUserPreferences: prefs,
        updateUserPreferences: updatePrefs,
        lookupUserByEmailUseCase: _MockLookup(),
        getAdminMe: admin,
      );
      await rootAuth.signInWithEmail('ana@example.com', 'secreto123');
    });

    Future<void> pumpRoot(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
        value: rootAuth,
        child: const MaterialApp(home: RegisterPage(popToRootOnComplete: false)),
      ));
      await tester.pump();
    }

    testWidgets('completar el registro no deja la app sin pantalla', (tester) async {
      await pumpRoot(tester);

      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      final submit = find.widgetWithText(FilledButton, 'Crear cuenta');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pumpAndSettle();

      expect(rootAuth.isRegistered, isTrue);
      expect(find.byType(RegisterPage), findsOneWidget);
    });

    testWidgets('ofrece "Usar otra cuenta" y cierra la sesión', (tester) async {
      await pumpRoot(tester);

      await tapKey(tester, 'register.logout');

      expect(repo.signOutCalls, 1);
      expect(rootAuth.isSignedIn, isFalse);
    });
  });

  group('Teclado en iPhone', () {
    // iPhone de 390x844 pt; el teclado (336 pt) se abre después de tocar, como en el dispositivo.
    Future<void> pumpPhone(WidgetTester tester, Widget home, {bool keyboard = false}) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      if (keyboard) tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider<AuthController>.value(
        value: auth,
        child: MaterialApp(home: home),
      ));
      await tester.pump();
    }

    testWidgets('al desplegar el correo, el formulario completo queda sobre el teclado', (tester) async {
      await pumpPhone(tester, const LoginPage());

      await tester.tap(find.byKey(const Key('auth.emailToggle')));
      await tester.pump();
      tester.view.viewInsets = const FakeViewPadding(bottom: 336 * 3);
      await tester.pumpAndSettle();

      const visibleBottom = 844.0 - 336.0;
      final submit = tester.getRect(find.byKey(const Key('auth.submit')));
      final forgot = tester.getRect(find.byKey(const Key('auth.forgot')));
      expect(submit.bottom, lessThanOrEqualTo(visibleBottom));
      expect(forgot.bottom, lessThanOrEqualTo(visibleBottom));
    });

    testWidgets('tocar fuera de un campo oculta el teclado', (tester) async {
      await pumpPhone(tester, const LoginPage());
      await tester.tap(find.byKey(const Key('auth.emailToggle')));
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isFalse);
    });

    testWidgets('tocar fuera también oculta el teclado en "Olvidé mi contraseña"', (tester) async {
      await pumpPhone(tester, const ForgotPasswordPage(), keyboard: true);
      await tester.pumpAndSettle();
      expect(tester.testTextInput.isVisible, isTrue);

      await tester.tapAt(const Offset(195, 400));
      await tester.pumpAndSettle();

      expect(tester.testTextInput.isVisible, isFalse);
    });
  });
}

/// Error de credenciales para probar el aviso.
class AuthExceptionForTest extends AuthException {
  const AuthExceptionForTest() : super(AuthFailure.invalidCredentials);
}
