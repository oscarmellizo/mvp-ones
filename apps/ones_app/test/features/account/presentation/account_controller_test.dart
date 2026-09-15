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
}
