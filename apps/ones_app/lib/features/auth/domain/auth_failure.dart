enum AuthFailure {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  userDisabled,
  accountExistsWithDifferentCredential,
  tooManyRequests,
  popupBlocked,
  sessionExpired,
  cancelled,
  network,
  unsupported,
  unknown,
}

class AuthException implements Exception {
  final AuthFailure failure;
  final String? detail;

  const AuthException(this.failure, [this.detail]);

  @override
  String toString() => 'AuthException(${failure.name}${detail != null ? ': $detail' : ''})';
}

/// Mensaje para el usuario. Cancelar no es un error y no muestra nada.
String authFailureMessage(AuthFailure failure) => switch (failure) {
      AuthFailure.invalidCredentials => 'Correo o contraseña incorrectos.',
      AuthFailure.emailAlreadyInUse =>
        'Ya existe una cuenta con este correo. Inicia sesión con Google o restablece tu contraseña.',
      AuthFailure.weakPassword => 'La contraseña debe tener al menos 8 caracteres.',
      AuthFailure.invalidEmail => 'El correo no es válido.',
      AuthFailure.userDisabled => 'Esta cuenta está deshabilitada.',
      AuthFailure.accountExistsWithDifferentCredential =>
        'Ya tienes una cuenta con este correo usando otro método. Entra con ese método (por ejemplo, Google).',
      AuthFailure.tooManyRequests => 'Demasiados intentos. Espera unos minutos e inténtalo de nuevo.',
      AuthFailure.popupBlocked =>
        'Tu navegador bloqueó la ventana de Google. Permite las ventanas emergentes de este sitio e inténtalo de nuevo.',
      AuthFailure.sessionExpired => 'Tu sesión expiró. Inicia sesión de nuevo.',
      AuthFailure.cancelled => '',
      AuthFailure.network => 'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
      AuthFailure.unsupported => 'Este método de inicio de sesión no está disponible en este dispositivo.',
      AuthFailure.unknown => 'No se pudo iniciar sesión. Inténtalo de nuevo.',
    };
