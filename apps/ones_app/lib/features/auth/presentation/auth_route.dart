import 'auth_controller.dart';

enum AuthRoute { splash, verifyEmail, completeRegistration, login, home }

/// Pantalla raíz según el estado de sesión.
AuthRoute resolveAuthRoute(AuthController auth) {
  if (auth.isLoading && !auth.isSignedIn) return AuthRoute.splash;
  if (auth.needsEmailVerification) return AuthRoute.verifyEmail;
  if (!auth.isRegistered) {
    // Google/Apple completan el registro en la RegisterPage apilada desde el login;
    // las cuentas de correo llegan aquí tras verificar y no tienen pantalla apilada.
    return auth.user?.provider == 'password' ? AuthRoute.completeRegistration : AuthRoute.login;
  }
  return AuthRoute.home;
}
