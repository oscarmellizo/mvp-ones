import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/features/account/adapters/api/account_api_repository.dart';
import 'package:ones_app/features/account/presentation/account_controller.dart';
import 'package:ones_app/features/account/presentation/pages/account_page.dart';
import 'package:ones_app/features/admin/application/get_admin_me_use_case.dart';
import 'package:ones_app/features/auth/domain/auth_failure.dart';
import 'package:ones_app/features/auth/presentation/auth_controller.dart';
import 'package:ones_app/features/subscriptions/domain/subscriptions_repository.dart';
import 'package:ones_app/features/subscriptions/presentation/subscriptions_controller.dart';
import 'package:ones_app/features/users/application/ensure_user_use_case.dart';
import 'package:ones_app/features/users/domain/users_repository.dart';
import 'package:provider/provider.dart';

import '../../auth/fake_auth_repository.dart';

class _MockAccountApiRepository extends Mock implements AccountApiRepository {}
class _MockGetPrefs extends Mock implements GetUserPreferencesUseCase {}
class _MockGetAdminMe extends Mock implements GetAdminMeUseCase {}
class _MockEnsureUser extends Mock implements EnsureUserUseCase {}
class _MockUpdatePrefs extends Mock implements UpdateUserPreferencesUseCase {}
class _MockLookup extends Mock implements LookupUserByEmailUseCase {}
class _MockSubscriptionsRepository extends Mock implements SubscriptionsRepository {}

AuthController _authWith(FakeAuthRepository repo) => AuthController(
      authRepository: repo,
      ensureUser: _MockEnsureUser(),
      getUserPreferences: _MockGetPrefs(),
      updateUserPreferences: _MockUpdatePrefs(),
      lookupUserByEmailUseCase: _MockLookup(),
      getAdminMe: _MockGetAdminMe(),
    );

void main() {
  late _MockAccountApiRepository repo;
  late AccountController controller;

  setUp(() {
    repo = _MockAccountApiRepository();
    controller = AccountController(repository: repo)..setIdToken('token');
  });

  group('ensureReactivatedIfEligible', () {
    test('calls onClosed when the account is DISABLED and reactivation is refused', () async {
      when(() => repo.getStatus('token')).thenAnswer(
        (_) async => const AccountStatus(status: 'DISABLED'),
      );
      when(() => repo.reactivate('token')).thenAnswer((_) async => null);
      var closedCalls = 0;

      await controller.ensureReactivatedIfEligible(onClosed: () async => closedCalls++);

      expect(closedCalls, 1);
    });

    test('does not call onClosed when reactivation succeeds', () async {
      when(() => repo.getStatus('token')).thenAnswer(
        (_) async => const AccountStatus(status: 'DISABLED'),
      );
      when(() => repo.reactivate('token')).thenAnswer(
        (_) async => const AccountStatus(status: 'ACTIVE'),
      );
      var closedCalls = 0;

      await controller.ensureReactivatedIfEligible(onClosed: () async => closedCalls++);

      expect(closedCalls, 0);
    });

    test('does nothing for an ACTIVE account', () async {
      when(() => repo.getStatus('token')).thenAnswer(
        (_) async => const AccountStatus(status: 'ACTIVE'),
      );
      var closedCalls = 0;

      await controller.ensureReactivatedIfEligible(onClosed: () async => closedCalls++);

      expect(closedCalls, 0);
      verifyNever(() => repo.reactivate(any()));
    });
  });

  group('una sola vez por sesión', () {
    test('no vuelve a consultar el estado cuando solo se renueva el token', () async {
      when(() => repo.getStatus(any())).thenAnswer((_) async => const AccountStatus(status: 'ACTIVE'));

      await controller.ensureReactivatedIfEligible(sessionKey: 'uid-1');
      controller.setIdToken('token-renovado');
      await controller.ensureReactivatedIfEligible(sessionKey: 'uid-1');

      verify(() => repo.getStatus(any())).called(1);
    });

    test('vuelve a consultar en una sesión nueva', () async {
      when(() => repo.getStatus(any())).thenAnswer((_) async => const AccountStatus(status: 'ACTIVE'));

      await controller.ensureReactivatedIfEligible(sessionKey: 'uid-1');
      controller.setIdToken(null);
      controller.setIdToken('token-otra-sesion');
      await controller.ensureReactivatedIfEligible(sessionKey: 'uid-1');

      verify(() => repo.getStatus(any())).called(2);
    });
  });

  group('deactivateAndSignOut', () {
    late FakeAuthRepository authRepo;
    late AuthController auth;

    setUp(() {
      authRepo = FakeAuthRepository()..current = fakeUser(provider: 'apple.com');
      auth = _authWith(authRepo);
      when(() => repo.deactivate('token')).thenAnswer((_) async {
        authRepo.calls.add('deactivate');
        return true;
      });
    });

    test('baja con Apple revoca el acceso antes de desactivar', () async {
      await controller.deactivateAndSignOut(auth);
      expect(authRepo.calls, ['revokeAppleAccessIfNeeded', 'deactivate', 'signOut']);
    });

    test('si cancela el diálogo de Apple no se desactiva la cuenta', () async {
      authRepo.revokeError = const AuthException(AuthFailure.cancelled);
      final result = await controller.deactivateAndSignOut(auth);
      expect(result, DeactivationResult.cancelled);
      expect(authRepo.calls, ['revokeAppleAccessIfNeeded']);
      verifyNever(() => repo.deactivate(any()));
    });

    test('otro error de revocación no bloquea la baja', () async {
      authRepo.revokeError = const AuthException(AuthFailure.unknown);
      final result = await controller.deactivateAndSignOut(auth);
      expect(result, DeactivationResult.done);
      expect(authRepo.calls, ['revokeAppleAccessIfNeeded', 'deactivate', 'signOut']);
    });
  });

  testWidgets('el texto de baja menciona el enlace de 8 días', (tester) async {
    final authRepo = FakeAuthRepository();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SubscriptionsController>(
              create: (_) => SubscriptionsController(_MockSubscriptionsRepository())),
          ChangeNotifierProvider<AuthController>(create: (_) => _authWith(authRepo)),
          ChangeNotifierProvider<AccountController>.value(value: controller),
        ],
        child: const MaterialApp(home: AccountPage()),
      ),
    );
    expect(find.textContaining('el enlace dura 8 días'), findsOneWidget);
  });

  group('AccountPage: baja', () {
    Future<void> runDeactivation(WidgetTester tester, FakeAuthRepository authRepo) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SubscriptionsController>(
                create: (_) => SubscriptionsController(_MockSubscriptionsRepository())),
            ChangeNotifierProvider<AuthController>(create: (_) => _authWith(authRepo)),
            ChangeNotifierProvider<AccountController>.value(value: controller),
          ],
          child: MaterialApp(
            home: Navigator(onGenerateRoute: (_) => MaterialPageRoute(builder: (_) => const AccountPage())),
          ),
        ),
      );
      await tester.tap(find.text('Borrar cuenta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Darse de baja'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar'));
      await tester.pumpAndSettle();
    }

    const failureText = 'No fue posible desactivar la cuenta. Intenta de nuevo.';

    testWidgets('cancelar el diálogo de Apple no muestra error ni llama al API', (tester) async {
      final authRepo = FakeAuthRepository()
        ..current = fakeUser(provider: 'apple.com')
        ..revokeError = const AuthException(AuthFailure.cancelled);
      await runDeactivation(tester, authRepo);
      expect(find.text(failureText), findsNothing);
      verifyNever(() => repo.deactivate(any()));
    });

    testWidgets('si la baja falla se muestra el aviso', (tester) async {
      when(() => repo.deactivate('token')).thenAnswer((_) async => false);
      await runDeactivation(tester, FakeAuthRepository());
      expect(find.text(failureText), findsOneWidget);
    });
  });
}
