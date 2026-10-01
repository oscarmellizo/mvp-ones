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
