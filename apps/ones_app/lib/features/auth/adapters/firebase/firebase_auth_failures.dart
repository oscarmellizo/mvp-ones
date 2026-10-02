import '../../domain/auth_failure.dart';

AuthFailure authFailureFromCode(String code) => switch (code) {
      'wrong-password' || 'invalid-credential' || 'user-not-found' || 'invalid-login-credentials' =>
        AuthFailure.invalidCredentials,
      'email-already-in-use' => AuthFailure.emailAlreadyInUse,
      'weak-password' => AuthFailure.weakPassword,
      'invalid-email' => AuthFailure.invalidEmail,
      'user-disabled' => AuthFailure.userDisabled,
      'account-exists-with-different-credential' || 'credential-already-in-use' =>
        AuthFailure.accountExistsWithDifferentCredential,
      'too-many-requests' => AuthFailure.tooManyRequests,
      'popup-blocked' => AuthFailure.popupBlocked,
      'user-token-expired' || 'invalid-user-token' => AuthFailure.sessionExpired,
      'network-request-failed' => AuthFailure.network,
      'canceled' ||
      'cancelled' ||
      'web-context-canceled' ||
      'web-context-cancelled' ||
      'popup-closed-by-user' ||
      'cancelled-popup-request' =>
        AuthFailure.cancelled,
      'operation-not-allowed' => AuthFailure.unsupported,
      _ => AuthFailure.unknown,
    };
