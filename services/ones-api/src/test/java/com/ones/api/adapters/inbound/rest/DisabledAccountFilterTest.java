package com.ones.api.adapters.inbound.rest;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicBoolean;

import jakarta.servlet.FilterChain;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import com.ones.api.application.users.AccountAccessService;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

class DisabledAccountFilterTest {

    private static final Instant NOW = Instant.parse("2026-09-15T12:00:00Z");

    private final InMemoryUsersRepository repo = new InMemoryUsersRepository();
    private final DisabledAccountFilter filter = new DisabledAccountFilter(
            new AccountAccessService(repo, Clock.fixed(NOW, ZoneOffset.UTC), Duration.ofDays(30)));

    @AfterEach
    void clearContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void unauthenticatedRequest_passesThrough() throws Exception {
        MockHttpServletResponse res = new MockHttpServletResponse();
        AtomicBoolean chained = new AtomicBoolean(false);

        filter.doFilter(request("POST", "/v1/events"), res, chain(chained));

        assertTrue(chained.get());
        assertEquals(200, res.getStatus());
    }

    @Test
    void activeUser_passesThrough() throws Exception {
        repo.upsert(user("u1", "ACTIVE", null));
        authenticateAs("u1");
        AtomicBoolean chained = new AtomicBoolean(false);
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(request("GET", "/v1/events"), res, chain(chained));

        assertTrue(chained.get());
        assertEquals(200, res.getStatus());
    }

    @Test
    void disabledUser_isRejectedWith403AndCode() throws Exception {
        repo.upsert(user("u1", "DISABLED", NOW.minus(Duration.ofDays(5))));
        authenticateAs("u1");
        AtomicBoolean chained = new AtomicBoolean(false);
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(request("GET", "/v1/events"), res, chain(chained));

        assertFalse(chained.get());
        assertEquals(403, res.getStatus());
        assertTrue(res.getContentType().startsWith("application/json"));
        assertTrue(res.getContentAsString().contains("\"code\":\"ACCOUNT_DISABLED\""));
    }

    @Test
    void closedUser_isRejectedWithClosedCode() throws Exception {
        repo.upsert(user("u1", "DISABLED", NOW.minus(Duration.ofDays(45))));
        authenticateAs("u1");
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(request("GET", "/v1/events"), res, chain(new AtomicBoolean()));

        assertEquals(403, res.getStatus());
        assertTrue(res.getContentAsString().contains("\"code\":\"ACCOUNT_CLOSED\""));
    }

    @Test
    void disabledUser_canStillReachAccountAndEnsureEndpoints() throws Exception {
        repo.upsert(user("u1", "DISABLED", NOW.minus(Duration.ofDays(5))));
        authenticateAs("u1");

        for (String path : List.of("/v1/account", "/v1/account/reactivate", "/v1/account:reactivate",
                "/v1/account/deactivate", "/v1/users/ensure")) {
            AtomicBoolean chained = new AtomicBoolean(false);
            MockHttpServletResponse res = new MockHttpServletResponse();

            filter.doFilter(request("POST", path), res, chain(chained));

            assertTrue(chained.get(), "expected pass-through for " + path);
            assertEquals(200, res.getStatus(), path);
        }
    }

    @Test
    void closedUser_cannotUseOtherUserEndpoints() throws Exception {
        repo.upsert(user("u1", "DISABLED", NOW.minus(Duration.ofDays(45))));
        authenticateAs("u1");
        AtomicBoolean chained = new AtomicBoolean(false);
        MockHttpServletResponse res = new MockHttpServletResponse();

        filter.doFilter(request("PUT", "/v1/users/me/preferences"), res, chain(chained));

        assertFalse(chained.get());
        assertEquals(403, res.getStatus());
    }

    private static MockHttpServletRequest request(String method, String path) {
        MockHttpServletRequest req = new MockHttpServletRequest(method, path);
        req.setServletPath(path);
        return req;
    }

    private static FilterChain chain(AtomicBoolean called) {
        return (req, res) -> called.set(true);
    }

    private static void authenticateAs(String sub) {
        Jwt jwt = Jwt.withTokenValue("token")
                .header("alg", "none")
                .claim("sub", sub)
                .build();
        SecurityContextHolder.getContext().setAuthentication(new JwtAuthenticationToken(jwt, List.of(), sub));
    }

    private static User user(String id, String status, Instant disabledAt) {
        Instant created = Instant.parse("2026-01-01T00:00:00Z");
        return new User(id, id + "@example.com", null, null, null, null, null, "google", null, true,
                created, created, status, disabledAt, null);
    }

    private static class InMemoryUsersRepository implements UsersRepository {
        private final Map<String, User> byId = new HashMap<>();

        @Override public Optional<User> findById(String userId) { return Optional.ofNullable(byId.get(userId)); }
        @Override public Optional<User> findByEmail(String email) { return Optional.empty(); }
        @Override public User upsert(User user) { byId.put(user.getUserId(), user); return user; }
        @Override public void deleteById(String userId) { byId.remove(userId); }
    }
}
