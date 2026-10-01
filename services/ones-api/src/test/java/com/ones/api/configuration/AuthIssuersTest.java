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
