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
    void migrationNotConfigured_respondsServiceUnavailable_insteadOfTreatingUserAsNew() throws Exception {
        authenticateFirebase("firebase-uid-9", "google-sub-1");
        when(service.migrateIfLegacy("firebase-uid-9", "google-sub-1")).thenReturn(Outcome.NOT_CONFIGURED);
        AtomicBoolean chained = new AtomicBoolean(false);
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(request("GET", "/v1/users/me"), res, (q, r) -> chained.set(true));

        assertFalse(chained.get());
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
