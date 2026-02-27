package com.ones.api.adapters.inbound.rest;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.time.Instant;
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
