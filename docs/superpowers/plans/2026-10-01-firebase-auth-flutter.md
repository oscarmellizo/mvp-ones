# Firebase Auth — Flutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que `apps/ones_app` (iOS, Android y web, que es la misma app compilada para navegador y desplegada con `deploy-web-app.yml`) inicie sesión con Firebase Auth usando Google, correo/contraseña y Apple (solo iOS), con verificación de correo, recuperación de contraseña y reintento automático tras la migración de cuentas legadas del backend.

**Architecture:** Un único adaptador `FirebaseAuthRepository` implementa el puerto `AuthRepository`. `AuthController` conserva su API pública (la usan ~20 pantallas) y centraliza el flujo: sesión de Firebase → token → `GET /v1/users/me` (con manejo de 404, 409 `ACCOUNT_MIGRATED`, 403 `EMAIL_NOT_VERIFIED`, 409 `EMAIL_CONFLICT`). El router raíz decide la pantalla con una función pura `resolveAuthRoute`.

**Tech Stack:** Flutter 3.47 / Dart ≥3.6, `firebase_core ^4.15.0`, `firebase_auth ^6.7.0`, `google_sign_in ^7.2.0` (solo móvil), provider, dio, flutter_test + mocktail.

**Spec:** `docs/superpowers/specs/2026-09-19-firebase-auth-migration-design.md` (backend ya implementado: `docs/superpowers/plans/2026-10-01-firebase-auth-backend.md`).

## Global Constraints

- Proyecto Firebase único `ones-a96a7` para dev y prod. Web usa `FirebaseWebConfig` (`lib/core/config/firebase_web_config.dart`); iOS `ios/Runner/GoogleService-Info.plist` y Android `android/app/google-services.json` (ambos fuera de git, ya presentes).
- Bundle iOS `co.ones.onesapp`; `GIDClientID` = `403122779240-7e0p9b2rau3mkctg7s08ku1uql1ah0ii.apps.googleusercontent.com` (ya en `Info.plist`).
- Apple: solo iOS (`!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS`). Web: Google con `signInWithPopup`.
- Contraseña mínima: 8 caracteres.
- Web: Google con `signInWithPopup`, llamado sin `await` previo dentro del gesto del usuario (si no, el navegador bloquea la ventana). CloudFront ya envía `cross-origin-opener-policy: same-origin-allow-popups` en `app.` y `appdev.ones.events` (`infra/cloudformation/frontend/cloudfront.yml`), que es lo que requiere el popup. Dominios autorizados en Firebase: `app.ones.events`, `appdev.ones.events` (pendiente de agregar), `localhost`.
- Diseño: las pantallas nuevas usan el lenguaje visual existente, sin inventar otro: fondo `OnesColors.background` (ámbar `#FAB14E`), morado `purpleDeep #4A036E` / `purpleMid #5C036E`, esquinas rectas (`BorderRadius.zero`), títulos en LemonMilk vía `textTheme.headlineSmall` (se ven en mayúsculas), cuerpo con `bodyFallbacks`, campos con `OnesInputDecoration.build`, columna centrada de máx. 520 px. El elemento memorable sigue siendo la pila de fotos tipo polaroid; lo nuevo se mantiene sobrio.
- Códigos del API: 404 en `/v1/users/me` = no registrado; 409 `ACCOUNT_MIGRATED` = reintentar inicio de sesión una vez con la credencial de Google; 403 `EMAIL_NOT_VERIFIED`; 409 `EMAIL_CONFLICT`; 403 `ACCOUNT_DISABLED|ACCOUNT_CLOSED` (ya manejado por `AccountBlock`).
- API pública de `AuthController` que otras pantallas usan y NO cambia: `user`, `idToken`, `isLoading`, `error`, `preferredName`, `languagePreference`, `termsAccepted`, `isAdmin`, `isSignedIn`, `isRegistered`, `signIn()`, `signInExisting()`, `beginRegistration()`, `completeRegistration(...)`, `savePreferences(...)`, `savePreferredName(...)`, `lookupUserByEmail(...)`, `refreshIdToken()`, `logout()`, `clearGoogleSession()`, `restoreSessionIfPossible()`, `signOutBecauseAccountBlocked(...)`.
- Textos en español escritos en el widget, como el resto de pantallas de auth (no hay claves de traducción para estas pantallas).
- Desviaciones deliberadas del spec (más simples, mismo comportamiento): sin casos de uso pass-through (el controlador usa `AuthRepository` directo); sin `authStateChanges()` (no lo consume nadie); no se borra la clave vieja de SharedPreferences.
- Comandos (desde `apps/ones_app`): tests `flutter test <ruta>`; análisis `flutter analyze` (línea base: 226 issues, no subir errores). Línea base de `flutter test`: 23 pasan, 2 fallan antes de este plan (`test/features/events/application/list_events_use_case_test.dart` no compila; `test/core/utils/validators_test.dart` tumba el compilador). Esos 2 no son de este plan.

## Review Focus

- Segundo 409 `ACCOUNT_MIGRATED` después de reintentar: debe terminar en `failed` con mensaje, nunca en bucle. Test en Task 3.
- Usuario de correo que verifica, vuelve a la app y aún no completó el registro (nombre + términos): debe ver el formulario de registro, no el login. Test en Task 4 (`resolveAuthRoute`).
- Cancelar la hoja de Google/Apple: no debe mostrar error. Test en Task 3.
- 409 `EMAIL_CONFLICT` (Apple/correo con el correo de una cuenta Google existente): mensaje que indica entrar con Google y sesión de Firebase cerrada. Test en Task 3.
- Registro con Google de una cuenta que ya existe en Ones desde `RegisterPage` (pantalla apilada): debe llegar al Home, no quedar atrapado en la pantalla de registro. Test en Task 4 (widget).
- Usuario que verifica el correo en otra app/pestaña y vuelve: la app debe notarlo sola al volver, sin obligarlo a pulsar "Ya verifiqué". Test en Task 3 (`refreshEmailVerification`).

---

## File Structure

| Archivo | Responsabilidad |
|---|---|
| `pubspec.yaml`, `lib/main.dart`, `lib/core/config/firebase_web_config.dart` | dependencias e inicialización de Firebase |
| `ios/Runner/Runner.entitlements`, `ios/Runner.xcodeproj/project.pbxproj`, `web/index.html` | plataforma |
| `lib/features/auth/domain/auth_user.dart` | + `provider`, `emailVerified`, `needsEmailVerification` |
| `lib/features/auth/domain/auth_failure.dart` (nuevo) | `AuthFailure`, `AuthException`, `authFailureMessage` |
| `lib/features/auth/domain/auth_repository.dart` | puerto nuevo |
| `lib/features/auth/adapters/firebase/firebase_auth_failures.dart` (nuevo) | código de Firebase → `AuthFailure` |
| `lib/features/auth/adapters/firebase/firebase_auth_repository.dart` (nuevo) | adaptador |
| `lib/features/auth/presentation/auth_controller.dart` | flujo de sesión |
| `lib/features/auth/presentation/auth_route.dart` (nuevo) | `resolveAuthRoute` |
| `lib/features/auth/presentation/widgets/auth_buttons.dart`, `.../widgets/email_auth_section.dart`, `.../widgets/auth_error_banner.dart`, `.../widgets/polaroid_frame.dart` (nuevos) | UI compartida |
| `assets/auth/{google_g,apple_logo}.png` (+ `2.0x/`, `3.0x/`, `4.0x/`) (ya en el repo) | logos oficiales de Google y Apple |
| `lib/features/auth/presentation/pages/{login,register}_page.dart` | botones nuevos |
| `lib/features/auth/presentation/pages/{verify_email,forgot_password}_page.dart` (nuevos) | pantallas nuevas |
| `lib/app.dart` | cableado y router |
| `test/features/auth/fake_auth_repository.dart` (nuevo) | doble de pruebas |

Se eliminan: `lib/features/auth/adapters/google/google_auth_repository.dart`, `lib/features/auth/infrastructure/google_sign_in_initializer.dart`, `lib/features/auth/infrastructure/google_token_refresh_service.dart`, `lib/features/auth/presentation/google_sign_in_button.dart`, `..._stub.dart`, `..._web.dart`, `lib/features/auth/application/{get_id_token,sign_in_with_google,sign_out}_use_case.dart`.

---

### Task 1: Dependencias, inicialización de Firebase y plataforma

**Files:**
- Modify: `apps/ones_app/pubspec.yaml` (environment + dependencies)
- Modify: `apps/ones_app/lib/core/config/firebase_web_config.dart`
- Modify: `apps/ones_app/lib/main.dart`
- Create: `apps/ones_app/ios/Runner/Runner.entitlements`
- Modify: `apps/ones_app/ios/Runner.xcodeproj/project.pbxproj` (vía gem `xcodeproj`)
- Test: `apps/ones_app/test/core/config/firebase_web_config_test.dart`

**Interfaces:**
- Produces: `FirebaseWebConfig.options : FirebaseOptions`. Firebase inicializado antes de `runApp`.

- [ ] **Step 1: Dependencias.** En `pubspec.yaml`: `sdk: ^3.5.3` → `sdk: ^3.6.0`; en `dependencies`, debajo de `google_sign_in: ^7.2.0`:

```yaml
  firebase_core: ^4.15.0
  firebase_auth: ^6.7.0
```

Run: `flutter pub get`
Expected: `Got dependencies!` sin conflictos.

- [ ] **Step 2: Write the failing test** `test/core/config/firebase_web_config_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:ones_app/core/config/firebase_web_config.dart';

void main() {
  test('web options apuntan al proyecto ones-a96a7', () {
    final o = FirebaseWebConfig.options;

    expect(o.projectId, 'ones-a96a7');
    expect(o.authDomain, 'ones-a96a7.firebaseapp.com');
    expect(o.apiKey, startsWith('AIza'));
    expect(o.appId, startsWith('1:403122779240:web:'));
  });
}
```

Run: `flutter test test/core/config/firebase_web_config_test.dart`
Expected: FAIL de compilación, `Member not found: 'FirebaseWebConfig.options'`.

- [ ] **Step 3: Implement.** En `firebase_web_config.dart` añadir `import 'package:firebase_core/firebase_core.dart';` arriba y, al final de la clase:

```dart
  static FirebaseOptions get options => const FirebaseOptions(
        apiKey: apiKey,
        appId: appId,
        messagingSenderId: messagingSenderId,
        projectId: projectId,
        authDomain: authDomain,
        storageBucket: storageBucket,
      );
```

En `lib/main.dart`: imports `package:firebase_core/firebase_core.dart` y `core/config/firebase_web_config.dart`; justo después de `WidgetsFlutterBinding.ensureInitialized();`:

```dart
  // Móvil lee google-services.json / GoogleService-Info.plist; web necesita las opciones explícitas.
  await Firebase.initializeApp(options: kIsWeb ? FirebaseWebConfig.options : null);
```

Run: `flutter test test/core/config/firebase_web_config_test.dart`
Expected: PASS.

- [ ] **Step 4: iOS — plist en el target y capability de Apple.** Crear `ios/Runner/Runner.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.developer.applesignin</key>
	<array>
		<string>Default</string>
	</array>
</dict>
</plist>
```

Run (desde `apps/ones_app`):
```bash
GEM_HOME=/opt/homebrew/Cellar/cocoapods/1.17.0/libexec ruby -rxcodeproj -e '
p = Xcodeproj::Project.open("ios/Runner.xcodeproj")
t = p.targets.find { |x| x.name == "Runner" }
g = p.main_group["Runner"]
f = g.files.find { |x| x.path == "GoogleService-Info.plist" } || g.new_file("GoogleService-Info.plist")
t.resources_build_phase.add_file_reference(f, true)
g.files.find { |x| x.path == "Runner.entitlements" } || g.new_file("Runner.entitlements")
t.build_configurations.each { |c| c.build_settings["CODE_SIGN_ENTITLEMENTS"] = "Runner/Runner.entitlements" }
p.save'
grep -c 'GoogleService-Info.plist' ios/Runner.xcodeproj/project.pbxproj
grep -c 'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements' ios/Runner.xcodeproj/project.pbxproj
```
Expected: primer conteo `4` (file ref, build file, grupo, fase de recursos); segundo `3` (Debug, Release, Profile).

- [ ] **Step 5: Verify builds**

Run:
```bash
bash scripts/ios_config.sh prod --release > /dev/null && DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -showBuildSettings 2>/dev/null | grep -E ' CODE_SIGN_ENTITLEMENTS = '
flutter build web --release > /tmp/web-build.log 2>&1; tail -1 /tmp/web-build.log
flutter analyze 2>&1 | tail -1
```
Expected: `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements`; `✓ Built build/web`; issues ≤ 226 y sin `error •` nuevos.

- [ ] **Step 6: Commit** (sin `pubspec.lock`/`Podfile.lock` si solo traen ruido ajeno; sí incluirlos si añaden firebase)

```bash
git add apps/ones_app/pubspec.yaml apps/ones_app/pubspec.lock apps/ones_app/ios/Podfile.lock \
        apps/ones_app/lib/core/config/firebase_web_config.dart apps/ones_app/lib/main.dart \
        apps/ones_app/ios/Runner/Runner.entitlements apps/ones_app/ios/Runner.xcodeproj/project.pbxproj \
        apps/ones_app/test/core/config/firebase_web_config_test.dart
git commit -m "feat(app): inicializar Firebase y capability Sign in with Apple"
```

---

### Task 2: Dominio de auth y adaptador de Firebase

**Files:**
- Modify: `apps/ones_app/lib/features/auth/domain/auth_user.dart`
- Create: `apps/ones_app/lib/features/auth/domain/auth_failure.dart`
- Modify: `apps/ones_app/lib/features/auth/domain/auth_repository.dart`
- Create: `apps/ones_app/lib/features/auth/adapters/firebase/firebase_auth_failures.dart`
- Create: `apps/ones_app/lib/features/auth/adapters/firebase/firebase_auth_repository.dart`
- Test: `apps/ones_app/test/features/auth/domain/auth_domain_test.dart`

**Interfaces:**
- Produces:
  - `AuthUser({userId, email, displayName, pictureUrl, String provider = 'google.com', bool emailVerified = true})`, `bool get needsEmailVerification`.
  - `enum AuthFailure { invalidCredentials, emailAlreadyInUse, weakPassword, invalidEmail, userDisabled, accountExistsWithDifferentCredential, tooManyRequests, popupBlocked, cancelled, network, unsupported, unknown }`, `class AuthException(AuthFailure failure, [String? detail])`, `String authFailureMessage(AuthFailure)`.
  - `AuthRepository` con `currentUser()`, `signInWithGoogle()`, `signInWithApple()`, `signInWithEmail(email, password)`, `registerWithEmail(email, password)`, `sendEmailVerification()`, `reloadUser()`, `sendPasswordReset(email)`, `getIdToken({bool forceRefresh = false})`, `signInAgainAfterMigration()`, `signOut()`.
  - `AuthFailure authFailureFromCode(String code)`.
  - `FirebaseAuthRepository({FirebaseAuth? auth, required String? googleServerClientId})`.

Nota: tras este task `GoogleAuthRepository` deja de compilar contra el puerto nuevo; se elimina aquí mismo y `app.dart` se cablea en Task 3. Para que el árbol compile entre tasks, en este task `app.dart` pasa a construir `FirebaseAuthRepository` (ver Step 5).

- [ ] **Step 1: Write the failing test** `test/features/auth/domain/auth_domain_test.dart`:

```dart
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
```

Run: `flutter test test/features/auth/domain/auth_domain_test.dart`
Expected: FAIL de compilación (`firebase_auth_failures.dart` y `auth_failure.dart` no existen).

- [ ] **Step 2: Implement domain.** `auth_user.dart` completo:

```dart
class AuthUser {
  final String userId;
  final String? email;
  final String? displayName;
  final String? pictureUrl;

  /// Proveedor con el que se autenticó: google.com, apple.com o password.
  final String provider;
  final bool emailVerified;

  const AuthUser({
    required this.userId,
    required this.email,
    required this.displayName,
    required this.pictureUrl,
    this.provider = 'google.com',
    this.emailVerified = true,
  });

  /// Las cuentas de correo/contraseña deben verificar el correo antes de usar el API.
  bool get needsEmailVerification => provider == 'password' && !emailVerified;

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      userId: json['userId'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String? ?? json['name'] as String?,
      pictureUrl: json['pictureUrl'] as String? ?? json['picture'] as String?,
    );
  }
}
```

`auth_failure.dart`:

```dart
enum AuthFailure {
  invalidCredentials,
  emailAlreadyInUse,
  weakPassword,
  invalidEmail,
  userDisabled,
  accountExistsWithDifferentCredential,
  tooManyRequests,
  popupBlocked,
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
      AuthFailure.cancelled => '',
      AuthFailure.network => 'Sin conexión. Revisa tu internet e inténtalo de nuevo.',
      AuthFailure.unsupported => 'Este método de inicio de sesión no está disponible en este dispositivo.',
      AuthFailure.unknown => 'No se pudo iniciar sesión. Inténtalo de nuevo.',
    };
```

`auth_repository.dart` completo:

```dart
import 'auth_user.dart';

/// Errores: los métodos lanzan [AuthException] (ver auth_failure.dart).
abstract interface class AuthRepository {
  Future<AuthUser?> currentUser();

  Future<AuthUser> signInWithGoogle();

  /// Solo iOS; en otras plataformas lanza AuthException(AuthFailure.unsupported).
  Future<AuthUser> signInWithApple();

  Future<AuthUser> signInWithEmail(String email, String password);

  /// Crea la cuenta y envía el correo de verificación.
  Future<AuthUser> registerWithEmail(String email, String password);

  Future<void> sendEmailVerification();

  /// Recarga el usuario actual (p. ej. para leer emailVerified); null si no hay sesión.
  Future<AuthUser?> reloadUser();

  Future<void> sendPasswordReset(String email);

  Future<String?> getIdToken({bool forceRefresh = false});

  /// Tras 409 ACCOUNT_MIGRATED: vuelve a iniciar sesión con la última credencial de Google.
  Future<AuthUser> signInAgainAfterMigration();

  Future<void> signOut();
}
```

`adapters/firebase/firebase_auth_failures.dart`:

```dart
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
```

Run: `flutter test test/features/auth/domain/auth_domain_test.dart`
Expected: PASS.

- [ ] **Step 3: Adapter** `adapters/firebase/firebase_auth_repository.dart`:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../domain/auth_failure.dart';
import '../../domain/auth_repository.dart';
import '../../domain/auth_user.dart';
import 'firebase_auth_failures.dart';

class FirebaseAuthRepository implements AuthRepository {
  final FirebaseAuth _auth;

  /// Client OAuth web del proyecto: en Android define la audiencia del idToken de Google.
  final String? googleServerClientId;

  AuthCredential? _lastGoogleCredential;
  Future<void>? _googleInit;

  FirebaseAuthRepository({FirebaseAuth? auth, required this.googleServerClientId})
      : _auth = auth ?? FirebaseAuth.instance;

  @override
  Future<AuthUser?> currentUser() async {
    final u = _auth.currentUser;
    return u == null ? null : _toAuthUser(u);
  }

  @override
  Future<AuthUser> signInWithGoogle() => _guard(() async {
        if (kIsWeb) {
          // Sin awaits antes del popup: debe abrirse dentro del clic o el navegador lo bloquea.
          final result = await _auth.signInWithPopup(GoogleAuthProvider()..addScope('email'));
          _lastGoogleCredential = result.credential;
          return _toAuthUser(result.user!);
        }
        await _ensureGoogleInitialized();
        final account = await GoogleSignIn.instance.authenticate();
        final idToken = account.authentication.idToken;
        if (idToken == null || idToken.isEmpty) {
          throw const AuthException(AuthFailure.unknown, 'Google no devolvió idToken');
        }
        final credential = GoogleAuthProvider.credential(idToken: idToken);
        final result = await _auth.signInWithCredential(credential);
        _lastGoogleCredential = credential;
        return _toAuthUser(result.user!);
      });

  @override
  Future<AuthUser> signInWithApple() => _guard(() async {
        if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
          throw const AuthException(AuthFailure.unsupported);
        }
        final provider = AppleAuthProvider()
          ..addScope('email')
          ..addScope('name');
        final result = await _auth.signInWithProvider(provider);
        return _toAuthUser(result.user!);
      });

  @override
  Future<AuthUser> signInWithEmail(String email, String password) => _guard(() async {
        final result = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        return _toAuthUser(result.user!);
      });

  @override
  Future<AuthUser> registerWithEmail(String email, String password) => _guard(() async {
        final result = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
        await result.user!.sendEmailVerification(_actionCodeSettings());
        return _toAuthUser(result.user!);
      });

  @override
  Future<void> sendEmailVerification() => _guard(() async {
        await _auth.currentUser?.sendEmailVerification(_actionCodeSettings());
      });

  @override
  Future<AuthUser?> reloadUser() => _guard(() async {
        final current = _auth.currentUser;
        if (current == null) return null;
        await current.reload();
        final fresh = _auth.currentUser;
        return fresh == null ? null : _toAuthUser(fresh);
      });

  @override
  Future<void> sendPasswordReset(String email) =>
      _guard(() => _auth.sendPasswordResetEmail(email: email.trim(), actionCodeSettings: _actionCodeSettings()));

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    final u = _auth.currentUser;
    if (u == null) return null;
    return u.getIdToken(forceRefresh);
  }

  @override
  Future<AuthUser> signInAgainAfterMigration() => _guard(() async {
        final credential = _lastGoogleCredential;
        if (credential == null) {
          throw const AuthException(AuthFailure.unknown, 'Sin credencial de Google para reintentar');
        }
        await _auth.signOut();
        final result = await _auth.signInWithCredential(credential);
        return _toAuthUser(result.user!);
      });

  @override
  Future<void> signOut() async {
    _lastGoogleCredential = null;
    await _auth.signOut();
    if (!kIsWeb) {
      try {
        await _ensureGoogleInitialized();
        // disconnect obliga a elegir cuenta la próxima vez (comportamiento anterior).
        await GoogleSignIn.instance.disconnect();
      } catch (_) {
        // Best-effort.
      }
    }
  }

  /// En web, el botón "Continuar" de la página de Firebase devuelve al usuario a la app
  /// (el dominio debe estar autorizado en Firebase). En móvil se usa la página por defecto.
  static ActionCodeSettings? _actionCodeSettings() =>
      kIsWeb ? ActionCodeSettings(url: Uri.base.origin) : null;

  Future<void> _ensureGoogleInitialized() {
    final serverClientId = googleServerClientId?.trim();
    return _googleInit ??= GoogleSignIn.instance.initialize(
      serverClientId: (serverClientId == null || serverClientId.isEmpty) ? null : serverClientId,
    );
  }

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on FirebaseAuthException catch (e) {
      throw AuthException(authFailureFromCode(e.code), e.message);
    } on GoogleSignInException catch (e) {
      throw AuthException(
        e.code == GoogleSignInExceptionCode.canceled ? AuthFailure.cancelled : AuthFailure.unknown,
        e.description,
      );
    }
  }

  static AuthUser _toAuthUser(User u) {
    final providers = u.providerData.map((p) => p.providerId).toSet();
    final provider = providers.contains('google.com')
        ? 'google.com'
        : providers.contains('apple.com')
            ? 'apple.com'
            : 'password';
    return AuthUser(
      userId: u.uid,
      email: u.email,
      displayName: u.displayName,
      pictureUrl: u.photoURL,
      provider: provider,
      emailVerified: u.emailVerified,
    );
  }
}
```

- [ ] **Step 4: Remove the old adapter** `lib/features/auth/adapters/google/google_auth_repository.dart` (`git rm`).

- [ ] **Step 5: Keep the tree compiling.** En `lib/app.dart`: reemplazar `import 'features/auth/adapters/google/google_auth_repository.dart';` por `import 'features/auth/adapters/firebase/firebase_auth_repository.dart';` y

```dart
    final authRepository =
        GoogleAuthRepository(webClientId: config.googleWebClientId);
```
por
```dart
    final authRepository =
        FirebaseAuthRepository(googleServerClientId: config.googleWebClientId);
```

Los use cases `SignInWithGoogleUseCase`/`SignOutUseCase`/`GetIdTokenUseCase` siguen compilando (llaman métodos que existen en el puerto nuevo; `getIdToken()` usa el parámetro opcional).

Run: `flutter analyze lib 2>&1 | grep -E 'error •' | head; flutter test test/features/auth`
Expected: sin líneas `error •`; tests de auth PASS.

- [ ] **Step 6: Commit**

```bash
git add -A apps/ones_app/lib/features/auth apps/ones_app/lib/app.dart apps/ones_app/test/features/auth/domain
git commit -m "feat(app): adaptador FirebaseAuthRepository y errores de autenticación"
```

---

### Task 3: `AuthController` sobre Firebase

**Files:**
- Modify: `apps/ones_app/lib/features/auth/presentation/auth_controller.dart` (reescritura)
- Modify: `apps/ones_app/lib/app.dart` (construcción del controlador)
- Modify: `apps/ones_app/lib/features/auth/presentation/pages/login_page.dart`, `register_page.dart` (quitar `warmUpGoogleSignIn`)
- Delete: `lib/features/auth/application/{get_id_token,sign_in_with_google,sign_out}_use_case.dart`, `lib/features/auth/infrastructure/google_token_refresh_service.dart`
- Create: `apps/ones_app/test/features/auth/fake_auth_repository.dart`
- Modify: `apps/ones_app/test/features/auth/presentation/auth_controller_test.dart`

**Interfaces:**
- Consumes: `AuthRepository`, `AuthUser`, `AuthException`, `authFailureMessage` (Task 2).
- Produces: `AuthController({required AuthRepository authRepository, required EnsureUserUseCase ensureUser, required GetUserPreferencesUseCase getUserPreferences, required UpdateUserPreferencesUseCase updateUserPreferences, required LookupUserByEmailUseCase lookupUserByEmailUseCase, required GetAdminMeUseCase getAdminMe})`; `enum AuthNextStep { signedIn, needsRegistration, needsEmailVerification, failed }`; nuevos: `bool needsEmailVerification`, `signInWithGoogle()`, `signInWithApple()`, `signInWithEmail(email, password)`, `registerWithEmail(email, password)`, `beginRegistrationWithApple()`, `confirmEmailVerified()` → `Future<AuthNextStep>`; `refreshEmailVerification()` → `Future<void>` (silencioso, para cuando la app vuelve a primer plano); `resendEmailVerification()`, `sendPasswordReset(email)` → `Future<bool>`. Se elimina `warmUpGoogleSignIn()`.

- [ ] **Step 1: Test double** `test/features/auth/fake_auth_repository.dart`:

```dart
import 'package:ones_app/features/auth/domain/auth_failure.dart';
import 'package:ones_app/features/auth/domain/auth_repository.dart';
import 'package:ones_app/features/auth/domain/auth_user.dart';

AuthUser fakeUser({String id = 'uid-1', String provider = 'google.com', bool verified = true}) => AuthUser(
      userId: id,
      email: '$id@example.com',
      displayName: 'Ana Pérez',
      pictureUrl: null,
      provider: provider,
      emailVerified: verified,
    );

class FakeAuthRepository implements AuthRepository {
  AuthUser? current;
  AuthUser signInResult = fakeUser();
  AuthException? signInError;
  AuthUser? afterMigration;
  AuthUser? afterReload;
  String token = 'token-1';
  int signOutCalls = 0;
  int verificationEmails = 0;
  int migrationRetries = 0;
  final List<String> passwordResets = [];
  final List<bool> tokenRequests = [];

  Future<AuthUser> _signIn() async {
    final error = signInError;
    if (error != null) throw error;
    current = signInResult;
    return signInResult;
  }

  @override
  Future<AuthUser?> currentUser() async => current;

  @override
  Future<AuthUser> signInWithGoogle() => _signIn();

  @override
  Future<AuthUser> signInWithApple() => _signIn();

  @override
  Future<AuthUser> signInWithEmail(String email, String password) => _signIn();

  @override
  Future<AuthUser> registerWithEmail(String email, String password) async {
    final user = await _signIn();
    verificationEmails++;
    return user;
  }

  @override
  Future<void> sendEmailVerification() async => verificationEmails++;

  @override
  Future<AuthUser?> reloadUser() async => current = afterReload ?? current;

  @override
  Future<void> sendPasswordReset(String email) async {
    final error = signInError;
    if (error != null) throw error;
    passwordResets.add(email);
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) async {
    tokenRequests.add(forceRefresh);
    return current == null ? null : token;
  }

  @override
  Future<AuthUser> signInAgainAfterMigration() async {
    migrationRetries++;
    current = afterMigration ?? current;
    return current!;
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
    current = null;
  }
}
```

- [ ] **Step 2: Write the failing tests** — reemplazar `test/features/auth/presentation/auth_controller_test.dart` completo:

```dart
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
}
```

Run: `flutter test test/features/auth/presentation/auth_controller_test.dart`
Expected: FAIL de compilación (`No named parameter with the name 'authRepository'`).

- [ ] **Step 3: Rewrite `auth_controller.dart`** completo:

```dart
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../domain/auth_failure.dart';
import '../domain/auth_repository.dart';
import '../domain/auth_user.dart';
import '../../users/application/ensure_user_use_case.dart';
import '../../users/domain/users_repository.dart';
import '../../admin/application/get_admin_me_use_case.dart';

enum AuthNextStep {
  signedIn,
  needsRegistration,
  needsEmailVerification,
  failed,
}

class AuthController extends ChangeNotifier {
  final AuthRepository authRepository;
  final EnsureUserUseCase ensureUser;
  final GetUserPreferencesUseCase getUserPreferences;
  final UpdateUserPreferencesUseCase updateUserPreferences;
  final LookupUserByEmailUseCase lookupUserByEmailUseCase;
  final GetAdminMeUseCase getAdminMe;

  AuthUser? _user;
  String? _idToken;
  String? _preferredName;
  String? _languagePreference;
  bool _termsAccepted = false;
  bool _isAdmin = false;
  bool _isRegistered = false;
  bool _needsEmailVerification = false;
  bool _isLoading = false;
  Object? _error;

  Future<void>? _restoreInFlight;
  Future<AuthNextStep>? _signInInFlight;

  AuthController({
    required this.authRepository,
    required this.ensureUser,
    required this.getUserPreferences,
    required this.updateUserPreferences,
    required this.lookupUserByEmailUseCase,
    required this.getAdminMe,
  });

  AuthUser? get user => _user;
  String? get idToken => _idToken;
  String? get preferredName => _preferredName;
  String? get languagePreference => _languagePreference;
  bool get termsAccepted => _termsAccepted;
  bool get isAdmin => _isAdmin;
  bool get isSignedIn => _user != null;
  bool get isRegistered => _isRegistered;
  bool get needsEmailVerification => _needsEmailVerification;
  bool get isLoading => _isLoading;
  Object? get error => _error;

  Future<void> signIn() async {
    await signInExisting();
  }

  /// Compatibilidad: login e invitaciones usan este nombre para Google.
  Future<AuthNextStep> signInExisting() => signInWithGoogle();

  Future<AuthNextStep> signInWithGoogle() => _signIn(authRepository.signInWithGoogle);

  Future<AuthNextStep> signInWithApple() => _signIn(authRepository.signInWithApple);

  Future<AuthNextStep> signInWithEmail(String email, String password) =>
      _signIn(() => authRepository.signInWithEmail(email, password));

  Future<AuthNextStep> registerWithEmail(String email, String password) =>
      _signIn(() => authRepository.registerWithEmail(email, password));

  /// Registro con Google: si la cuenta ya existe en Ones devuelve signedIn.
  Future<AuthNextStep> beginRegistration() => signInWithGoogle();

  Future<AuthNextStep> beginRegistrationWithApple() => signInWithApple();

  Future<void> restoreSessionIfPossible() async {
    final existing = _restoreInFlight;
    if (existing != null) {
      await existing;
      return;
    }
    final f = _restoreSessionInternal();
    _restoreInFlight = f;
    try {
      await f;
    } finally {
      _restoreInFlight = null;
    }
  }

  Future<void> _restoreSessionInternal() async {
    var current = await authRepository.currentUser();
    if (current == null) return;

    _setLoading(true);
    try {
      _error = null;
      if (current.needsEmailVerification) {
        // Pudo verificar desde el correo mientras la app estaba cerrada.
        current = await authRepository.reloadUser() ?? current;
      }
      _user = current;
      final step = await _loadSession();
      // Google/Apple sin registro vuelven al login (como antes); correo sigue al formulario de registro.
      if (step == AuthNextStep.needsRegistration && current!.provider != 'password') {
        _clearSession();
      }
    } catch (e) {
      _error = _formatDioOrRawError(e);
      _clearSession();
    } finally {
      _setLoading(false);
    }
  }

  Future<AuthNextStep> _signIn(Future<AuthUser> Function() action) {
    return _signInInFlight ??= _runSignIn(action).whenComplete(() => _signInInFlight = null);
  }

  Future<AuthNextStep> _runSignIn(Future<AuthUser> Function() action) async {
    _setLoading(true);
    try {
      _error = null;
      _user = await action();
      return await _loadSession();
    } on AuthException catch (e) {
      _clearSession();
      _error = e.failure == AuthFailure.cancelled ? null : authFailureMessage(e.failure);
      return AuthNextStep.failed;
    } catch (e) {
      if (_errorCode(e) == 'EMAIL_CONFLICT') {
        await _safeSignOut();
      }
      _clearSession();
      _error = _formatDioOrRawError(e);
      return AuthNextStep.failed;
    } finally {
      _setLoading(false);
    }
  }

  /// Con [_user] autenticado en Firebase, decide el siguiente paso consultando el API.
  Future<AuthNextStep> _loadSession() async {
    if (_user!.needsEmailVerification) {
      _needsEmailVerification = true;
      _isRegistered = false;
      return AuthNextStep.needsEmailVerification;
    }
    _needsEmailVerification = false;

    final token = await _requireToken();
    try {
      return await _loadPreferences(token);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final code = _errorCode(e);
      if (status == 409 && code == 'ACCOUNT_MIGRATED') {
        // El backend reasignó la cuenta al uid legado: se entra de nuevo con la misma credencial.
        // Un segundo ACCOUNT_MIGRATED se propaga como error (sin bucle).
        _user = await authRepository.signInAgainAfterMigration();
        return await _loadPreferences(await _requireToken(forceRefresh: true));
      }
      if (status == 403 && code == 'EMAIL_NOT_VERIFIED') {
        _needsEmailVerification = true;
        return AuthNextStep.needsEmailVerification;
      }
      rethrow;
    }
  }

  Future<AuthNextStep> _loadPreferences(String token) async {
    try {
      final prefs = await getUserPreferences.execute(token);
      _preferredName = prefs?.preferredName;
      final lp = prefs?.languagePreference;
      _languagePreference = (lp != null && lp.trim().isNotEmpty) ? lp.trim().toLowerCase() : 'es';
      _termsAccepted = prefs?.termsAccepted ?? false;
      _isAdmin = await _safeLoadIsAdmin(token);
      _isRegistered = true;
      return AuthNextStep.signedIn;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        _preferredName = null;
        _languagePreference = null;
        _termsAccepted = false;
        _isAdmin = false;
        _isRegistered = false;
        return AuthNextStep.needsRegistration;
      }
      rethrow;
    }
  }

  Future<String> _requireToken({bool forceRefresh = false}) async {
    final token = await authRepository.getIdToken(forceRefresh: forceRefresh);
    if (token == null || token.isEmpty) {
      throw StateError('Missing idToken');
    }
    _idToken = token;
    return token;
  }

  /// "Ya verifiqué": recarga el usuario y, si está verificado, continúa con un token nuevo.
  Future<AuthNextStep> confirmEmailVerified() async {
    _setLoading(true);
    try {
      _error = null;
      final user = await authRepository.reloadUser();
      if (user == null) {
        _clearSession();
        return AuthNextStep.failed;
      }
      _user = user;
      if (user.needsEmailVerification) {
        _error = 'Aún no vemos tu correo verificado. Abre el enlace que te enviamos y vuelve a intentarlo.';
        return AuthNextStep.needsEmailVerification;
      }
      // El token anterior no trae email_verified=true.
      await _requireToken(forceRefresh: true);
      return await _loadSession();
    } on AuthException catch (e) {
      _error = authFailureMessage(e.failure);
      return AuthNextStep.failed;
    } catch (e) {
      _error = _formatDioOrRawError(e);
      return AuthNextStep.failed;
    } finally {
      _setLoading(false);
    }
  }

  /// Revisión silenciosa al volver a la app: si ya verificó, continúa; si no, no muestra nada.
  Future<void> refreshEmailVerification() async {
    if (!_needsEmailVerification || _isLoading) return;
    try {
      final user = await authRepository.reloadUser();
      if (user == null || user.needsEmailVerification) return;
      _user = user;
      await _requireToken(forceRefresh: true);
      await _loadSession();
      notifyListeners();
    } catch (_) {
      // El botón "Ya verifiqué" muestra el error si el usuario lo intenta a mano.
    }
  }

  Future<bool> resendEmailVerification() async {
    try {
      _error = null;
      await authRepository.sendEmailVerification();
      return true;
    } on AuthException catch (e) {
      _error = authFailureMessage(e.failure);
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPasswordReset(String email) async {
    try {
      _error = null;
      await authRepository.sendPasswordReset(email);
      return true;
    } on AuthException catch (e) {
      _error = authFailureMessage(e.failure);
      notifyListeners();
      return false;
    }
  }

  Future<void> completeRegistration(
    String preferredName, {
    bool termsAccepted = false,
  }) async {
    final token = _idToken;
    if (token == null || token.isEmpty) {
      throw StateError('Missing idToken');
    }

    final trimmed = preferredName.trim();
    if (trimmed.isEmpty) {
      throw StateError('Preferred name is required');
    }

    _setLoading(true);
    try {
      _error = null;
      await ensureUser.execute(token);
      final lang = _languagePreference ?? 'es';
      final updated = await updateUserPreferences.execute(token, trimmed, lang, termsAccepted);
      _preferredName = (updated?.preferredName ?? trimmed).trim();
      _languagePreference = (updated?.languagePreference ?? lang).trim().toLowerCase();
      _termsAccepted = updated?.termsAccepted ?? termsAccepted;
      _isAdmin = await _safeLoadIsAdmin(token);
      _isRegistered = true;
    } catch (e) {
      _error = _formatDioOrRawError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> savePreferredName(String value) async {
    await savePreferences(preferredName: value, languagePreference: null);
  }

  Future<void> savePreferences({
    required String preferredName,
    required String? languagePreference,
  }) async {
    final token = _idToken;
    if (token == null || token.isEmpty) return;

    final pn = preferredName.trim();
    if (pn.isEmpty) {
      throw StateError('Preferred name is required');
    }

    final lang = (languagePreference ?? _languagePreference ?? 'es').trim();
    if (lang.isEmpty) {
      throw StateError('Language preference is required');
    }

    _setLoading(true);
    try {
      _error = null;
      final updated = await updateUserPreferences.execute(token, pn, lang, _termsAccepted);
      _preferredName = updated?.preferredName ?? pn;
      _languagePreference = (updated?.languagePreference ?? lang).trim().toLowerCase();
      _termsAccepted = updated?.termsAccepted ?? _termsAccepted;
    } catch (e) {
      _error = e;
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<UserLookup?> lookupUserByEmail(String email) async {
    final token = _idToken;
    if (token == null || token.isEmpty) return null;
    return lookupUserByEmailUseCase.execute(token, email);
  }

  /// Usado por el interceptor 401 de OnesApiFactory.
  Future<String?> refreshIdToken() async {
    try {
      final token = await authRepository.getIdToken(forceRefresh: true);
      if (token == null || token.isEmpty) return null;
      _idToken = token;
      if (_isRegistered) {
        _isAdmin = await _safeLoadIsAdmin(token);
      }
      notifyListeners();
      return token;
    } catch (_) {
      return null;
    }
  }

  /// "Intentar con otra cuenta" en el login.
  Future<void> clearGoogleSession() async {
    await _safeSignOut();
    _clearSession();
    notifyListeners();
  }

  Future<void>? _accountBlockedSignOutInFlight;

  /// Cierra la sesión porque el API rechazó la cuenta (ACCOUNT_DISABLED / ACCOUNT_CLOSED)
  /// y deja un mensaje en [error] para que la pantalla de login lo muestre.
  Future<void> signOutBecauseAccountBlocked(String code) {
    return _accountBlockedSignOutInFlight ??= _doSignOutBecauseAccountBlocked(code).whenComplete(() {
      _accountBlockedSignOutInFlight = null;
    });
  }

  Future<void> _doSignOutBecauseAccountBlocked(String code) async {
    await logout();
    _error = code == 'ACCOUNT_CLOSED'
        ? 'Tu cuenta fue cerrada porque pasaron más de 30 días desde su desactivación.'
        : 'Tu cuenta está desactivada. Vuelve a iniciar sesión para reactivarla.';
    notifyListeners();
  }

  Future<void> logout() async {
    _setLoading(true);
    try {
      _error = null;
      await authRepository.signOut();
    } catch (e) {
      _error = e;
    } finally {
      _clearSession();
      _setLoading(false);
    }
  }

  Future<void> _safeSignOut() async {
    try {
      await authRepository.signOut();
    } catch (_) {}
  }

  void _clearSession() {
    _user = null;
    _idToken = null;
    _preferredName = null;
    _languagePreference = null;
    _termsAccepted = false;
    _isAdmin = false;
    _isRegistered = false;
    _needsEmailVerification = false;
  }

  static String? _errorCode(Object e) {
    if (e is! DioException) return null;
    final data = e.response?.data;
    return data is Map ? data['code']?.toString() : null;
  }

  Object _formatDioOrRawError(Object e) {
    if (e is DioException) {
      if (_errorCode(e) == 'EMAIL_CONFLICT') {
        return 'Ya existe una cuenta de Ones con este correo. Entra con Google.';
      }
      final status = e.response?.statusCode;
      final data = e.response?.data;
      if (data is Map) {
        final code = data['code'] ?? data['error'];
        final msg = data['message'];
        return 'HTTP $status ${code ?? ''} ${msg ?? ''}'.trim();
      } else if (data is String && data.trim().isNotEmpty) {
        return 'HTTP $status ${data.trim()}'.trim();
      } else {
        return 'HTTP $status ${e.message ?? 'Request failed'}'.trim();
      }
    }
    if (e is AuthException) return authFailureMessage(e.failure);
    return e;
  }

  Future<bool> _safeLoadIsAdmin(String token) async {
    try {
      return await getAdminMe.execute(token);
    } catch (_) {
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
```

- [ ] **Step 4: Wiring.** En `lib/app.dart`:
  - Quitar imports de `get_id_token_use_case.dart`, `sign_in_with_google_use_case.dart`, `sign_out_use_case.dart`, `google_token_refresh_service.dart`.
  - Quitar las líneas que crean `tokenRefreshService`, `signInWithGoogle`, `signOut`, `getIdToken`.
  - En el `ChangeNotifierProvider` reemplazar los argumentos del constructor por:

```dart
            final ctrl = AuthController(
              authRepository: authRepository,
              ensureUser: ensureUser,
              getUserPreferences: getUserPreferences,
              updateUserPreferences: updateUserPreferences,
              lookupUserByEmailUseCase: lookupUserByEmail,
              getAdminMe: getAdminMe,
            );
```

  - En `login_page.dart` y `register_page.dart`: borrar cada llamada `...warmUpGoogleSignIn();` (login: el `addPostFrameCallback` completo de `initState` que solo hace eso; register: la línea `auth.warmUpGoogleSignIn();` y su `if (kIsWeb) { ... }`).
  - `git rm` de `lib/features/auth/application/get_id_token_use_case.dart`, `sign_in_with_google_use_case.dart`, `sign_out_use_case.dart`, `lib/features/auth/infrastructure/google_token_refresh_service.dart`.

- [ ] **Step 5: Run tests**

Run: `flutter test test/features/auth && flutter analyze lib 2>&1 | grep -E 'error •' | head`
Expected: todos PASS (24 en `auth_controller_test.dart` + 4 de dominio); sin `error •`.

- [ ] **Step 6: Commit**

```bash
git add -A apps/ones_app/lib apps/ones_app/test/features/auth
git commit -m "feat(app): AuthController sobre Firebase (correo, Apple, verificación y migración)"
```

---

### Task 4: Pantallas, componentes de diseño y router

**Dirección de diseño (aplica a todo el task).** Las pantallas de auth ya tienen identidad: fondo ámbar, morado profundo, títulos LemonMilk en mayúsculas, esquinas rectas y la pila de fotos tipo polaroid como elemento memorable. No se agrega otro protagonista. Decisiones:

- **Primera pantalla sin ruido.** El login sigue mostrando logo, título, polaroids y los botones de proveedor. El correo es un tercer botón ("Continuar con correo") que al tocarlo despliega el formulario en el mismo lugar (`AnimatedSize`, 220 ms, sin animación si el sistema pide reducir movimiento). Así el formulario no empuja todo hacia abajo para quien entra con Google.
- **Botones de proveedor como una familia.** Mismo alto (mín. 54), ancho completo, esquinas rectas, logo a la izquierda del texto con 12 px de separación: Google blanco con borde `#747775` y su "G" oficial de 20 px (hoy el ícono de FontAwesome sale como un cuadro vacío en web); Apple negro con su logo oficial blanco de 22 px de alto (solo iOS). Los logos salen de los kits oficiales (Google Sign-In Branding y Apple "Sign in with Apple" Left-aligned White) y están en el repo en 1x–4x, así que Flutter elige la densidad exacta y se ven nítidos incluso con zoom al 200 % en pantallas Retina; no se dibujan con fuentes de íconos ni se recolorean. correo con fondo transparente y borde morado. La acción principal de cada formulario es el morado lleno (`purpleMid`), como el botón "Crear cuenta" existente.
- **Polaroid como lenguaje, no como adorno nuevo.** Las pantallas de verificación y de contraseña enviada usan un marco polaroid (mismo blanco, sombra y leve giro que la pila del login) con el ícono del sobre y, en el pie de foto, el correo del usuario.
- **Errores legibles.** El rojo `danger` sobre ámbar tiene poco contraste: el aviso de error pasa a texto negro sobre blanco translúcido con una barra roja a la izquierda, sin el prefijo "Error:".
- **Textos.** Verbo claro y consistente: "Continuar con Google/Apple/correo", "Iniciar sesión", "Crear cuenta", "Olvidé mi contraseña", "Enviar enlace", "Ya verifiqué mi correo", "Reenviar enlace", "Usar otra cuenta". Los errores dicen qué pasó y qué hacer.
- **Calidad mínima.** Alturas mínimas (no fijas) para no cortar texto con tamaño de letra grande; foco de teclado visible (botones Material); `autofillHints` y `AutofillGroup` para que el gestor de contraseñas funcione; íconos decorativos fuera de la semántica; aviso de error como `liveRegion`.

**Files:**
- Create: `apps/ones_app/lib/features/auth/presentation/auth_route.dart`
- Create: `apps/ones_app/lib/features/auth/presentation/widgets/auth_buttons.dart`
- Create: `apps/ones_app/lib/features/auth/presentation/widgets/email_auth_section.dart`
- Create: `apps/ones_app/lib/features/auth/presentation/widgets/auth_error_banner.dart`
- Create: `apps/ones_app/lib/features/auth/presentation/widgets/polaroid_frame.dart`
- Create: `apps/ones_app/lib/features/auth/presentation/pages/verify_email_page.dart`
- Create: `apps/ones_app/lib/features/auth/presentation/pages/forgot_password_page.dart`
- Modify: `apps/ones_app/lib/features/auth/presentation/pages/login_page.dart`
- Modify: `apps/ones_app/lib/features/auth/presentation/pages/register_page.dart`
- Modify: `apps/ones_app/lib/app.dart` (`_RootRouterState.build`)
- Delete: `lib/features/auth/infrastructure/google_sign_in_initializer.dart`, `lib/features/auth/presentation/google_sign_in_button.dart`, `google_sign_in_button_stub.dart`, `google_sign_in_button_web.dart`
- Test: `apps/ones_app/test/features/auth/presentation/auth_route_test.dart`, `.../auth_pages_test.dart`

**Interfaces:**
- Consumes: `AuthController` (Task 3, incl. `refreshEmailVerification`), `FakeAuthRepository`/`fakeUser` (Task 3).
- Produces: `enum AuthRoute { splash, verifyEmail, completeRegistration, login, home }`, `AuthRoute resolveAuthRoute(AuthController auth)`; `bool get appleSignInAvailable`; `AuthOptionButton`, `GoogleSignInButton({required bool busy, required VoidCallback? onPressed})`, `AppleSignInButton({required VoidCallback? onPressed})`; `EmailAuthSection({required String toggleLabel, required String submitLabel, required bool busy, bool isRegistration = false, Widget? footer, required Future<void> Function(String email, String password) onSubmit})`; `AuthErrorBanner({required String message})`; `PolaroidFrame({required Widget child, Widget? caption, double angle = -0.035, double width = 260})`; páginas `VerifyEmailPage()`, `ForgotPasswordPage()`. Keys: `auth.google`, `auth.apple`, `auth.emailToggle`, `auth.email`, `auth.password`, `auth.submit`, `auth.forgot`, `verify.email`, `verify.confirm`, `verify.resend`, `verify.logout`, `forgot.email`, `forgot.send`, `forgot.sent`, `forgot.back`.

- [ ] **Step 1: Logos (ya en el repo).** Verificar que existan y no modificarlos:

```bash
for n in google_g apple_logo; do ls assets/auth/$n.png assets/auth/2.0x/$n.png assets/auth/3.0x/$n.png assets/auth/4.0x/$n.png; done
```
Expected: 8 archivos. `google_g` es 20×20 en 1x (recorte exacto de la "G" del PNG oficial `Theme=Light, Show text=No, Shape=Square`); `apple_logo` es 20×24 en 1x (glifo oficial de 22 px de alto con 1 px transparente por lado, del SVG `Logo - SIWA - Left-aligned - White - Medium`). `assets/auth/` ya está en `pubspec.yaml`; las carpetas `N.0x/` las resuelve Flutter solo.

- [ ] **Step 2: Write the failing route test** `test/features/auth/presentation/auth_route_test.dart`:

```dart
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
}
```

Run: `flutter test test/features/auth/presentation/auth_route_test.dart`
Expected: FAIL de compilación (`auth_route.dart` no existe).

- [ ] **Step 3: Implement** `auth_route.dart`:

```dart
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
```

Run: `flutter test test/features/auth/presentation/auth_route_test.dart`
Expected: PASS (6).

- [ ] **Step 4: Router.** En `lib/app.dart`, `_RootRouterState.build`, reemplazar desde `if (auth.isLoading && !auth.isSignedIn) {` hasta `return const LoginPage();\n    }` por:

```dart
    switch (resolveAuthRoute(auth)) {
      case AuthRoute.splash:
        return const SplashPage();
      case AuthRoute.verifyEmail:
        return const VerifyEmailPage();
      case AuthRoute.completeRegistration:
        return const RegisterPage(popToRootOnComplete: false);
      case AuthRoute.login:
        return const LoginPage();
      case AuthRoute.home:
        break;
    }
```

Imports: `features/auth/presentation/auth_route.dart`, `features/auth/presentation/pages/verify_email_page.dart`, `features/auth/presentation/pages/register_page.dart`.

- [ ] **Step 5: Componentes.** `widgets/auth_buttons.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/ones_typography.dart';

/// Sign in with Apple solo se ofrece en iOS.
bool get appleSignInAvailable => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

/// Botón de método de acceso: todos comparten alto, ancho y esquinas rectas;
/// solo cambian fondo, borde y logo.
class AuthOptionButton extends StatelessWidget {
  final Widget logo;
  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color foreground;
  final Color border;

  const AuthOptionButton({
    super.key,
    required this.logo,
    required this.label,
    required this.onPressed,
    required this.background,
    required this.foreground,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        backgroundColor: background,
        foregroundColor: foreground,
        disabledBackgroundColor: background,
        disabledForegroundColor: foreground.withOpacity(0.5),
        side: BorderSide(color: border, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        textStyle: const TextStyle(
          fontFamilyFallback: OnesTypography.bodyFallbacks,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ExcludeSemantics(child: SizedBox.square(dimension: 24, child: Center(child: logo))),
          const SizedBox(width: 12),
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ],
      ),
    );
  }
}

class GoogleSignInButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;

  const GoogleSignInButton({super.key, required this.busy, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AuthOptionButton(
      key: const Key('auth.google'),
      // Logo oficial sin modificar; borde y colores según las guías de marca de Google.
      logo: Image.asset('assets/auth/google_g.png', width: 20, height: 20, filterQuality: FilterQuality.medium),
      label: busy ? 'Conectando...' : 'Continuar con Google',
      onPressed: onPressed,
      background: OnesColors.white,
      foreground: const Color(0xFF1F1F1F),
      border: const Color(0xFF747775),
    );
  }
}

class AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AppleSignInButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AuthOptionButton(
      key: const Key('auth.apple'),
      // Logo oficial de Apple (no el ícono de Material): lo exige la guía de Sign in with Apple.
      logo: Image.asset('assets/auth/apple_logo.png', width: 20, height: 24, filterQuality: FilterQuality.medium),
      label: 'Continuar con Apple',
      onPressed: onPressed,
      background: OnesColors.black,
      foreground: OnesColors.white,
      border: OnesColors.black,
    );
  }
}
```

`widgets/auth_error_banner.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';

/// Texto negro sobre blanco con barra roja: el rojo directo sobre ámbar no se lee bien.
class AuthErrorBanner extends StatelessWidget {
  final String message;

  const AuthErrorBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: OnesColors.white.withOpacity(0.8),
          border: const Border(left: BorderSide(color: OnesColors.danger, width: 4)),
        ),
        child: Text(
          message,
          style: const TextStyle(color: OnesColors.black, fontWeight: FontWeight.w600, height: 1.3),
        ),
      ),
    );
  }
}
```

`widgets/polaroid_frame.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';

/// Marco tipo polaroid con la misma sombra y giro que la pila de fotos del login.
class PolaroidFrame extends StatelessWidget {
  final Widget child;
  final Widget? caption;
  final double angle;
  final double width;

  const PolaroidFrame({
    super.key,
    required this.child,
    this.caption,
    this.angle = -0.035,
    this.width = 260,
  });

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: width,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
        decoration: BoxDecoration(
          color: OnesColors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.18), blurRadius: 28, offset: const Offset(0, 12)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AspectRatio(aspectRatio: 4 / 3, child: child),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
              child: caption ?? const SizedBox(height: 8),
            ),
          ],
        ),
      ),
    );
  }
}
```

`widgets/email_auth_section.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/ones_typography.dart';
import '../../../../core/ui/widgets/ones_input_decoration.dart';
import 'auth_buttons.dart';

/// Botón "Continuar con correo" que se despliega en el formulario de correo y contraseña.
class EmailAuthSection extends StatefulWidget {
  final String toggleLabel;
  final String submitLabel;
  final bool busy;

  /// Registro: exige 8 caracteres y sugiere contraseña nueva al gestor de contraseñas.
  final bool isRegistration;
  final Widget? footer;
  final Future<void> Function(String email, String password) onSubmit;

  const EmailAuthSection({
    super.key,
    required this.toggleLabel,
    required this.submitLabel,
    required this.busy,
    this.isRegistration = false,
    this.footer,
    required this.onSubmit,
  });

  @override
  State<EmailAuthSection> createState() => _EmailAuthSectionState();
}

class _EmailAuthSectionState extends State<EmailAuthSection> {
  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _expanded = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy || !(_formKey.currentState?.validate() ?? false)) return;
    await widget.onSubmit(_email.text.trim(), _password.text);
  }

  InputDecoration _decoration(String hint, IconData icon, {Widget? suffix, String? helper}) {
    return OnesInputDecoration.build(
      hintText: hint,
      prefixIcon: Icon(icon, color: OnesColors.purpleDeep.withOpacity(0.7)),
      suffixIcon: suffix,
      fillColor: OnesColors.white,
    ).copyWith(helperText: helper);
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    return AnimatedSize(
      duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: _expanded ? _form() : _toggle(),
    );
  }

  Widget _toggle() {
    return AuthOptionButton(
      key: const Key('auth.emailToggle'),
      logo: const Icon(Icons.mail_outline, size: 20, color: OnesColors.purpleDeep),
      label: widget.toggleLabel,
      onPressed: widget.busy ? null : () => setState(() => _expanded = true),
      background: Colors.transparent,
      foreground: OnesColors.purpleDeep,
      border: OnesColors.purpleDeep,
    );
  }

  Widget _form() {
    const fieldStyle = TextStyle(
      fontFamilyFallback: OnesTypography.bodyFallbacks,
      color: OnesColors.black,
      fontWeight: FontWeight.w600,
    );
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('auth.email'),
              controller: _email,
              autofocus: true,
              style: fieldStyle,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              decoration: _decoration('Correo', Icons.mail_outline),
              validator: (v) => _emailPattern.hasMatch((v ?? '').trim()) ? null : 'Escribe un correo válido.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('auth.password'),
              controller: _password,
              style: fieldStyle,
              obscureText: _obscure,
              autofillHints: [widget.isRegistration ? AutofillHints.newPassword : AutofillHints.password],
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: _decoration(
                'Contraseña',
                Icons.lock_outline,
                helper: widget.isRegistration ? 'Mínimo 8 caracteres.' : null,
                suffix: IconButton(
                  tooltip: _obscure ? 'Mostrar contraseña' : 'Ocultar contraseña',
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                final value = v ?? '';
                if (value.isEmpty) return 'Escribe tu contraseña.';
                if (widget.isRegistration && value.length < 8) return 'Usa al menos 8 caracteres.';
                return null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('auth.submit'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: OnesColors.purpleMid,
                foregroundColor: OnesColors.white,
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: widget.busy ? null : _submit,
              child: Text(
                widget.busy ? 'Un momento...' : widget.submitLabel,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (widget.footer != null) widget.footer!,
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Páginas nuevas.** `pages/verify_email_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../auth_controller.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/polaroid_frame.dart';

class VerifyEmailPage extends StatelessWidget {
  const VerifyEmailPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final email = auth.user?.email ?? '';
    final text = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: OnesColors.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: PolaroidFrame(
                      child: const ColoredBox(
                        color: OnesColors.yellowLight,
                        child: Center(
                          child: Icon(Icons.mark_email_unread_outlined, size: 72, color: OnesColors.purpleDeep),
                        ),
                      ),
                      caption: Text(
                        email,
                        key: const Key('verify.email'),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800, color: OnesColors.black),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Revisa tu correo',
                    textAlign: TextAlign.center,
                    style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: OnesColors.black),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Abre el enlace que te enviamos para activar tu cuenta. Cuando vuelvas, lo detectamos solos.',
                    textAlign: TextAlign.center,
                    style: text.bodyMedium?.copyWith(color: OnesColors.black.withOpacity(0.75), height: 1.35),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 20),
                    AuthErrorBanner(message: '${auth.error}'),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    key: const Key('verify.confirm'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      backgroundColor: OnesColors.purpleMid,
                      foregroundColor: OnesColors.white,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    onPressed: auth.isLoading ? null : () => auth.confirmEmailVerified(),
                    child: const Text('Ya verifiqué mi correo', style: TextStyle(fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const Key('verify.resend'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(54),
                      foregroundColor: OnesColors.purpleDeep,
                      side: const BorderSide(color: OnesColors.purpleDeep, width: 1.5),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                    ),
                    onPressed: auth.isLoading
                        ? null
                        : () async {
                            final ok = await auth.resendEmailVerification();
                            if (ok && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Te enviamos un nuevo enlace a $email.')),
                              );
                            }
                          },
                    child: const Text('Reenviar enlace', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('verify.logout'),
                    onPressed: auth.isLoading ? null : () => auth.logout(),
                    child: const Text(
                      'Usar otra cuenta',
                      style: TextStyle(color: OnesColors.purpleDeep, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

`pages/forgot_password_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/ui/ones_colors.dart';
import '../../../../core/ui/ones_typography.dart';
import '../../../../core/ui/widgets/ones_input_decoration.dart';
import '../auth_controller.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/polaroid_frame.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _email = TextEditingController();
  String? _sentTo;
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    if (email.isEmpty || _sending) return;
    setState(() => _sending = true);
    final ok = await context.read<AuthController>().sendPasswordReset(email);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (ok) _sentTo = email;
    });
  }

  ButtonStyle get _primary => FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: OnesColors.purpleMid,
        foregroundColor: OnesColors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      );

  @override
  Widget build(BuildContext context) {
    final error = context.watch<AuthController>().error;
    final text = Theme.of(context).textTheme;
    final body = text.bodyMedium?.copyWith(color: OnesColors.black.withOpacity(0.75), height: 1.35);

    return Scaffold(
      backgroundColor: OnesColors.background,
      appBar: AppBar(title: const Text('Restablecer contraseña')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: _sentTo != null
                  ? Column(
                      key: const Key('forgot.sent'),
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: PolaroidFrame(
                            angle: 0.03,
                            child: const ColoredBox(
                              color: OnesColors.yellowLight,
                              child: Center(child: Icon(Icons.lock_reset, size: 72, color: OnesColors.purpleDeep)),
                            ),
                            caption: Text(
                              _sentTo!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w800, color: OnesColors.black),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Text('Revisa tu correo',
                            textAlign: TextAlign.center,
                            style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: OnesColors.black)),
                        const SizedBox(height: 10),
                        Text(
                          'Si hay una cuenta con ese correo, te llegará un enlace para crear una contraseña nueva.',
                          textAlign: TextAlign.center,
                          style: body,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          key: const Key('forgot.back'),
                          style: _primary,
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Volver a iniciar sesión', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Escribe el correo de tu cuenta y te enviaremos un enlace para crear una contraseña nueva.',
                          style: body,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          key: const Key('forgot.email'),
                          controller: _email,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          style: const TextStyle(
                            fontFamilyFallback: OnesTypography.bodyFallbacks,
                            color: OnesColors.black,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: OnesInputDecoration.build(
                            hintText: 'Correo',
                            prefixIcon: Icon(Icons.mail_outline, color: OnesColors.purpleDeep.withOpacity(0.7)),
                            fillColor: OnesColors.white,
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 16),
                          AuthErrorBanner(message: '$error'),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          key: const Key('forgot.send'),
                          style: _primary,
                          onPressed: _sending ? null : _send,
                          child: Text(_sending ? 'Enviando...' : 'Enviar enlace',
                              style: const TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Write the failing page tests** `test/features/auth/presentation/auth_pages_test.dart`:

```dart
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
}

/// Error de credenciales para probar el aviso.
class AuthExceptionForTest extends AuthException {
  const AuthExceptionForTest() : super(AuthFailure.invalidCredentials);
}
```

Run: `flutter test test/features/auth/presentation/auth_pages_test.dart`
Expected: FAIL (LoginPage/RegisterPage aún no tienen `auth.emailToggle`, `auth.apple`, `auth.google`, `auth.forgot`).

- [ ] **Step 8: LoginPage.** En `login_page.dart`:
  - Imports: quitar `dart:async`, `package:google_sign_in/google_sign_in.dart`, `../../infrastructure/google_sign_in_initializer.dart`, los dos `../google_sign_in_button.dart` y `font_awesome_flutter` si queda sin uso; añadir `../widgets/auth_buttons.dart`, `../widgets/email_auth_section.dart`, `../widgets/auth_error_banner.dart`, `forgot_password_page.dart`. Quitar `package:flutter/foundation.dart` si queda sin uso.
  - En `_LoginPageState`: borrar `_webGisButton`, `_webAuthSub`, `_webAuthEvents`, `_webConsumedSignIn`, `_onWebGoogleSignedIn`, y `initState`/`dispose` completos (solo existían para GIS web). Añadir:

```dart
  Future<void> _run(Future<AuthNextStep> Function() action) async {
    final auth = context.read<AuthController>();
    final step = await action();
    if (!mounted) return;
    setState(() {
      // Las cuentas de correo sin registro las lleva el router al formulario de registro.
      _accountNotFound = step == AuthNextStep.needsRegistration && auth.user?.provider != 'password';
    });
  }
```

  - En el bloque `else ...[`: reemplazar el `Container(...)` que muestra `'Error: ${auth.error}'` por `AuthErrorBanner(message: '${auth.error}'),` y reemplazar el elemento `SizedBox(width: double.infinity, height: 54, child: kIsWeb ? StreamBuilder<GoogleSignInAuthenticationEvent>(...) : ElevatedButton(...),),` completo por:

```dart
                    GoogleSignInButton(
                      busy: auth.isLoading,
                      onPressed: auth.isLoading ? null : () => _run(auth.signInWithGoogle),
                    ),
                    if (appleSignInAvailable) ...[
                      const SizedBox(height: 12),
                      AppleSignInButton(
                        onPressed: auth.isLoading ? null : () => _run(auth.signInWithApple),
                      ),
                    ],
                    const SizedBox(height: 12),
                    EmailAuthSection(
                      toggleLabel: 'Continuar con correo',
                      submitLabel: 'Iniciar sesión',
                      busy: auth.isLoading,
                      onSubmit: (email, password) => _run(() => auth.signInWithEmail(email, password)),
                      footer: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          key: const Key('auth.forgot'),
                          onPressed: auth.isLoading
                              ? null
                              : () => Navigator.of(context).push(
                                    MaterialPageRoute(builder: (_) => const ForgotPasswordPage()),
                                  ),
                          child: const Text(
                            'Olvidé mi contraseña',
                            style: TextStyle(color: OnesColors.purpleDeep, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
```

  - Quitar los `print(` de depuración que queden en el archivo.

- [ ] **Step 9: RegisterPage.** En `register_page.dart`:
  - Imports: quitar `dart:async`, `package:google_sign_in/google_sign_in.dart`, `../../infrastructure/google_sign_in_initializer.dart`, `../google_sign_in_button.dart`; añadir `../widgets/auth_buttons.dart`, `../widgets/email_auth_section.dart`, `../widgets/auth_error_banner.dart`. Quitar `package:flutter/foundation.dart` y `font_awesome_flutter` si quedan sin uso.
  - Borrar `_webGisButton`, `_webAuthSub`, `_webConsumedSignIn`, `_onWebGoogleSignedIn` y, en `initState`, el bloque `if (kIsWeb) { ... }` del listener; en `dispose` quitar `_webAuthSub?.cancel();`.
  - Añadir:

```dart
  Future<void> _startWith(Future<AuthNextStep> Function() action) async {
    final auth = context.read<AuthController>();
    final step = await action();
    if (!mounted) return;
    switch (step) {
      case AuthNextStep.failed:
        return;
      case AuthNextStep.signedIn:
      case AuthNextStep.needsEmailVerification:
        // La raíz (Home o VerifyEmailPage) toma el control.
        if (widget.popToRootOnComplete) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
        return;
      case AuthNextStep.needsRegistration:
        final seed = auth.preferredName ?? _guessPreferredName(auth.user?.displayName);
        setState(() {
          _showValidation = false;
          if (_preferredNameController.text.trim().isEmpty && seed != null && seed.trim().isNotEmpty) {
            _preferredNameController.text = seed.trim();
          }
        });
    }
  }
```

  - Subtítulo `'Usa tu cuenta de Google para crear tu perfil en Ones.'` → `'Elige cómo quieres crear tu cuenta en Ones.'`.
  - Reemplazar el `Container(...)` de `'Error: ${auth.error}'` por `AuthErrorBanner(message: '${auth.error}'),`.
  - En `if (user == null) ...[`, reemplazar el `SizedBox(width: double.infinity, height: 54, child: kIsWeb ? Stack(...) : ElevatedButton(...),),` completo por:

```dart
                          GoogleSignInButton(
                            busy: auth.isLoading,
                            onPressed: auth.isLoading ? null : () => _startWith(auth.beginRegistration),
                          ),
                          if (appleSignInAvailable) ...[
                            const SizedBox(height: 12),
                            AppleSignInButton(
                              onPressed: auth.isLoading ? null : () => _startWith(auth.beginRegistrationWithApple),
                            ),
                          ],
                          const SizedBox(height: 12),
                          EmailAuthSection(
                            toggleLabel: 'Crear cuenta con correo',
                            submitLabel: 'Crear cuenta',
                            busy: auth.isLoading,
                            isRegistration: true,
                            onSubmit: (email, password) => _startWith(() => auth.registerWithEmail(email, password)),
                          ),
```

- [ ] **Step 10: Remove GIS.** `git rm` de `lib/features/auth/infrastructure/google_sign_in_initializer.dart`, `lib/features/auth/presentation/google_sign_in_button.dart`, `google_sign_in_button_stub.dart`, `google_sign_in_button_web.dart`.

- [ ] **Step 11: Run tests**

Run:
```bash
flutter test test/features/auth test/core/config
flutter analyze lib 2>&1 | grep -E 'error •' | head
```
Expected: todos PASS; sin `error •`.

- [ ] **Step 12: Commit**

```bash
git add -A apps/ones_app/lib apps/ones_app/assets/auth apps/ones_app/test/features/auth
git commit -m "feat(app): login y registro con Google, Apple y correo; verificación y recuperación de contraseña"
```

---

### Task 5: Web y revisión visual

**Files:**
- Modify: `apps/ones_app/web/index.html`
- Modify: `apps/ones_app/lib/app.dart` (`_RootRouterState.didChangeAppLifecycleState`)
- Temporal (no se commitea): `apps/ones_app/tool/auth_preview.dart`

**Interfaces:**
- Consumes: `AuthController.refreshEmailVerification()` (Task 3), páginas de Task 4.

- [ ] **Step 1: Limpiar GIS de `web/index.html`.** Borrar `<meta name="google-signin-client_id" ...>` y `<script src="https://accounts.google.com/gsi/client" async defer></script>`. Firebase carga su propio SDK de autenticación; ese script ya no se usa.

- [ ] **Step 2: Detectar la verificación al volver.** En `lib/app.dart`, `_RootRouterState` ya es `WidgetsBindingObserver`. En su `didChangeAppLifecycleState` (crearlo si no existe, llamando a `super`), añadir al recibir `AppLifecycleState.resumed`:

```dart
    if (state == AppLifecycleState.resumed) {
      // Volvió desde el correo (otra app o pestaña): si ya verificó, avanzamos sin pedirle nada.
      context.read<AuthController>().refreshEmailVerification();
    }
```

En web, Flutter emite `resumed` cuando la pestaña vuelve a estar visible, así que cubre a quien verifica en otra pestaña.

Run: `flutter test test/features/auth && flutter analyze lib 2>&1 | grep -E 'error •' | head`
Expected: PASS; sin `error •`.

- [ ] **Step 3: Commit**

```bash
git add apps/ones_app/web/index.html apps/ones_app/lib/app.dart
git commit -m "feat(web): quitar Google Identity Services y detectar verificación al volver a la app"
```

- [ ] **Step 4: Build web**

Run: `flutter build web --release > /tmp/web-build.log 2>&1; tail -1 /tmp/web-build.log`
Expected: `✓ Built build/web`.

- [ ] **Step 5: Revisión visual de las pantallas reales.** Servir y capturar con Chrome (Claude in Chrome) en 390×844 y 1280×800:

```bash
(cd build/web && python3 -m http.server 7357 --bind 127.0.0.1) &
```

En `http://127.0.0.1:7357/` capturar: login plegado; login con el correo desplegado; login tras enviar el formulario vacío (errores de validación); registro; "Olvidé mi contraseña". Recorrer con Tab para ver el foco en cada botón y campo. Revisar contra la dirección de diseño de Task 4:
  - el logo de Google se ve a color (no un cuadro vacío) y con bordes limpios: hacer `zoom` del navegador sobre cada botón a 1280×800 y con zoom de página al 200 %;
  - los tres botones de acceso tienen el mismo ancho y alto, y el formulario no empuja la pila de fotos fuera de la primera pantalla en 390×844 cuando está plegado;
  - el aviso de error se lee (negro sobre blanco) y no lleva "Error:";
  - nada se corta con zoom del navegador al 200 %.

- [ ] **Step 5b: Logo de Apple.** En web no aparece (solo iOS). Revisarlo en el simulador de iOS: `flutter run -d "iPhone 16"` (o el simulador disponible), captura con `xcrun simctl io booted screenshot /tmp/login-ios.png` y revisar el botón negro con el logo blanco nítido, centrado verticalmente con el texto.

- [ ] **Step 6: Revisión visual de verificación y contraseña enviada** (no se llega a ellas sin una cuenta real). Crear `tool/auth_preview.dart` temporal que pinte `VerifyEmailPage` y la confirmación de `ForgotPasswordPage` con un `AuthController` falso:

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ones_app/core/ui/ones_theme.dart';
import 'package:ones_app/features/admin/application/get_admin_me_use_case.dart';
import 'package:ones_app/features/admin/domain/admin_repository.dart';
import 'package:ones_app/features/auth/domain/auth_repository.dart';
import 'package:ones_app/features/auth/domain/auth_user.dart';
import 'package:ones_app/features/auth/presentation/auth_controller.dart';
import 'package:ones_app/features/auth/presentation/pages/verify_email_page.dart';
import 'package:ones_app/features/users/application/ensure_user_use_case.dart';
import 'package:ones_app/features/users/domain/users_repository.dart';

/// Solo para revisar diseño en local. No se commitea.
class _PreviewAuth implements AuthRepository {
  static const _user = AuthUser(
      userId: 'preview', email: 'ana.perez@example.com', displayName: null, pictureUrl: null,
      provider: 'password', emailVerified: false);
  @override
  Future<AuthUser> registerWithEmail(String e, String p) async => _user;
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(null);
}

class _NoUsers implements UsersRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(null);
}

class _NoAdmin implements AdminRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value(false);
}

Future<void> main() async {
  final users = _NoUsers();
  final auth = AuthController(
    authRepository: _PreviewAuth(),
    ensureUser: EnsureUserUseCase(users),
    getUserPreferences: GetUserPreferencesUseCase(users),
    updateUserPreferences: UpdateUserPreferencesUseCase(users),
    lookupUserByEmailUseCase: LookupUserByEmailUseCase(users),
    getAdminMe: GetAdminMeUseCase(_NoAdmin()),
  );
  await auth.registerWithEmail('ana.perez@example.com', 'x');
  runApp(ChangeNotifierProvider.value(
    value: auth,
    child: MaterialApp(theme: OnesTheme.light(), home: const VerifyEmailPage()),
  ));
}
```

Ajustar el import de `AdminRepository` a su ruta real (`grep -rn 'class AdminRepository' lib`). Run: `flutter build web --release -t tool/auth_preview.dart` y capturar igual que en Step 5 (390×844 y 1280×800). Revisar: el marco polaroid con el correo como pie de foto, jerarquía título → texto → botón morado → contorno → enlace, y que un correo largo se corte con "…" sin romper el marco. Repetir cambiando `home:` por la confirmación de `ForgotPasswordPage` si hace falta. Al terminar: `rm tool/auth_preview.dart`, `rm -rf build/web` y detener el servidor.

- [ ] **Step 7: Ajustes de diseño.** Si la revisión muestra algo que no cumple la dirección de Task 4, corregirlo con su test de widget cuando sea comportamiento, o directamente cuando sea solo estilo, y commitear: `git commit -m "fix(app): ajustes visuales de autenticación"`.

---

## Verificación manual (después del plan, con el backend desplegado)

Configuración previa: agregar `appdev.ones.events` a los dominios autorizados de Firebase.

Matriz del spec §9: iOS Google/Apple/correo, Android Google/correo, web Google/correo (Chrome, Safari y Safari en iPhone; con bloqueador de ventanas emergentes activo debe salir el mensaje de ventana bloqueada); verificar correo abriendo el enlace en otra pestaña/app y volver (debe avanzar solo); persistencia tras reinstalar; expiración del token tras 1 h; desactivar y reactivar cuenta; usuario legado de Google entrando por primera vez (debe conservar sus eventos); app versión anterior contra backend nuevo.
