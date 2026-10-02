package com.ones.api.adapters.inbound.rest.users;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.net.URL;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;

import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.users.InMemoryUsersRepository;
import com.ones.api.domain.users.User;

class AccountExportsControllerTest {

    private static final Instant NOW = Instant.parse("2026-10-02T08:00:00Z");

    private InMemoryUsersRepository repo;
    private ObjectStoragePresigner presigner;
    private AccountExportsController controller;

    @BeforeEach
    void setUp() {
        repo = new InMemoryUsersRepository();
        presigner = mock(ObjectStoragePresigner.class);
        controller = new AccountExportsController(repo, presigner, Clock.fixed(NOW, ZoneOffset.UTC), "exports");
    }

    private static User closedWithExport(String id, String token, Instant closedAt) {
        return new User(id, id + "@x.com", "N", "N", "N", null, null, "google", "es", true,
                NOW.minus(Duration.ofDays(400)), NOW.minus(Duration.ofDays(400)),
                User.STATUS_CLOSED, null, null)
                .withLifecycle(User.STATUS_CLOSED, closedAt, token, "exports/" + id + "/ones-fotos.zip");
    }

    private void assertNotFound(ResponseEntity<Void> r) {
        assertEquals(404, r.getStatusCode().value());
        assertNull(r.getBody());
        assertFalse(r.getHeaders().containsKey("Location"));
        verifyNoInteractions(presigner);
    }

    @Test
    void validToken_redirectsToShortLivedLink() throws Exception {
        repo.upsert(closedWithExport("u1", "tok123", NOW.minus(Duration.ofDays(1))));
        when(presigner.presignGet("exports", "exports/u1/ones-fotos.zip", Duration.ofMinutes(5)))
                .thenReturn(new URL("https://s3.example/x"));

        ResponseEntity<Void> r = controller.download("u1.tok123");

        assertEquals(302, r.getStatusCode().value());
        assertEquals("https://s3.example/x", r.getHeaders().getLocation().toString());
    }

    @Test
    void wrongToken_404() {
        repo.upsert(closedWithExport("u1", "tok123", NOW.minus(Duration.ofDays(1))));
        assertNotFound(controller.download("u1.otro"));
    }

    @Test
    void after8Days_404() {
        repo.upsert(closedWithExport("u1", "tok123", NOW.minus(Duration.ofDays(8)).minusSeconds(1)));
        assertNotFound(controller.download("u1.tok123"));
    }

    @Test
    void deletedAccount_404() {
        User closed = closedWithExport("u1", "tok123", NOW.minus(Duration.ofDays(9)));
        repo.upsert(closed.tombstone(NOW));
        assertNotFound(controller.download("u1.tok123"));
    }

    @Test
    void unknownUser_404() {
        assertNotFound(controller.download("nadie.tok123"));
    }

    @Test
    void malformed_404() {
        repo.upsert(closedWithExport("u1", "tok123", NOW.minus(Duration.ofDays(1))));
        assertNotFound(controller.download("sinpunto"));
        assertNotFound(controller.download(".tok123"));
    }

    @Test
    void nullClosedAt_404() {
        repo.upsert(closedWithExport("u1", "tok123", null));
        assertNotFound(controller.download("u1.tok123"));
    }

    @Test
    void notClosed_404() {
        repo.upsert(closedWithExport("u1", "tok123", NOW.minus(Duration.ofDays(1)))
                .withLifecycle(User.STATUS_ACTIVE, NOW.minus(Duration.ofDays(1)), "tok123", "exports/u1/ones-fotos.zip"));
        assertNotFound(controller.download("u1.tok123"));
    }
}
