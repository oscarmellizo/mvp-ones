# Migración de autenticación a Firebase Auth (Google, Apple, correo/contraseña)

Fecha: 2026-09-19
Rama de trabajo: `fix/ios-google-signin-audience` (se creará rama propia para la implementación)
Estado: aprobado para plan de implementación

## 1. Contexto y objetivo

Hoy la app autentica únicamente con Google Sign-In. El cliente Flutter obtiene un
Google ID Token y el backend Spring (Resource Server OAuth2) lo valida contra el
JWKS de Google. El `userId` de todas las tablas es el claim `sub` de Google. No
existe sesión propia: el token vive en memoria y un timestamp local de 30 días
decide si se intenta restaurar sesión con login silencioso.

App Store exige ofrecer un método de inicio de sesión adicional al de terceros.
Se decidió migrar a **Firebase Auth** con tres proveedores: Google, Sign in with
Apple (solo iOS) y correo/contraseña. Objetivos:

- Cumplir el requisito de App Store.
- Mejorar seguridad y manejo de sesión (refresh token real, verificación de
  correo, bloqueo de cuentas desactivadas).
- Conservar todas las tablas de DynamoDB sin cambios de esquema ni reescritura
  de datos.
- No romper las versiones actuales de la app durante la transición.

## 2. Decisiones tomadas

| Decisión | Elección |
|---|---|
| Identidad de usuarios existentes | Importar a Firebase con `uid = userId` actual. `sub` del token nuevo coincide con las claves existentes. |
| Transición | Backend acepta tokens de Google directos y de Firebase en paralelo, con flag para retirar el issuer viejo. |
| Sign in with Apple | Solo iOS. No se configura Service ID ni key `.p8`. |
| Proyectos Firebase | Prod: proyecto existente vinculado al proyecto Google Cloud actual (client IDs `403122779240-…`). Dev: proyecto nuevo. |
| Verificación de correo | Obligatoria para cuentas `password`. El backend rechaza tokens sin `email_verified`. |
| Firebase Admin SDK en backend | No. El backend solo valida JWT con JWKS público. |

## 3. Arquitectura

```
Flutter (iOS / Android / Web)
  └─ firebase_auth  ──(Google credential vía google_sign_in | Apple nativo | email+password)──▶ Firebase Auth
        │  ID token de Firebase (JWT, 1 h) + refresh token gestionado por el SDK
        ▼
Spring Boot API (ECS)
  └─ JwtIssuerAuthenticationManagerResolver
        ├─ issuer https://accounts.google.com                (legacy, flag)
        └─ issuer https://securetoken.google.com/<projectId> (Firebase)
              ├─ audiencia = projectId
              ├─ JWKS https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com
              ├─ validador EmailVerified (solo provider password)
              └─ principal = sub
  └─ Filtro AccountStatus (rechaza DISABLED salvo /v1/account/**)
DynamoDB: sin cambios de esquema.
```

## 4. Backend (`services/ones-api`)

### 4.1 Configuración

- Propiedades nuevas en `application.yml`:
  - `ones.auth.firebase.project-id: ${FIREBASE_PROJECT_ID:}`
  - `ones.auth.google-legacy.enabled: ${GOOGLE_LEGACY_AUTH_ENABLED:true}`
- CloudFormation (`infra/cloudformation/backend/*.yml`): parámetro `FirebaseProjectId`
  y variable de entorno `FIREBASE_PROJECT_ID` en la task definition, junto a
  `GOOGLE_LEGACY_AUTH_ENABLED`. Workflows de deploy reciben el parámetro nuevo.

### 4.2 Cadena de seguridad

- `SecurityConfig.securityFilterChain` deja de usar un `JwtDecoder` único y pasa a
  `oauth2ResourceServer.authenticationManagerResolver(resolver)` con un
  `JwtIssuerAuthenticationManagerResolver` construido a partir de un mapa
  issuer → `AuthenticationManager`.
- Issuer Google: decoder y validadores actuales (`GoogleAudienceValidator`,
  issuer). Se registra solo si `google-legacy.enabled` es `true`.
- Issuer Firebase: `NimbusJwtDecoder.withJwkSetUri(...)` y validadores: issuer,
  audiencia = projectId, timestamps por defecto, y `FirebaseEmailVerifiedValidator`.
- Si `FIREBASE_PROJECT_ID` está vacío el issuer Firebase no se registra y se loguea
  un warning al arrancar. Si ambos están deshabilitados la aplicación falla al
  arrancar.
- `JwtAuthenticationConverter` se mantiene: principal `sub`, sin authorities.
- Las rutas públicas, las de admin y los filtros de actuator/internal no cambian.

### 4.3 Validador de correo verificado

`FirebaseEmailVerifiedValidator implements OAuth2TokenValidator<Jwt>`:

- Lee `firebase.sign_in_provider`. Si es `password` y `email_verified` no es `true`,
  devuelve fallo con `OAuth2Error("invalid_token", "EMAIL_NOT_VERIFIED")`.
- Cualquier otro proveedor pasa.
- El `ApiExceptionHandler` / entry point traduce ese fallo a HTTP 403 con cuerpo
  `{ "code": "EMAIL_NOT_VERIFIED", "message": ... }` para que el cliente lo distinga
  de un 401 de token expirado. Implementación: `BearerTokenAuthenticationEntryPoint`
  personalizado que inspecciona el `OAuth2Error` y responde 403 cuando el código
  de error sea `EMAIL_NOT_VERIFIED`; en cualquier otro caso responde 401 como hoy.

### 4.4 Claims

`AuthClaims` gana:

- `provider(Authentication)`: devuelve `firebase.sign_in_provider` si existe
  (`google.com`, `apple.com`, `password`); si el token es de Google legacy devuelve
  `"google"`.
- `requireEmail` y `preferredName` no cambian; `name` puede faltar en cuentas de
  correo y el fallback a `preferredName` existente lo cubre.

`UsersController.ensure` reemplaza el literal `"google"` por `AuthClaims.provider(...)`.
`given_name` y `family_name` siguen leyéndose; en Firebase serán `null` y
`EnsureUserUseCase` ya hace `coalesce`.

### 4.5 Filtro de cuentas desactivadas

`AccountStatusFilter extends OncePerRequestFilter`, registrado después de la
autenticación JWT en la cadena principal:

- Si hay `Authentication` y el usuario existe en la tabla users con
  `status = DISABLED`, responde 403 `{ "code": "ACCOUNT_DISABLED" }`.
- Exento: `/v1/account/**` (reactivación) y rutas públicas.
- Usa `UsersRepository.findById` con cache Caffeine (`CacheConfig`), TTL corto
  (1 minuto) y se invalida en `AccountDeactivateUseCase` y
  `AccountReactivateUseCase`.

## 5. Cliente Flutter (`apps/ones_app`)

### 5.1 Dependencias

- Agregar `firebase_core` y `firebase_auth`.
- Mantener `google_sign_in` (credencial de Google en iOS/Android).
- Apple en iOS: `FirebaseAuth.instance.signInWithProvider(AppleAuthProvider())`,
  sin paquete adicional. El botón de Apple solo se renderiza en iOS.
- Web: Google con `signInWithPopup(GoogleAuthProvider())`. Se elimina el
  `<meta name="google-signin-client_id">` y el script GIS de `web/index.html`,
  junto con `google_sign_in_button_web.dart` y `_stub.dart`.
- Eliminar `shared_preferences` solo si ningún otro módulo lo usa (verificar en el
  plan); la clave `ones.auth.last_interactive_signin_at_v1` se borra en el primer
  arranque.

### 5.2 Configuración por ambiente

- Android: `google-services.json` por flavor en `android/app/src/dev/` y
  `android/app/src/prod/` (applicationId `com.ones.events.dev` y `com.ones.events`).
  Ambos archivos siguen ignorados en git; se documenta dónde obtenerlos.
- iOS: `GoogleService-Info.plist` por ambiente en `ios/config/dev/` y
  `ios/config/prod/` (ignorados en git). `scripts/ios_config.sh` copia el del
  ambiente a `ios/Runner/GoogleService-Info.plist` además de generar los
  dart-defines. El `GIDClientID` de `Info.plist` se toma del plist de Firebase
  del proyecto correspondiente (`CLIENT_ID`) y el `REVERSED_CLIENT_ID` va en
  `CFBundleURLSchemes`.
- Web: `AppConfig` gana `firebaseWeb` con `apiKey`, `authDomain`, `projectId`,
  `appId`, `messagingSenderId`, desde dart-defines `FIREBASE_WEB_*` y desde
  `assets/config/app_config.json`. `Firebase.initializeApp` recibe
  `FirebaseOptions` construidas desde `AppConfig` en web; en móvil usa los archivos
  nativos.
- Capability "Sign in with Apple" en `Runner.entitlements` y en el App ID.

### 5.3 Dominio y aplicación

`AuthRepository` (puerto) pasa a:

```dart
abstract interface class AuthRepository {
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser?> currentUser();
  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInWithApple();          // UnsupportedError fuera de iOS
  Future<AuthUser> signInWithEmail(String email, String password);
  Future<AuthUser> registerWithEmail(String email, String password);
  Future<void> sendEmailVerification();
  Future<void> reloadUser();
  Future<void> sendPasswordReset(String email);
  Future<String?> getIdToken({bool forceRefresh = false});
  Future<void> signOut();
}
```

`AuthUser` gana `provider` y `emailVerified`. Se agregan casos de uso mínimos
(`SignInWithAppleUseCase`, `SignInWithEmailUseCase`, `RegisterWithEmailUseCase`,
`SendPasswordResetUseCase`, `SendEmailVerificationUseCase`) siguiendo el patrón
de los existentes. `SignInWithGoogleUseCase`, `SignOutUseCase` y
`GetIdTokenUseCase` se conservan.

Errores: el adaptador traduce `FirebaseAuthException.code` a un enum
`AuthFailure` (`invalidCredentials`, `emailAlreadyInUse`, `weakPassword`,
`userDisabled`, `emailNotVerified`, `cancelled`, `network`, `unknown`) para que la
presentación no dependa de Firebase.

### 5.4 Adaptador

`FirebaseAuthRepository` en `features/auth/adapters/firebase/` reemplaza a
`GoogleAuthRepository`, `GoogleSignInInitializer` y `GoogleTokenRefreshService`.

- Google móvil: `GoogleSignIn.instance.authenticate()` →
  `GoogleAuthProvider.credential(idToken: ...)` → `signInWithCredential`.
  `google_sign_in` se inicializa con `serverClientId` = client web del proyecto
  Firebase del ambiente (dart-define `GOOGLE_WEB_CLIENT_ID`, como hoy).
- Google web: `signInWithPopup`.
- Apple iOS: `signInWithProvider(AppleAuthProvider()..addScope('email')..addScope('name'))`.
- `signOut`: `FirebaseAuth.signOut()` y, en móvil, `GoogleSignIn.disconnect()`
  best-effort como hoy.

### 5.5 Controlador

`AuthController` conserva su API pública hacia `app.dart` (`idToken`, `user`,
`isRegistered`, `isAdmin`, `isLoading`, `refreshIdToken`, `logout`, etc.) y cambia
internamente:

- Arranque: `currentUser()`; si existe, `getIdToken()` y el flujo actual
  (`GET preferences` → 404 = `needsRegistration`). Se elimina el timestamp de 30 días.
- `refreshIdToken()` llama `getIdToken(forceRefresh: true)`. El interceptor de
  401 en `OnesApiFactory` no cambia.
- Nuevo estado `AuthNextStep.needsEmailVerification`, devuelto cuando el usuario
  es `password` y `emailVerified` es falso, o cuando el backend responde 403
  `EMAIL_NOT_VERIFIED`.
- Registro con correo: `registerWithEmail` → `sendEmailVerification` →
  `needsEmailVerification`. Al confirmar: `reloadUser`, `getIdToken(forceRefresh)`
  y continúa a `completeRegistration` (ensure + preferencias + términos), que no
  cambia.
- Registro con Google/Apple: igual que hoy (`beginRegistration` → formulario de
  nombre preferido y términos → `completeRegistration`).
- Logout limpia también `_languagePreference` y `_termsAccepted`.
- Se eliminan los `print` de depuración de credenciales.

### 5.6 Pantallas

Todas en `features/auth/presentation/pages/`, reutilizando estilos actuales:

- `LoginPage`: botones "Continuar con Google", "Continuar con Apple" (solo iOS),
  formulario correo/contraseña con "Olvidé mi contraseña" y enlace a registro.
- `RegisterPage`: selector de método; con correo pide email, contraseña
  (mínimo 8 caracteres), nombre preferido y términos.
- `VerifyEmailPage`: muestra el correo, botones "Reenviar" y "Ya verifiqué", y
  "Cerrar sesión".
- `ForgotPasswordPage`: email y envío del correo de restablecimiento.

Los textos entran por el sistema de traducciones existente (`TranslationsService`
y `initial-translations.json`).

## 6. Importación de usuarios a Firebase

Script `infra/scripts/firebase-import-users/` (Node, `firebase-admin` +
`@aws-sdk/client-dynamodb`):

- Entrada: nombre de tabla users y credenciales de servicio del proyecto Firebase
  del ambiente (`GOOGLE_APPLICATION_CREDENTIALS`).
- Escanea la tabla y por cada usuario con `provider = google` construye
  `{ uid: userId, email, emailVerified: true, displayName: name, photoURL: picture,
     providerData: [{ providerId: 'google.com', uid: userId, email, displayName, photoURL }] }`.
- Llama `auth.importUsers` en lotes de hasta 1000. Los errores por uid existente
  se ignoran (idempotente); el resto se reporta al final con conteo.
- Modo `--dry-run` que solo imprime el conteo.
- Se ejecuta manualmente por un admin: dev, luego prod, justo antes de publicar la
  app. Puede repetirse para recoger usuarios nuevos entre corridas.

Comportamiento esperado: al iniciar sesión con Google, Firebase busca por
`(google.com, sub)` y devuelve el usuario importado, por lo que el `sub` del token
de Firebase es igual al `userId` existente.

## 7. Despliegue y transición

1. Configurar proyectos Firebase (dev nuevo, prod existente), registrar apps
   Android (`com.ones.events`, `com.ones.events.dev`) con SHA-1, app iOS
   (`co.ones.onesapp`) y app web. Habilitar proveedores Google, Apple y
   Email/Password. Ajuste "Una cuenta por dirección de correo".
2. Desplegar backend con ambos issuers a dev, validar con la app actual, luego prod.
3. Ejecutar importación de usuarios en dev y prod.
4. Publicar app nueva (TestFlight, Play interno, web).
5. Con adopción suficiente, poner `GOOGLE_LEGACY_AUTH_ENABLED=false` y redeploy.

## 8. Errores y casos borde

- Email ya registrado con Google al crear cuenta por correo:
  `emailAlreadyInUse` → mensaje que ofrece entrar con Google o restablecer contraseña.
- Apple con "Ocultar mi correo": email de relay `privaterelay.appleid.com`. Las
  invitaciones por correo real no coincidirán. Limitación documentada.
- Token expirado/revocado: 401 → refresh forzado y un reintento (comportamiento
  actual). Si el refresh falla, `AuthController` cierra sesión local.
- Cuenta desactivada: 403 `ACCOUNT_DISABLED` en cualquier endpoint; la app ya
  muestra el flujo de reactivación desde `/v1/account`.
- Cancelación del popup/hoja nativa: `AuthFailure.cancelled`, sin mensaje de error.
- Sin `FIREBASE_PROJECT_ID` en backend: arranca solo con Google legacy y warning.

## 9. Pruebas

Backend (JUnit + spring-security-test):

- `FirebaseEmailVerifiedValidatorTest`: password sin verificar falla; password
  verificado pasa; google.com y apple.com pasan sin el claim.
- `IssuerResolverTest`: token con issuer Firebase se acepta; issuer desconocido
  responde 401; con `google-legacy.enabled=false` el issuer Google responde 401.
  Se usa un JWKS de prueba servido por `MockWebServer` o clave RSA local.
- `AuthClaimsTest`: casos con claims con forma Firebase (`firebase.sign_in_provider`,
  sin `given_name`).
- `AccountStatusFilterTest`: DISABLED → 403 salvo en `/v1/account/**`.
- `UsersControllerTest`: `provider` persistido según el token.

Flutter (flutter_test):

- `AuthControllerTest` con `FakeAuthRepository`: arranque con y sin usuario,
  Google, Apple, correo verificado, correo sin verificar, 403 `EMAIL_NOT_VERIFIED`,
  refresh, logout limpia todo.
- Tests de mapeo `FirebaseAuthException` → `AuthFailure`.

Manual (matriz antes de publicar): iOS Google/Apple/correo, Android Google/correo,
web Google/correo, persistencia tras reinstalar, expiración tras 1 h, desactivar y
reactivar, app versión anterior contra backend nuevo.

## 10. Fuera de alcance

MFA, Apple en Android y web, App Check, expiración máxima de sesión por
`auth_time`, cambio del comportamiento de fusión por email en `EnsureUserUseCase`,
desvinculación de proveedores, y deshabilitar usuarios en Firebase desde el backend.

## 11. Insumos que debe entregar el equipo

- Proyecto Firebase dev nuevo y acceso al proyecto existente para prod.
- Archivos `google-services.json` (dos por proyecto) y `GoogleService-Info.plist`
  (uno por proyecto), y config web de cada proyecto.
- Capability Sign in with Apple habilitada en el App ID `co.ones.onesapp`.
- SHA-1 de debug y release de Android registrados en ambos proyectos.
- Credenciales de servicio de cada proyecto Firebase para correr la importación.
- Valor de `FIREBASE_PROJECT_ID` por ambiente para CloudFormation.
- Dispositivo o simulador iOS con Apple ID para QA.
