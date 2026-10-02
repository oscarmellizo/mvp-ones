import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ones_app/features/account/adapters/api/account_api_repository.dart';
import 'package:ones_app/features/account/presentation/account_controller.dart';

class _MockAccountApiRepository extends Mock implements AccountApiRepository {}

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
}
