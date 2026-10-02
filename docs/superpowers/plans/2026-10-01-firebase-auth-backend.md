# Firebase Auth — Backend Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Que `ones-api` acepte ID tokens de Firebase (Google, Apple, correo) en paralelo con los de Google actuales, exija correo verificado para cuentas `password`, migre bajo demanda a los usuarios de Google existentes y nunca borre datos por coincidencia de correo.

**Architecture:** `JwtIssuerAuthenticationManagerResolver` enruta cada token por su `iss` a un decoder (Google legacy o Firebase). Tres filtros después de `BearerTokenAuthenticationFilter`: `EmailVerifiedFilter` → `LegacyAccountMigrationFilter` → `DisabledAccountFilter` (existente). La migración usa la REST API de Identity Toolkit con una service account leída de Secrets Manager.

**Tech Stack:** Java 17, Spring Boot 3.3.6, Spring Security 6.3 (resource server), JUnit 5 + Mockito, WebClient, `com.google.auth:google-auth-library-oauth2-http:1.54.0`, CloudFormation.

**Spec:** `docs/superpowers/specs/2026-09-19-firebase-auth-migration-design.md`

## Global Constraints

- Proyecto Firebase único (dev y prod): `ones-a96a7`.
- Issuer Firebase: `https://securetoken.google.com/<projectId>`; audiencia = `<projectId>`; JWKS `https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com`.
- Issuer Google legacy: `https://accounts.google.com`, JWKS `https://www.googleapis.com/oauth2/v3/certs`, validado con `GoogleAudienceValidator` como hoy.
- Propiedades: `ones.auth.firebase.project-id: ${FIREBASE_PROJECT_ID:}`, `ones.auth.google-legacy.enabled: ${GOOGLE_LEGACY_AUTH_ENABLED:true}`, `ones.auth.firebase.service-account-secret-name: ${FIREBASE_SERVICE_ACCOUNT_SECRET_NAME:}`.
- Sin `FIREBASE_PROJECT_ID`: arranca solo con Google legacy y loguea warning. Ambos deshabilitados: falla al arrancar.
- Principal = claim `sub`, sin authorities (no cambia).
- Códigos de error en cuerpo JSON `{"code": "..."}`: `EMAIL_NOT_VERIFIED` (403), `ACCOUNT_MIGRATED` (409), `ACCOUNT_MIGRATION_FAILED` (503), `EMAIL_CONFLICT` (409).
- DynamoDB sin cambios de esquema. Nunca se borra un usuario no-`stub` por coincidencia de correo.
- Comando de tests: desde `services/ones-api`, `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test` (añadir `-Dtest=Clase` para uno solo). Línea base: todo pasa.
- Comentarios y mensajes de log en español, como el código existente.

## Review Focus

- Token de Firebase con `aud` de otro proyecto (o de Google legacy con `iss` de Firebase): debe responder 401, nunca autenticar. Test en Task 1.
- Usuario invitado (fila `provider = "stub"` creada por invitación) que se registra con Firebase: la fusión del stub debe seguir funcionando. Test en Task 4.
- Usuario de Google nuevo (sin fila legada) entrando por Firebase con `uid != googleSub`: no debe migrar ni bloquearse. Test en Task 6.
- Migración sin service account configurada: no debe borrar nada ni responder `ACCOUNT_MIGRATED`. Test en Task 6.
- Cuenta `password` sin verificar llamando a `/v1/users/ensure`: 403 `EMAIL_NOT_VERIFIED` (no hay excepción de ruta). Test en Task 3.

---

## File Structure

| Archivo | Responsabilidad |
|---|---|
| `configuration/AuthIssuers.java` (nuevo) | issuer → validador/decoder/manager; reglas de habilitación |
| `configuration/SecurityConfig.java` | usa el resolver y registra los filtros en orden |
| `adapters/inbound/rest/AuthClaims.java` | `provider`, `emailVerified`, `isFirebase`, `googleIdentity` |
| `adapters/inbound/rest/users/UsersController.java` | `provider` real en `ensure` |
| `adapters/inbound/rest/EmailVerifiedFilter.java` (nuevo) | 403 `EMAIL_NOT_VERIFIED` |
| `application/users/EnsureUserUseCase.java` | conflicto en vez de borrado |
| `application/users/EmailConflictException.java` (nuevo) | error de dominio |
| `adapters/inbound/rest/ApiExceptionHandler.java` | 409 `EMAIL_CONFLICT` |
| `application/users/ports/FirebaseIdentityAdmin.java` (nuevo) | puerto de administración de Firebase |
| `adapters/outbound/firebase/FirebaseIdentityToolkitClient.java` (nuevo) | REST Identity Toolkit |
| `application/users/AccountMigrationService.java` (nuevo) | decide y ejecuta la migración |
| `adapters/inbound/rest/LegacyAccountMigrationFilter.java` (nuevo) | 409 `ACCOUNT_MIGRATED` en `/v1/users/**` |
| `infra/cloudformation/backend/{root,all}.yml`, `.github/workflows/deploy-infra-backend.yml` | parámetros, secreto, IAM, env |

Rutas Java relativas a `services/ones-api/src/main/java/com/ones/api/` (tests en `src/test/java/com/ones/api/`).

---

### Task 1: Resolver multi-issuer (Google legacy + Firebase)

**Files:**
- Create: `services/ones-api/src/main/java/com/ones/api/configuration/AuthIssuers.java`
- Modify: `services/ones-api/src/main/java/com/ones/api/configuration/SecurityConfig.java`
- Modify: `services/ones-api/src/main/resources/application.yml` (bloque `ones.auth`)
- Test: `services/ones-api/src/test/java/com/ones/api/configuration/AuthIssuersTest.java`

**Interfaces:**
- Produces: `AuthIssuers.GOOGLE_ISSUER`, `AuthIssuers.firebaseIssuer(String projectId)`, `AuthIssuers.validators(boolean googleLegacyEnabled, String googleClientIds, String firebaseProjectId) : Map<String, OAuth2TokenValidator<Jwt>>`, `AuthIssuers.decoders(Map<String, OAuth2TokenValidator<Jwt>>) : Map<String, JwtDecoder>`, `AuthIssuers.resolver(Map<String, JwtDecoder>, JwtAuthenticationConverter) : AuthenticationManagerResolver<HttpServletRequest>`. Bean `AuthenticationManagerResolver<HttpServletRequest> jwtAuthenticationManagerResolver` reemplaza al bean `JwtDecoder`.

- [ ] **Step 1: Write the failing test**

```java
package com.ones.api.configuration;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.server.resource.InvalidBearerTokenException;
import org.springframework.security.oauth2.server.resource.authentication.BearerTokenAuthenticationToken;

import com.nimbusds.jwt.JWTClaimsSet;
import com.nimbusds.jwt.PlainJWT;

class AuthIssuersTest {

    private static final String PROJECT = "ones-a96a7";
    private static final String FIREBASE_ISS = "https://securetoken.google.com/" + PROJECT;

    @Test
    void validators_withoutProjectId_onlyGoogleLegacy() {
        Map<String, OAuth2TokenValidator<Jwt>> v = AuthIssuers.validators(true, "client-1", "");

        assertEquals(List.of(AuthIssuers.GOOGLE_ISSUER), List.copyOf(v.keySet()));
    }

    @Test
    void validators_withProjectIdAndLegacyDisabled_onlyFirebase() {
        Map<String, OAuth2TokenValidator<Jwt>> v = AuthIssuers.validators(false, "client-1", PROJECT);

        assertEquals(List.of(FIREBASE_ISS), List.copyOf(v.keySet()));
        assertEquals(FIREBASE_ISS, AuthIssuers.firebaseIssuer(PROJECT));
    }

    @Test
    void validators_noneEnabled_failsAtStartup() {
        assertThrows(IllegalStateException.class, () -> AuthIssuers.validators(false, "client-1", " "));
    }

    @Test
    void firebaseValidator_acceptsTokenForProject() {
        OAuth2TokenValidator<Jwt> v = AuthIssuers.validators(false, "", PROJECT).get(FIREBASE_ISS);

        assertFalse(v.validate(jwt(FIREBASE_ISS, PROJECT)).hasErrors());
    }

    @Test
    void firebaseValidator_rejectsOtherAudience() {
        OAuth2TokenValidator<Jwt> v = AuthIssuers.validators(false, "", PROJECT).get(FIREBASE_ISS);

        assertTrue(v.validate(jwt(FIREBASE_ISS, "otro-proyecto")).hasErrors());
    }

    @Test
    void firebaseValidator_rejectsOtherIssuer() {
        OAuth2TokenValidator<Jwt> v = AuthIssuers.validators(false, "", PROJECT).get(FIREBASE_ISS);

        assertTrue(v.validate(jwt("https://securetoken.google.com/otro-proyecto", PROJECT)).hasErrors());
    }

    @Test
    void resolver_routesByIssuer_andUsesSubAsPrincipal() {
        JwtDecoder firebase = token -> jwt(FIREBASE_ISS, PROJECT);
        AuthenticationManager manager = AuthIssuers
                .resolver(Map.of(FIREBASE_ISS, firebase), new SecurityConfig().jwtAuthenticationConverter())
                .resolve(new MockHttpServletRequest());

        Authentication auth = manager.authenticate(new BearerTokenAuthenticationToken(plainToken(FIREBASE_ISS)));

        assertEquals("uid-1", auth.getName());
    }

    @Test
    void resolver_unknownIssuer_isRejected() {
        JwtDecoder firebase = token -> jwt(FIREBASE_ISS, PROJECT);
        AuthenticationManager manager = AuthIssuers
                .resolver(Map.of(FIREBASE_ISS, firebase), new SecurityConfig().jwtAuthenticationConverter())
                .resolve(new MockHttpServletRequest());

        assertThrows(InvalidBearerTokenException.class,
                () -> manager.authenticate(new BearerTokenAuthenticationToken(plainToken(AuthIssuers.GOOGLE_ISSUER))));
    }

    private static Jwt jwt(String issuer, String audience) {
        Instant now = Instant.now();
        return Jwt.withTokenValue("token")
                .header("alg", "RS256")
                .issuer(issuer)
                .audience(List.of(audience))
                .subject("uid-1")
                .issuedAt(now.minusSeconds(60))
                .expiresAt(now.plusSeconds(3600))
                .build();
    }

    private static String plainToken(String issuer) {
        return new PlainJWT(new JWTClaimsSet.Builder().issuer(issuer).subject("uid-1").build()).serialize();
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=AuthIssuersTest`
Expected: FAIL de compilación, `cannot find symbol: class AuthIssuers`.

- [ ] **Step 3: Write `AuthIssuers`**

```java
package com.ones.api.configuration;

import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import jakarta.servlet.http.HttpServletRequest;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.AuthenticationManagerResolver;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimNames;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationProvider;
import org.springframework.security.oauth2.server.resource.authentication.JwtIssuerAuthenticationManagerResolver;
import org.springframework.util.StringUtils;

/**
 * Emisores de ID tokens aceptados: Google directo (legado, apps anteriores a Firebase)
 * y Firebase Auth. Cada token se enruta por su claim iss a su propio decoder.
 */
final class AuthIssuers {

    static final String GOOGLE_ISSUER = "https://accounts.google.com";
    static final String GOOGLE_JWKS = "https://www.googleapis.com/oauth2/v3/certs";
    static final String FIREBASE_JWKS =
            "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

    private static final Logger log = LoggerFactory.getLogger(AuthIssuers.class);

    private AuthIssuers() {
    }

    static String firebaseIssuer(String projectId) {
        return "https://securetoken.google.com/" + projectId;
    }

    static Map<String, OAuth2TokenValidator<Jwt>> validators(
            boolean googleLegacyEnabled,
            String googleClientIds,
            String firebaseProjectId
    ) {
        Map<String, OAuth2TokenValidator<Jwt>> out = new LinkedHashMap<>();

        if (googleLegacyEnabled) {
            out.put(GOOGLE_ISSUER, new DelegatingOAuth2TokenValidatorWithAll<>(
                    JwtValidators.createDefaultWithIssuer(GOOGLE_ISSUER),
                    new GoogleAudienceValidator(googleClientIds)
            ));
        }

        if (StringUtils.hasText(firebaseProjectId)) {
            String projectId = firebaseProjectId.trim();
            String issuer = firebaseIssuer(projectId);
            out.put(issuer, new DelegatingOAuth2TokenValidatorWithAll<>(
                    JwtValidators.createDefaultWithIssuer(issuer),
                    new JwtClaimValidator<Collection<String>>(JwtClaimNames.AUD,
                            aud -> aud != null && aud.contains(projectId))
            ));
        } else {
            log.warn("[auth] FIREBASE_PROJECT_ID vacío: los tokens de Firebase serán rechazados");
        }

        if (out.isEmpty()) {
            throw new IllegalStateException(
                    "No hay emisores de autenticación habilitados: define FIREBASE_PROJECT_ID o GOOGLE_LEGACY_AUTH_ENABLED=true");
        }
        return out;
    }

    static Map<String, JwtDecoder> decoders(Map<String, OAuth2TokenValidator<Jwt>> validators) {
        Map<String, JwtDecoder> out = new LinkedHashMap<>();
        validators.forEach((issuer, validator) -> {
            String jwks = GOOGLE_ISSUER.equals(issuer) ? GOOGLE_JWKS : FIREBASE_JWKS;
            NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(jwks).build();
            decoder.setJwtValidator(validator);
            out.put(issuer, decoder);
        });
        return out;
    }

    static AuthenticationManagerResolver<HttpServletRequest> resolver(
            Map<String, JwtDecoder> decoders,
            JwtAuthenticationConverter converter
    ) {
        Map<String, AuthenticationManager> managers = new HashMap<>();
        decoders.forEach((issuer, decoder) -> {
            JwtAuthenticationProvider provider = new JwtAuthenticationProvider(decoder);
            provider.setJwtAuthenticationConverter(converter);
            managers.put(issuer, provider::authenticate);
        });
        // Un issuer no registrado devuelve null y Spring responde 401 "Invalid issuer".
        return new JwtIssuerAuthenticationManagerResolver(managers::get);
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=AuthIssuersTest`
Expected: PASS (8 tests).

- [ ] **Step 5: Wire it in `SecurityConfig`**

Reemplazar el bean `jwtDecoder(...)` completo por:

```java
    @Bean
    AuthenticationManagerResolver<HttpServletRequest> jwtAuthenticationManagerResolver(
            @Value("${GOOGLE_CLIENT_ID:${ones.auth.google.client-id:}}") String googleClientIds,
            @Value("${ones.auth.google-legacy.enabled:true}") boolean googleLegacyEnabled,
            @Value("${ones.auth.firebase.project-id:}") String firebaseProjectId,
            JwtAuthenticationConverter jwtAuthenticationConverter
    ) {
        Map<String, JwtDecoder> decoders = AuthIssuers.decoders(
                AuthIssuers.validators(googleLegacyEnabled, googleClientIds, firebaseProjectId));
        return AuthIssuers.resolver(decoders, jwtAuthenticationConverter);
    }
```

En `securityFilterChain`, cambiar los parámetros `JwtDecoder jwtDecoder, JwtAuthenticationConverter jwtAuthenticationConverter` por `AuthenticationManagerResolver<HttpServletRequest> jwtAuthenticationManagerResolver`, y el bloque `oauth2ResourceServer` por:

```java
                .oauth2ResourceServer(oauth2 -> oauth2
                        .authenticationManagerResolver(jwtAuthenticationManagerResolver)
                )
```

Imports: añadir `java.util.Map`, `jakarta.servlet.http.HttpServletRequest`, `org.springframework.security.authentication.AuthenticationManagerResolver`; quitar `OAuth2TokenValidator`, `JwtValidators`, `NimbusJwtDecoder` (ya no se usan aquí; `Jwt` y `JwtDecoder` siguen si el compilador lo pide, si no, quitarlos).

En `application.yml`, dentro de `ones.auth`, dejar:

```yaml
  auth:
    google:
      client-id: ${GOOGLE_CLIENT_ID:}
    google-legacy:
      enabled: ${GOOGLE_LEGACY_AUTH_ENABLED:true}
    firebase:
      project-id: ${FIREBASE_PROJECT_ID:}
      service-account-secret-name: ${FIREBASE_SERVICE_ACCOUNT_SECRET_NAME:}
```

- [ ] **Step 6: Run full suite**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test`
Expected: PASS, sin fallos.

- [ ] **Step 7: Commit**

```bash
git add services/ones-api/src/main/java/com/ones/api/configuration/AuthIssuers.java \
        services/ones-api/src/main/java/com/ones/api/configuration/SecurityConfig.java \
        services/ones-api/src/main/resources/application.yml \
        services/ones-api/src/test/java/com/ones/api/configuration/AuthIssuersTest.java
git commit -m "feat(api): aceptar ID tokens de Firebase en paralelo con Google legado"
```

---

### Task 2: Claims de Firebase y `provider` real en `ensure`

**Files:**
- Modify: `services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/AuthClaims.java`
- Modify: `services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/users/UsersController.java:58`
- Test: `services/ones-api/src/test/java/com/ones/api/adapters/inbound/rest/AuthClaimsTest.java`

**Interfaces:**
- Produces: `AuthClaims.isFirebase(Authentication) : boolean`, `AuthClaims.provider(Authentication) : String` (`"google.com" | "apple.com" | "password" | ...`, o `"google"` para tokens legados), `AuthClaims.emailVerified(Authentication) : boolean`, `AuthClaims.googleIdentity(Authentication) : String` (o `null`).

- [ ] **Step 1: Write the failing tests** (añadir a `AuthClaimsTest`, que ya tiene `authWithClaims(Map)`; añadir imports `java.util.List`, `static org.junit.jupiter.api.Assertions.assertFalse`, `static org.junit.jupiter.api.Assertions.assertTrue`, `static org.junit.jupiter.api.Assertions.assertNull`)

```java
    @Test
    void provider_legacyGoogleToken_isGoogle() {
        Authentication auth = authWithClaims(Map.of("email", "a@b.com"));

        assertFalse(AuthClaims.isFirebase(auth));
        assertEquals("google", AuthClaims.provider(auth));
    }

    @Test
    void provider_firebaseToken_usesSignInProvider() {
        Authentication auth = authWithClaims(Map.of("firebase", Map.of("sign_in_provider", "password")));

        assertTrue(AuthClaims.isFirebase(auth));
        assertEquals("password", AuthClaims.provider(auth));
    }

    @Test
    void emailVerified_readsBooleanClaim() {
        assertTrue(AuthClaims.emailVerified(authWithClaims(Map.of("email_verified", true))));
        assertFalse(AuthClaims.emailVerified(authWithClaims(Map.of("email_verified", false))));
        assertFalse(AuthClaims.emailVerified(authWithClaims(Map.of())));
    }

    @Test
    void googleIdentity_returnsFirstGoogleSub() {
        Authentication auth = authWithClaims(Map.of("firebase", Map.of(
                "sign_in_provider", "google.com",
                "identities", Map.of("google.com", List.of("1234567890"), "email", List.of("a@b.com"))
        )));

        assertEquals("1234567890", AuthClaims.googleIdentity(auth));
    }

    @Test
    void googleIdentity_withoutGoogleIdentity_isNull() {
        Authentication auth = authWithClaims(Map.of("firebase", Map.of(
                "sign_in_provider", "password",
                "identities", Map.of("email", List.of("a@b.com"))
        )));

        assertNull(AuthClaims.googleIdentity(auth));
        assertNull(AuthClaims.googleIdentity(authWithClaims(Map.of())));
    }
```

- [ ] **Step 2: Run test to verify it fails**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=AuthClaimsTest`
Expected: FAIL de compilación, `cannot find symbol: method isFirebase`.

- [ ] **Step 3: Implement in `AuthClaims`** (antes de `getJwt`; añadir imports `java.util.List`, `java.util.Map`)

```java
    public static boolean isFirebase(Authentication authentication) {
        return firebaseClaim(authentication) != null;
    }

    /** Proveedor de inicio de sesión: firebase.sign_in_provider, o "google" para tokens de Google directos. */
    public static String provider(Authentication authentication) {
        Map<?, ?> firebase = firebaseClaim(authentication);
        Object value = firebase != null ? firebase.get("sign_in_provider") : null;
        return value != null ? value.toString() : "google";
    }

    public static boolean emailVerified(Authentication authentication) {
        Jwt jwt = getJwt(authentication);
        Object value = jwt != null ? jwt.getClaims().get("email_verified") : null;
        return Boolean.TRUE.equals(value) || "true".equals(String.valueOf(value));
    }

    /** sub de Google vinculado al usuario de Firebase (firebase.identities["google.com"][0]), o null. */
    public static String googleIdentity(Authentication authentication) {
        Map<?, ?> firebase = firebaseClaim(authentication);
        if (firebase == null || !(firebase.get("identities") instanceof Map<?, ?> identities)) {
            return null;
        }
        if (identities.get("google.com") instanceof List<?> ids && !ids.isEmpty() && ids.get(0) != null) {
            return ids.get(0).toString();
        }
        return null;
    }

    private static Map<?, ?> firebaseClaim(Authentication authentication) {
        Jwt jwt = getJwt(authentication);
        Object value = jwt != null ? jwt.getClaims().get("firebase") : null;
        return value instanceof Map<?, ?> map ? map : null;
    }
```

En `UsersController.ensure`, reemplazar la línea `"google",` por:

```java
                AuthClaims.provider(authentication),
```

- [ ] **Step 4: Run tests**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=AuthClaimsTest`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/AuthClaims.java \
        services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/users/UsersController.java \
        services/ones-api/src/test/java/com/ones/api/adapters/inbound/rest/AuthClaimsTest.java
git commit -m "feat(api): leer proveedor, correo verificado e identidad de Google de tokens Firebase"
```

---

### Task 3: `EmailVerifiedFilter`

**Files:**
- Create: `services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/EmailVerifiedFilter.java`
- Modify: `services/ones-api/src/main/java/com/ones/api/configuration/SecurityConfig.java` (cadena principal)
- Test: `services/ones-api/src/test/java/com/ones/api/adapters/inbound/rest/EmailVerifiedFilterTest.java`

**Interfaces:**
- Consumes: `AuthClaims.provider`, `AuthClaims.emailVerified` (Task 2).
- Produces: `EmailVerifiedFilter` (constructor sin argumentos), `EmailVerifiedFilter.CODE = "EMAIL_NOT_VERIFIED"`.

- [ ] **Step 1: Write the failing test**

```java
package com.ones.api.adapters.inbound.rest;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

class EmailVerifiedFilterTest {

    private final EmailVerifiedFilter filter = new EmailVerifiedFilter();

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void unverifiedPasswordAccount_isRejectedEvenOnEnsure() throws Exception {
        authenticate("password", false);
        AtomicBoolean chained = new AtomicBoolean(false);
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(new MockHttpServletRequest("POST", "/v1/users/ensure"), res, (q, r) -> chained.set(true));

        assertFalse(chained.get());
        assertEquals(403, res.getStatus());
        assertTrue(res.getContentAsString().contains("\"code\":\"EMAIL_NOT_VERIFIED\""));
    }

    @Test
    void verifiedPasswordAccount_passes() throws Exception {
        assertPasses("password", true);
    }

    @Test
    void googleAndAppleAccounts_passWithoutVerifiedClaim() throws Exception {
        assertPasses("google.com", false);
        assertPasses("apple.com", false);
    }

    @Test
    void legacyGoogleToken_passes() throws Exception {
        Jwt jwt = Jwt.withTokenValue("t").header("alg", "none").claim("sub", "u1").build();
        SecurityContextHolder.getContext().setAuthentication(new JwtAuthenticationToken(jwt, List.of(), "u1"));
        AtomicBoolean chained = new AtomicBoolean(false);

        filter.doFilter(new MockHttpServletRequest("GET", "/v1/events"), new MockHttpServletResponse(), (q, r) -> chained.set(true));

        assertTrue(chained.get());
    }

    private void assertPasses(String provider, boolean verified) throws Exception {
        authenticate(provider, verified);
        AtomicBoolean chained = new AtomicBoolean(false);

        filter.doFilter(new MockHttpServletRequest("GET", "/v1/events"), new MockHttpServletResponse(), (q, r) -> chained.set(true));

        assertTrue(chained.get(), provider);
    }

    private static void authenticate(String provider, boolean verified) {
        Jwt jwt = Jwt.withTokenValue("t")
                .header("alg", "none")
                .claim("sub", "u1")
                .claim("email_verified", verified)
                .claim("firebase", Map.of("sign_in_provider", provider))
                .build();
        SecurityContextHolder.getContext().setAuthentication(new JwtAuthenticationToken(jwt, List.of(), "u1"));
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=EmailVerifiedFilterTest`
Expected: FAIL de compilación, `cannot find symbol: class EmailVerifiedFilter`.

- [ ] **Step 3: Implement**

```java
package com.ones.api.adapters.inbound.rest;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * Rechaza con 403 las cuentas de correo/contraseña de Firebase que aún no verificaron su correo.
 * Se responde 403 (no 401) para que el cliente no lo confunda con un token expirado.
 */
public class EmailVerifiedFilter extends OncePerRequestFilter {

    public static final String CODE = "EMAIL_NOT_VERIFIED";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth instanceof JwtAuthenticationToken
                && "password".equals(AuthClaims.provider(auth))
                && !AuthClaims.emailVerified(auth)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.setCharacterEncoding(StandardCharsets.UTF_8.name());
            response.getWriter().write("{\"code\":\"" + CODE + "\"}");
            response.getWriter().flush();
            return;
        }
        chain.doFilter(request, response);
    }
}
```

En `SecurityConfig.securityFilterChain`, reemplazar la línea `.addFilterAfter(new DisabledAccountFilter(...), BearerTokenAuthenticationFilter.class);` (y su comentario) por:

```java
                // Orden tras autenticar el JWT: correo verificado → cuentas desactivadas.
                .addFilterAfter(new EmailVerifiedFilter(), BearerTokenAuthenticationFilter.class)
                .addFilterAfter(new DisabledAccountFilter(accountAccessService), EmailVerifiedFilter.class);
```

Añadir el import `com.ones.api.adapters.inbound.rest.EmailVerifiedFilter`.

- [ ] **Step 4: Run tests**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/EmailVerifiedFilter.java \
        services/ones-api/src/main/java/com/ones/api/configuration/SecurityConfig.java \
        services/ones-api/src/test/java/com/ones/api/adapters/inbound/rest/EmailVerifiedFilterTest.java
git commit -m "feat(api): exigir correo verificado a cuentas de correo/contraseña"
```

---

### Task 4: `ensure` responde conflicto en vez de borrar usuarios reales

**Files:**
- Create: `services/ones-api/src/main/java/com/ones/api/application/users/EmailConflictException.java`
- Modify: `services/ones-api/src/main/java/com/ones/api/application/users/EnsureUserUseCase.java` (rama `orElseGet`)
- Modify: `services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/ApiExceptionHandler.java`
- Test: `services/ones-api/src/test/java/com/ones/api/application/users/EnsureUserUseCaseTest.java`

**Interfaces:**
- Produces: `EmailConflictException extends RuntimeException` (constructor sin argumentos). Respuesta HTTP 409 `{"code":"EMAIL_CONFLICT","error":"email_conflict","message":"..."}`.

- [ ] **Step 1: Write the failing test**

```java
package com.ones.api.application.users;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

class EnsureUserUseCaseTest {

    private static final Instant T0 = Instant.parse("2026-01-01T00:00:00Z");
    private static final Instant NOW = Instant.parse("2026-10-01T00:00:00Z");

    private final InMemoryUsersRepository repo = new InMemoryUsersRepository();
    private final EnsureUserUseCase useCase = new EnsureUserUseCase(repo, Clock.fixed(NOW, ZoneOffset.UTC));

    @Test
    void newUser_isCreatedWithProvider() {
        User u = useCase.execute(command("uid-1", "new@example.com", "password"));

        assertEquals("password", u.getProvider());
        assertTrue(repo.findById("uid-1").isPresent());
    }

    @Test
    void emailOfAnotherRealUser_throwsConflict_andDeletesNothing() {
        repo.upsert(new User("google-sub-1", "a@example.com", "Ana", null, null, null, "Ana", "google", "es", true, T0, T0));

        assertThrows(EmailConflictException.class, () -> useCase.execute(command("firebase-uid-9", "A@Example.com", "apple.com")));

        assertTrue(repo.findById("google-sub-1").isPresent());
        assertTrue(repo.findById("firebase-uid-9").isEmpty());
    }

    @Test
    void stubFromInvitation_isStillMergedIntoNewUser() {
        repo.upsert(new User("stub-uuid", "guest@example.com", null, null, null, null, null, "stub", null, false, T0, T0));

        User u = useCase.execute(command("uid-2", "guest@example.com", "google.com"));

        assertEquals("uid-2", u.getUserId());
        assertEquals(T0, u.getCreatedAt());
        assertTrue(repo.findById("stub-uuid").isEmpty());
    }

    private static EnsureUserCommand command(String uid, String email, String provider) {
        return new EnsureUserCommand(uid, email, null, null, null, null, provider, null);
    }

    private static class InMemoryUsersRepository implements UsersRepository {
        private final Map<String, User> byId = new HashMap<>();

        @Override public Optional<User> findById(String userId) { return Optional.ofNullable(byId.get(userId)); }
        @Override public Optional<User> findByEmail(String email) {
            return byId.values().stream().filter(u -> email.equalsIgnoreCase(u.getEmail())).findFirst();
        }
        @Override public User upsert(User user) { byId.put(user.getUserId(), user); return user; }
        @Override public void deleteById(String userId) { byId.remove(userId); }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=EnsureUserUseCaseTest`
Expected: FAIL de compilación, `cannot find symbol: class EmailConflictException`.

- [ ] **Step 3: Implement**

`EmailConflictException.java`:

```java
package com.ones.api.application.users;

/** El correo del token ya pertenece a otro usuario real (no stub) con distinto userId. */
public class EmailConflictException extends RuntimeException {

    public EmailConflictException() {
        super("El correo ya está asociado a otra cuenta");
    }
}
```

En `EnsureUserUseCase.execute`, dentro de `orElseGet`, justo después de calcular `existingByEmail`, insertar:

```java
                    // Solo se fusionan los usuarios stub creados por invitaciones. Fusionar una cuenta real
                    // borraría su fila y dejaría huérfanos sus eventos y fotos.
                    if (existingByEmail != null && !"stub".equals(existingByEmail.getProvider())) {
                        throw new EmailConflictException();
                    }
```

En `ApiExceptionHandler`, junto a los demás handlers 409 (import `com.ones.api.application.users.EmailConflictException`):

```java
    @ExceptionHandler(EmailConflictException.class)
    public ResponseEntity<Map<String, Object>> emailConflict(EmailConflictException ex) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of(
                "code", "EMAIL_CONFLICT",
                "error", "email_conflict",
                "message", ex.getMessage()
        ));
    }
```

- [ ] **Step 4: Run tests**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add services/ones-api/src/main/java/com/ones/api/application/users/EmailConflictException.java \
        services/ones-api/src/main/java/com/ones/api/application/users/EnsureUserUseCase.java \
        services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/ApiExceptionHandler.java \
        services/ones-api/src/test/java/com/ones/api/application/users/EnsureUserUseCaseTest.java
git commit -m "fix(api): ensure no borra cuentas reales por coincidencia de correo (409 EMAIL_CONFLICT)"
```

---

### Task 5: Cliente de Identity Toolkit (Firebase) con service account

**Files:**
- Modify: `services/ones-api/pom.xml` (dependencia)
- Create: `services/ones-api/src/main/java/com/ones/api/application/users/ports/FirebaseIdentityAdmin.java`
- Create: `services/ones-api/src/main/java/com/ones/api/adapters/outbound/firebase/FirebaseIdentityToolkitClient.java`
- Test: `services/ones-api/src/test/java/com/ones/api/adapters/outbound/firebase/FirebaseIdentityToolkitClientTest.java`

**Interfaces:**
- Produces:
  ```java
  public interface FirebaseIdentityAdmin {
      boolean isConfigured();
      /** Borra el usuario de Firebase newUid e importa uno con uid = legacy.userId() vinculado a google.com. */
      void replaceWithLegacyGoogleUser(String newUid, LegacyGoogleUser legacy);
      record LegacyGoogleUser(String userId, String email, String displayName, String photoUrl) {}
  }
  ```
  Implementación `@Component FirebaseIdentityToolkitClient`, con helpers estáticos de paquete `batchCreateBody(LegacyGoogleUser) : Map<String, Object>` y `importErrors(JsonNode) : List<String>`.

- [ ] **Step 1: Add the dependency** (en `<dependencies>` de `pom.xml`)

```xml
        <dependency>
            <groupId>com.google.auth</groupId>
            <artifactId>google-auth-library-oauth2-http</artifactId>
            <version>1.54.0</version>
        </dependency>
```

- [ ] **Step 2: Write the failing test**

```java
package com.ones.api.adapters.outbound.firebase;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.web.reactive.function.client.WebClient;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.application.events.ports.SecretsProvider;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin.LegacyGoogleUser;

class FirebaseIdentityToolkitClientTest {

    private final ObjectMapper mapper = new ObjectMapper();

    @Test
    void batchCreateBody_linksGoogleProviderWithLegacyUid() throws Exception {
        Map<String, Object> body = FirebaseIdentityToolkitClient.batchCreateBody(
                new LegacyGoogleUser("google-sub-1", "a@example.com", "Ana", "https://img/a.png"));

        String json = mapper.writeValueAsString(body);
        assertEquals(
                "{\"users\":[{\"localId\":\"google-sub-1\",\"email\":\"a@example.com\",\"emailVerified\":true,"
                        + "\"displayName\":\"Ana\",\"photoUrl\":\"https://img/a.png\",\"providerUserInfo\":[{"
                        + "\"providerId\":\"google.com\",\"rawId\":\"google-sub-1\",\"email\":\"a@example.com\","
                        + "\"displayName\":\"Ana\",\"photoUrl\":\"https://img/a.png\"}]}]}",
                json);
    }

    @Test
    void batchCreateBody_omitsNullFields() throws Exception {
        String json = mapper.writeValueAsString(FirebaseIdentityToolkitClient.batchCreateBody(
                new LegacyGoogleUser("g-2", "b@example.com", null, null)));

        assertFalse(json.contains("displayName"));
        assertFalse(json.contains("photoUrl"));
    }

    @Test
    void importErrors_readsPerUserErrors() throws Exception {
        assertEquals(List.of("DUPLICATE_LOCAL_ID"), FirebaseIdentityToolkitClient.importErrors(
                mapper.readTree("{\"error\":[{\"index\":0,\"message\":\"DUPLICATE_LOCAL_ID\"}]}")));
        assertTrue(FirebaseIdentityToolkitClient.importErrors(mapper.readTree("{}")).isEmpty());
    }

    @Test
    void isConfigured_requiresProjectAndSecretName() {
        SecretsProvider secrets = mock(SecretsProvider.class);

        assertFalse(new FirebaseIdentityToolkitClient(WebClient.builder(), secrets, "ones-a96a7", "").isConfigured());
        assertFalse(new FirebaseIdentityToolkitClient(WebClient.builder(), secrets, "", "arn:secret").isConfigured());
        assertTrue(new FirebaseIdentityToolkitClient(WebClient.builder(), secrets, "ones-a96a7", "arn:secret").isConfigured());
    }
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=FirebaseIdentityToolkitClientTest`
Expected: FAIL de compilación, `package com.ones.api.application.users.ports.FirebaseIdentityAdmin does not exist`.

- [ ] **Step 4: Implement**

`FirebaseIdentityAdmin.java`:

```java
package com.ones.api.application.users.ports;

/** Operaciones administrativas sobre usuarios de Firebase Auth necesarias para migrar cuentas legadas. */
public interface FirebaseIdentityAdmin {

    boolean isConfigured();

    /** Borra el usuario de Firebase {@code newUid} e importa uno con uid = {@code legacy.userId()} vinculado a google.com. */
    void replaceWithLegacyGoogleUser(String newUid, LegacyGoogleUser legacy);

    record LegacyGoogleUser(String userId, String email, String displayName, String photoUrl) {
    }
}
```

`FirebaseIdentityToolkitClient.java`:

```java
package com.ones.api.adapters.outbound.firebase;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;
import org.springframework.web.reactive.function.client.WebClient;

import com.fasterxml.jackson.databind.JsonNode;
import com.google.auth.oauth2.GoogleCredentials;
import com.ones.api.application.events.ports.SecretsProvider;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin;

/** Cliente REST de Identity Toolkit (Firebase Auth) autenticado con una service account de Secrets Manager. */
@Component
public class FirebaseIdentityToolkitClient implements FirebaseIdentityAdmin {

    private static final String SCOPE = "https://www.googleapis.com/auth/cloud-platform";
    private static final Duration TIMEOUT = Duration.ofSeconds(15);

    private final WebClient webClient;
    private final SecretsProvider secretsProvider;
    private final String projectId;
    private final String serviceAccountSecretName;
    private volatile GoogleCredentials credentials;

    public FirebaseIdentityToolkitClient(
            WebClient.Builder builder,
            SecretsProvider secretsProvider,
            @Value("${ones.auth.firebase.project-id:}") String projectId,
            @Value("${ones.auth.firebase.service-account-secret-name:}") String serviceAccountSecretName
    ) {
        this.webClient = builder.baseUrl("https://identitytoolkit.googleapis.com").build();
        this.secretsProvider = secretsProvider;
        this.projectId = projectId != null ? projectId.trim() : "";
        this.serviceAccountSecretName = serviceAccountSecretName != null ? serviceAccountSecretName.trim() : "";
    }

    @Override
    public boolean isConfigured() {
        return StringUtils.hasText(projectId) && StringUtils.hasText(serviceAccountSecretName);
    }

    @Override
    public void replaceWithLegacyGoogleUser(String newUid, LegacyGoogleUser legacy) {
        String token = accessToken();

        // Primero se borra el usuario nuevo: tiene la identidad google.com que el importado necesita.
        post("/v1/projects/" + projectId + "/accounts:delete", Map.of("localId", newUid), token);

        JsonNode result = post("/v1/projects/" + projectId + "/accounts:batchCreate", batchCreateBody(legacy), token);
        List<String> errors = importErrors(result);
        if (!errors.isEmpty()) {
            throw new IllegalStateException("Firebase batchCreate falló para " + legacy.userId() + ": " + errors);
        }
    }

    static Map<String, Object> batchCreateBody(LegacyGoogleUser legacy) {
        Map<String, Object> provider = new LinkedHashMap<>();
        provider.put("providerId", "google.com");
        provider.put("rawId", legacy.userId());
        putIfPresent(provider, "email", legacy.email());
        putIfPresent(provider, "displayName", legacy.displayName());
        putIfPresent(provider, "photoUrl", legacy.photoUrl());

        Map<String, Object> user = new LinkedHashMap<>();
        user.put("localId", legacy.userId());
        putIfPresent(user, "email", legacy.email());
        user.put("emailVerified", true);
        putIfPresent(user, "displayName", legacy.displayName());
        putIfPresent(user, "photoUrl", legacy.photoUrl());
        user.put("providerUserInfo", List.of(provider));

        return Map.of("users", List.of(user));
    }

    static List<String> importErrors(JsonNode result) {
        List<String> out = new ArrayList<>();
        if (result != null && result.path("error").isArray()) {
            result.path("error").forEach(e -> out.add(e.path("message").asText()));
        }
        return out;
    }

    private JsonNode post(String path, Object body, String token) {
        return webClient.post()
                .uri(path)
                .headers(h -> h.setBearerAuth(token))
                .contentType(MediaType.APPLICATION_JSON)
                .bodyValue(body)
                .retrieve()
                .bodyToMono(JsonNode.class)
                .block(TIMEOUT);
    }

    private String accessToken() {
        try {
            GoogleCredentials c = credentials;
            if (c == null) {
                String json = secretsProvider.getSecretString(serviceAccountSecretName);
                c = GoogleCredentials
                        .fromStream(new ByteArrayInputStream(json.getBytes(StandardCharsets.UTF_8)))
                        .createScoped(List.of(SCOPE));
                credentials = c;
            }
            c.refreshIfExpired();
            return c.getAccessToken().getTokenValue();
        } catch (IOException e) {
            throw new IllegalStateException("No se pudo obtener token de la service account de Firebase", e);
        }
    }

    private static void putIfPresent(Map<String, Object> map, String key, String value) {
        if (value != null && !value.isBlank()) {
            map.put(key, value);
        }
    }
}
```

- [ ] **Step 5: Run tests**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add services/ones-api/pom.xml \
        services/ones-api/src/main/java/com/ones/api/application/users/ports/FirebaseIdentityAdmin.java \
        services/ones-api/src/main/java/com/ones/api/adapters/outbound/firebase/FirebaseIdentityToolkitClient.java \
        services/ones-api/src/test/java/com/ones/api/adapters/outbound/firebase/FirebaseIdentityToolkitClientTest.java
git commit -m "feat(api): cliente de Identity Toolkit para reemplazar usuarios de Firebase"
```

---

### Task 6: Migración bajo demanda (`AccountMigrationService` + filtro)

**Files:**
- Create: `services/ones-api/src/main/java/com/ones/api/application/users/AccountMigrationService.java`
- Create: `services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/LegacyAccountMigrationFilter.java`
- Modify: `services/ones-api/src/main/java/com/ones/api/configuration/SecurityConfig.java`
- Test: `services/ones-api/src/test/java/com/ones/api/application/users/AccountMigrationServiceTest.java`
- Test: `services/ones-api/src/test/java/com/ones/api/adapters/inbound/rest/LegacyAccountMigrationFilterTest.java`

**Interfaces:**
- Consumes: `FirebaseIdentityAdmin` (Task 5), `AuthClaims.isFirebase`, `AuthClaims.googleIdentity` (Task 2), `EmailVerifiedFilter` (Task 3).
- Produces: `@Service AccountMigrationService(UsersRepository, FirebaseIdentityAdmin)` con `Outcome migrateIfLegacy(String uid, String googleSub)`, `enum Outcome { NONE, MIGRATED, NOT_CONFIGURED }`. `LegacyAccountMigrationFilter(AccountMigrationService)` con códigos `ACCOUNT_MIGRATED` (409) y `ACCOUNT_MIGRATION_FAILED` (503).

- [ ] **Step 1: Write the failing service test**

```java
package com.ones.api.application.users;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.users.AccountMigrationService.Outcome;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin.LegacyGoogleUser;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

class AccountMigrationServiceTest {

    private static final Instant T0 = Instant.parse("2026-01-01T00:00:00Z");

    private final InMemoryUsersRepository repo = new InMemoryUsersRepository();
    private final FirebaseIdentityAdmin admin = mock(FirebaseIdentityAdmin.class);
    private final AccountMigrationService service = new AccountMigrationService(repo, admin);

    @Test
    void legacyGoogleUser_withNewFirebaseUid_isMigrated() {
        when(admin.isConfigured()).thenReturn(true);
        repo.upsert(user("google-sub-1"));

        assertEquals(Outcome.MIGRATED, service.migrateIfLegacy("firebase-uid-9", "google-sub-1"));

        verify(admin).replaceWithLegacyGoogleUser("firebase-uid-9",
                new LegacyGoogleUser("google-sub-1", "google-sub-1@example.com", "Ana", "https://img/a.png"));
    }

    @Test
    void alreadyMigratedUser_uidEqualsGoogleSub_doesNothing() {
        repo.upsert(user("google-sub-1"));

        assertEquals(Outcome.NONE, service.migrateIfLegacy("google-sub-1", "google-sub-1"));
        verify(admin, never()).replaceWithLegacyGoogleUser(anyString(), any());
    }

    @Test
    void brandNewGoogleUser_withoutLegacyRow_doesNothing() {
        assertEquals(Outcome.NONE, service.migrateIfLegacy("firebase-uid-9", "google-sub-new"));
        verify(admin, never()).replaceWithLegacyGoogleUser(anyString(), any());
    }

    @Test
    void firebaseUidThatAlreadyHasRow_doesNothing() {
        repo.upsert(user("firebase-uid-9"));
        repo.upsert(user("google-sub-1"));

        assertEquals(Outcome.NONE, service.migrateIfLegacy("firebase-uid-9", "google-sub-1"));
    }

    @Test
    void nonGoogleAccount_doesNothing() {
        assertEquals(Outcome.NONE, service.migrateIfLegacy("firebase-uid-9", null));
    }

    @Test
    void notConfigured_neverCallsFirebase() {
        when(admin.isConfigured()).thenReturn(false);
        repo.upsert(user("google-sub-1"));

        assertEquals(Outcome.NOT_CONFIGURED, service.migrateIfLegacy("firebase-uid-9", "google-sub-1"));
        verify(admin, never()).replaceWithLegacyGoogleUser(anyString(), any());
    }

    private static User user(String id) {
        return new User(id, id + "@example.com", "Ana", null, null, "https://img/a.png", "Ana", "google", "es", true, T0, T0);
    }

    private static class InMemoryUsersRepository implements UsersRepository {
        private final Map<String, User> byId = new HashMap<>();

        @Override public Optional<User> findById(String userId) { return Optional.ofNullable(byId.get(userId)); }
        @Override public Optional<User> findByEmail(String email) { return Optional.empty(); }
        @Override public User upsert(User user) { byId.put(user.getUserId(), user); return user; }
        @Override public void deleteById(String userId) { byId.remove(userId); }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=AccountMigrationServiceTest`
Expected: FAIL de compilación, `cannot find symbol: class AccountMigrationService`.

- [ ] **Step 3: Implement `AccountMigrationService`**

```java
package com.ones.api.application.users;

import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.ones.api.application.users.ports.FirebaseIdentityAdmin;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin.LegacyGoogleUser;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

/**
 * Migra bajo demanda a usuarios de Google anteriores a Firebase: si Firebase les asignó un uid nuevo,
 * se reemplaza ese usuario por uno con uid = sub de Google (el userId que ya usan todas las tablas).
 * La identidad google.com del token la firma Firebase, lo que prueba que es la misma cuenta.
 */
@Service
public class AccountMigrationService {

    public enum Outcome { NONE, MIGRATED, NOT_CONFIGURED }

    private static final Logger log = LoggerFactory.getLogger(AccountMigrationService.class);

    private final UsersRepository usersRepository;
    private final FirebaseIdentityAdmin firebaseIdentityAdmin;

    public AccountMigrationService(UsersRepository usersRepository, FirebaseIdentityAdmin firebaseIdentityAdmin) {
        this.usersRepository = usersRepository;
        this.firebaseIdentityAdmin = firebaseIdentityAdmin;
    }

    public Outcome migrateIfLegacy(String uid, String googleSub) {
        if (googleSub == null || googleSub.isBlank() || googleSub.equals(uid)) {
            return Outcome.NONE;
        }
        if (usersRepository.findById(uid).isPresent()) {
            return Outcome.NONE;
        }
        Optional<User> legacy = usersRepository.findById(googleSub);
        if (legacy.isEmpty()) {
            return Outcome.NONE;
        }
        if (!firebaseIdentityAdmin.isConfigured()) {
            log.error("[migration] usuario legado {} entró con uid {} pero la service account de Firebase no está configurada",
                    googleSub, uid);
            return Outcome.NOT_CONFIGURED;
        }

        User u = legacy.get();
        firebaseIdentityAdmin.replaceWithLegacyGoogleUser(uid,
                new LegacyGoogleUser(u.getUserId(), u.getEmail(), u.getName(), u.getPicture()));
        log.info("[migration] uid Firebase {} reemplazado por usuario legado {}", uid, googleSub);
        return Outcome.MIGRATED;
    }
}
```

- [ ] **Step 4: Run test**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=AccountMigrationServiceTest`
Expected: PASS (6 tests).

- [ ] **Step 5: Write the failing filter test**

```java
package com.ones.api.adapters.inbound.rest;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.util.List;
import java.util.Map;
import java.util.concurrent.atomic.AtomicBoolean;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import com.ones.api.application.users.AccountMigrationService;
import com.ones.api.application.users.AccountMigrationService.Outcome;

class LegacyAccountMigrationFilterTest {

    private final AccountMigrationService service = mock(AccountMigrationService.class);
    private final LegacyAccountMigrationFilter filter = new LegacyAccountMigrationFilter(service);

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void migrated_respondsConflictWithCode() throws Exception {
        authenticateFirebase("firebase-uid-9", "google-sub-1");
        when(service.migrateIfLegacy("firebase-uid-9", "google-sub-1")).thenReturn(Outcome.MIGRATED);
        AtomicBoolean chained = new AtomicBoolean(false);
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(request("GET", "/v1/users/me/preferences"), res, (q, r) -> chained.set(true));

        assertFalse(chained.get());
        assertEquals(409, res.getStatus());
        assertTrue(res.getContentAsString().contains("\"code\":\"ACCOUNT_MIGRATED\""));
    }

    @Test
    void migrationError_respondsServiceUnavailable() throws Exception {
        authenticateFirebase("firebase-uid-9", "google-sub-1");
        when(service.migrateIfLegacy(anyString(), anyString())).thenThrow(new IllegalStateException("boom"));
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(request("POST", "/v1/users/ensure"), res, (q, r) -> { });

        assertEquals(503, res.getStatus());
        assertTrue(res.getContentAsString().contains("\"code\":\"ACCOUNT_MIGRATION_FAILED\""));
    }

    @Test
    void noMigration_passesThrough() throws Exception {
        authenticateFirebase("uid-1", "uid-1");
        when(service.migrateIfLegacy("uid-1", "uid-1")).thenReturn(Outcome.NONE);
        AtomicBoolean chained = new AtomicBoolean(false);

        filter.doFilter(request("POST", "/v1/users/ensure"), new MockHttpServletResponse(), (q, r) -> chained.set(true));

        assertTrue(chained.get());
    }

    @Test
    void otherPaths_areNotChecked() throws Exception {
        authenticateFirebase("firebase-uid-9", "google-sub-1");
        AtomicBoolean chained = new AtomicBoolean(false);

        filter.doFilter(request("GET", "/v1/events"), new MockHttpServletResponse(), (q, r) -> chained.set(true));

        assertTrue(chained.get());
        verify(service, never()).migrateIfLegacy(anyString(), any());
    }

    @Test
    void legacyGoogleTokens_areNotChecked() throws Exception {
        Jwt jwt = Jwt.withTokenValue("t").header("alg", "none").claim("sub", "google-sub-1").build();
        SecurityContextHolder.getContext().setAuthentication(new JwtAuthenticationToken(jwt, List.of(), "google-sub-1"));
        AtomicBoolean chained = new AtomicBoolean(false);

        filter.doFilter(request("POST", "/v1/users/ensure"), new MockHttpServletResponse(), (q, r) -> chained.set(true));

        assertTrue(chained.get());
        verify(service, never()).migrateIfLegacy(anyString(), any());
    }

    private static MockHttpServletRequest request(String method, String path) {
        MockHttpServletRequest req = new MockHttpServletRequest(method, path);
        req.setServletPath(path);
        return req;
    }

    private static void authenticateFirebase(String uid, String googleSub) {
        Jwt jwt = Jwt.withTokenValue("t")
                .header("alg", "none")
                .claim("sub", uid)
                .claim("firebase", Map.of(
                        "sign_in_provider", "google.com",
                        "identities", Map.of("google.com", List.of(googleSub))))
                .build();
        SecurityContextHolder.getContext().setAuthentication(new JwtAuthenticationToken(jwt, List.of(), uid));
    }
}
```

- [ ] **Step 6: Run test to verify it fails**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test -Dtest=LegacyAccountMigrationFilterTest`
Expected: FAIL de compilación, `cannot find symbol: class LegacyAccountMigrationFilter`.

- [ ] **Step 7: Implement the filter**

```java
package com.ones.api.adapters.inbound.rest;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.filter.OncePerRequestFilter;

import com.ones.api.application.users.AccountMigrationService;
import com.ones.api.application.users.AccountMigrationService.Outcome;

/**
 * Migra usuarios de Google legados la primera vez que entran con Firebase. Solo revisa /v1/users/**,
 * que la app siempre consulta al iniciar sesión. Tras 409 ACCOUNT_MIGRATED el cliente vuelve a iniciar
 * sesión en Firebase con la misma credencial de Google y recibe el uid legado.
 */
public class LegacyAccountMigrationFilter extends OncePerRequestFilter {

    public static final String CODE_MIGRATED = "ACCOUNT_MIGRATED";
    public static final String CODE_FAILED = "ACCOUNT_MIGRATION_FAILED";

    private static final Logger log = LoggerFactory.getLogger(LegacyAccountMigrationFilter.class);

    private final AccountMigrationService accountMigrationService;

    public LegacyAccountMigrationFilter(AccountMigrationService accountMigrationService) {
        this.accountMigrationService = accountMigrationService;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        if (path == null || path.isEmpty()) {
            path = request.getRequestURI();
        }
        return !path.startsWith("/v1/users/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (!(auth instanceof JwtAuthenticationToken) || !AuthClaims.isFirebase(auth)) {
            chain.doFilter(request, response);
            return;
        }

        Outcome outcome;
        try {
            outcome = accountMigrationService.migrateIfLegacy(auth.getName(), AuthClaims.googleIdentity(auth));
        } catch (RuntimeException e) {
            log.error("[migration] falló la migración del uid {}", auth.getName(), e);
            write(response, HttpServletResponse.SC_SERVICE_UNAVAILABLE, CODE_FAILED);
            return;
        }

        if (outcome == Outcome.MIGRATED) {
            write(response, HttpServletResponse.SC_CONFLICT, CODE_MIGRATED);
            return;
        }
        chain.doFilter(request, response);
    }

    private static void write(HttpServletResponse response, int status, String code) throws IOException {
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write("{\"code\":\"" + code + "\"}");
        response.getWriter().flush();
    }
}
```

En `SecurityConfig.securityFilterChain`: añadir el parámetro `AccountMigrationService accountMigrationService` y reemplazar las dos líneas de filtros de Task 3 por:

```java
                // Orden tras autenticar el JWT: correo verificado → migración de cuentas legadas → cuentas desactivadas.
                .addFilterAfter(new EmailVerifiedFilter(), BearerTokenAuthenticationFilter.class)
                .addFilterAfter(new LegacyAccountMigrationFilter(accountMigrationService), EmailVerifiedFilter.class)
                .addFilterAfter(new DisabledAccountFilter(accountAccessService), LegacyAccountMigrationFilter.class);
```

Imports: `com.ones.api.adapters.inbound.rest.LegacyAccountMigrationFilter`, `com.ones.api.application.users.AccountMigrationService`.

- [ ] **Step 8: Run full suite**

Run: `JAVA_HOME=/opt/homebrew/opt/openjdk@17 sh ./mvnw -q test`
Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add services/ones-api/src/main/java/com/ones/api/application/users/AccountMigrationService.java \
        services/ones-api/src/main/java/com/ones/api/adapters/inbound/rest/LegacyAccountMigrationFilter.java \
        services/ones-api/src/main/java/com/ones/api/configuration/SecurityConfig.java \
        services/ones-api/src/test/java/com/ones/api/application/users/AccountMigrationServiceTest.java \
        services/ones-api/src/test/java/com/ones/api/adapters/inbound/rest/LegacyAccountMigrationFilterTest.java
git commit -m "feat(api): migración bajo demanda de usuarios de Google a Firebase (409 ACCOUNT_MIGRATED)"
```

---

### Task 7: Infraestructura (CloudFormation + workflow)

**Files:**
- Modify: `infra/cloudformation/backend/root.yml` (Parameters y `Parameters` del stack anidado)
- Modify: `infra/cloudformation/backend/all.yml` (Parameters, secreto, env del contenedor, política `ones-secrets` del TaskRole)
- Modify: `.github/workflows/deploy-infra-backend.yml` (los dos `aws cloudformation deploy`)

**Interfaces:**
- Consumes: variables de entorno `FIREBASE_PROJECT_ID`, `GOOGLE_LEGACY_AUTH_ENABLED`, `FIREBASE_SERVICE_ACCOUNT_SECRET_NAME` (Task 1 y 5).
- Produces: parámetros `FirebaseProjectId` (default `''`) y `GoogleLegacyAuthEnabled` (default `'true'`); secreto `${StackPrefix}-${Environment}-firebase-service-account`; variable de GitHub `vars.FIREBASE_PROJECT_ID`.

- [ ] **Step 1: `root.yml`** — después del parámetro `GoogleClientId`:

```yaml
  FirebaseProjectId:
    Type: String
    Default: ''
  GoogleLegacyAuthEnabled:
    Type: String
    Default: 'true'
    AllowedValues:
      - 'true'
      - 'false'
```

y en `Parameters:` del recurso que usa `TemplateURL: all.yml`, después de `GoogleClientId: !Ref GoogleClientId`:

```yaml
        FirebaseProjectId: !Ref FirebaseProjectId
        GoogleLegacyAuthEnabled: !Ref GoogleLegacyAuthEnabled
```

- [ ] **Step 2: `all.yml`** — mismos dos parámetros después de `GoogleClientId` (con `Description: Project ID de Firebase Auth (ej. ones-a96a7). Vacío = solo Google legado.` en `FirebaseProjectId`).

Recurso nuevo, después de `OpenAiApiKeySecret`:

```yaml
  FirebaseServiceAccountSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub ${StackPrefix}-${Environment}-firebase-service-account
      Description: JSON de la service account de Firebase (migración de usuarios legados)
      SecretString: '{}'
      Tags:
        - Key: Environment
          Value: !Ref Environment
```

En el `Environment` del contenedor, después de `GOOGLE_CLIENT_ID`:

```yaml
            - Name: FIREBASE_PROJECT_ID
              Value: !Ref FirebaseProjectId
            - Name: GOOGLE_LEGACY_AUTH_ENABLED
              Value: !Ref GoogleLegacyAuthEnabled
            - Name: FIREBASE_SERVICE_ACCOUNT_SECRET_NAME
              Value: !Ref FirebaseServiceAccountSecret
```

En la política `ones-secrets` del `TaskRole` (la lista que termina en `- !Ref InvitationEmailActionTokenSecret` seguida de `- PolicyName: ones-ses`), añadir `- !Ref FirebaseServiceAccountSecret`.

Nota: con `SecretString: '{}'`, `isConfigured()` es `true` pero la carga falla; el filtro responde 503 `ACCOUNT_MIGRATION_FAILED` y no borra nada hasta que se cargue el JSON real (paso de despliegue).

- [ ] **Step 3: Workflow** — en los dos bloques `aws cloudformation deploy` de `deploy-infra-backend.yml`, después de la línea `GoogleClientId=...`:

```yaml
              FirebaseProjectId="${{ vars.FIREBASE_PROJECT_ID }}" \
              GoogleLegacyAuthEnabled="${{ vars.GOOGLE_LEGACY_AUTH_ENABLED != '' && vars.GOOGLE_LEGACY_AUTH_ENABLED || 'true' }}" \
```

- [ ] **Step 4: Validate YAML**

Run (desde la raíz del repo):
```bash
python3 -c "import yaml,sys
class L(yaml.SafeLoader): pass
L.add_multi_constructor('!', lambda l,s,n: None)
for f in ['infra/cloudformation/backend/root.yml','infra/cloudformation/backend/all.yml','.github/workflows/deploy-infra-backend.yml']:
    yaml.load(open(f), Loader=L); print('ok', f)"
grep -c 'FirebaseServiceAccountSecret' infra/cloudformation/backend/all.yml
```
Expected: tres líneas `ok` y el conteo `3` (definición del recurso, variable de entorno y política IAM).

- [ ] **Step 5: Commit**

```bash
git add infra/cloudformation/backend/root.yml infra/cloudformation/backend/all.yml .github/workflows/deploy-infra-backend.yml
git commit -m "chore(infra): parámetros y secreto de Firebase Auth para el backend"
```

---

## Despliegue (manual, fuera del plan de código)

1. GitHub → environments `dev` y `prod`: variable `FIREBASE_PROJECT_ID=ones-a96a7`; actualizar `GOOGLE_IOS_CLIENT_ID=403122779240-7e0p9b2rau3mkctg7s08ku1uql1ah0ii.apps.googleusercontent.com`.
2. Deploy de infra + backend en dev.
3. Cargar el JSON de la service account en el secreto `…-dev-firebase-service-account` (consola de Secrets Manager).
4. Verificar que la app actual (Google directo) sigue funcionando contra dev.
5. Repetir en prod.
