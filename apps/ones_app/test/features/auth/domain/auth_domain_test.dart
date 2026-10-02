import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/features/auth/adapters/firebase/firebase_auth_failures.dart';
import 'package:ones_app/features/auth/domain/auth_failure.dart';
import 'package:ones_app/features/auth/domain/auth_user.dart';

void main() {
  group('AuthUser.needsEmailVerification', () {
    test('solo cuentas password sin verificar', () {
      const pending = AuthUser(userId: 'u', email: 'a@b.co', displayName: null, pictureUrl: null,
          provider: 'password', emailVerified: false);
      const verified = AuthUser(userId: 'u', email: 'a@b.co', displayName: null, pictureUrl: null,
          provider: 'password', emailVerified: true);
      const google = AuthUser(userId: 'u', email: 'a@b.co', displayName: null, pictureUrl: null,
          provider: 'google.com', emailVerified: false);

      expect(pending.needsEmailVerification, isTrue);
      expect(verified.needsEmailVerification, isFalse);
      expect(google.needsEmailVerification, isFalse);
    });
  });

  group('authFailureFromCode', () {
    test('credenciales inválidas', () {
      for (final code in ['wrong-password', 'invalid-credential', 'user-not-found', 'invalid-login-credentials']) {
        expect(authFailureFromCode(code), AuthFailure.invalidCredentials, reason: code);
      }
    });

    test('cancelaciones de Google, Apple y popup web', () {
      for (final code in ['canceled', 'cancelled', 'web-context-canceled', 'web-context-cancelled',
          'popup-closed-by-user', 'cancelled-popup-request']) {
        expect(authFailureFromCode(code), AuthFailure.cancelled, reason: code);
      }
    });

    test('resto de códigos conocidos y desconocidos', () {
      expect(authFailureFromCode('email-already-in-use'), AuthFailure.emailAlreadyInUse);
      expect(authFailureFromCode('weak-password'), AuthFailure.weakPassword);
      expect(authFailureFromCode('invalid-email'), AuthFailure.invalidEmail);
      expect(authFailureFromCode('user-disabled'), AuthFailure.userDisabled);
      expect(authFailureFromCode('account-exists-with-different-credential'),
          AuthFailure.accountExistsWithDifferentCredential);
      expect(authFailureFromCode('too-many-requests'), AuthFailure.tooManyRequests);
      expect(authFailureFromCode('popup-blocked'), AuthFailure.popupBlocked);
      expect(authFailureFromCode('user-token-expired'), AuthFailure.sessionExpired);
      expect(authFailureFromCode('unauthorized-domain'), AuthFailure.unauthorizedDomain);
      expect(authFailureFromCode('invalid-user-token'), AuthFailure.sessionExpired);
      expect(authFailureFromCode('network-request-failed'), AuthFailure.network);
      expect(authFailureFromCode('operation-not-allowed'), AuthFailure.unsupported);
      expect(authFailureFromCode('algo-nuevo'), AuthFailure.unknown);
    });
  });

  test('authFailureMessage: cancelado no tiene mensaje; el resto sí', () {
    expect(authFailureMessage(AuthFailure.cancelled), isEmpty);
    for (final f in AuthFailure.values.where((f) => f != AuthFailure.cancelled)) {
      expect(authFailureMessage(f), isNotEmpty, reason: f.name);
    }
  });
}
