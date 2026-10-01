package com.ones.api.adapters.inbound.rest;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Instant;
import java.util.List;
import java.util.Map;

import org.junit.jupiter.api.Test;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

class AuthClaimsTest {

    @Test
    void requireEmail_prefersEmailClaim() {
        Authentication auth = authWithClaims(Map.of(
                "email", "Test@Example.com"
        ));

        assertEquals("test@example.com", AuthClaims.requireEmail(auth));
    }

    @Test
    void requireEmail_fallsBackToCognitoUsername() {
        Authentication auth = authWithClaims(Map.of(
                "cognito:username", "User@Example.com"
        ));

        assertEquals("user@example.com", AuthClaims.requireEmail(auth));
    }

    @Test
    void requireEmail_fallsBackToPreferredUsername() {
        Authentication auth = authWithClaims(Map.of(
                "preferred_username", "User@Example.com"
        ));

        assertEquals("user@example.com", AuthClaims.requireEmail(auth));
    }

    @Test
    void requireEmail_whenMissing_throwsIllegalStateException() {
        Authentication auth = authWithClaims(Map.of());

        IllegalStateException ex = assertThrows(IllegalStateException.class, () -> AuthClaims.requireEmail(auth));
        assertEquals("Missing email claim", ex.getMessage());
    }

    @Test
    void getClaim_whenMissing_returnsNull() {
        Authentication auth = authWithClaims(Map.of(
                "email", "a@b.com"
        ));

        assertEquals(null, AuthClaims.getClaim(auth, "not_present"));
    }

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

    private static Authentication authWithClaims(Map<String, Object> claims) {
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "none")
                .claim("sub", "user-1")
                .claims(c -> c.putAll(claims))
                .issuedAt(Instant.parse("2026-01-01T00:00:00Z"))
                .expiresAt(Instant.parse("2027-01-01T00:00:00Z"))
                .build();

        return new JwtAuthenticationToken(jwt);
    }
}
