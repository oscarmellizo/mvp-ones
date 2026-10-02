package com.ones.api.application.users;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.Test;

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

    @Test
    void closedUser_ensureKeepsClosedAtExportTokenExportKeyAndStatus_andWritesNothing() {
        User closed = closedUser("uid-c");
        repo.upsert(closed);
        int writesBefore = repo.writes();

        User out = useCase.execute(new EnsureUserCommand("uid-c", "nuevo@example.com", "Nuevo", null, null, null, "google.com", null));

        User stored = repo.findById("uid-c").get();
        assertEquals(writesBefore, repo.writes());
        assertSame(closed, stored);
        assertSame(closed, out);
        assertEquals(User.STATUS_CLOSED, stored.getStatus());
        assertEquals(NOW.minusSeconds(3600), stored.getClosedAt());
        assertEquals("tok", stored.getExportToken());
        assertEquals("exports/uid-c/ones-fotos.zip", stored.getExportKey());
        assertEquals("c@example.com", stored.getEmail());
    }

    @Test
    void deletedTombstone_ensureWritesNothing() {
        User tombstone = closedUser("uid-d").tombstone(NOW);
        repo.upsert(tombstone);
        int writesBefore = repo.writes();

        useCase.execute(new EnsureUserCommand("uid-d", "otra@example.com", "Ana", "Ana", "P", "https://img", "google.com", null));

        assertEquals(writesBefore, repo.writes());
        User stored = repo.findById("uid-d").get();
        assertEquals(User.STATUS_DELETED, stored.getStatus());
        assertNull(stored.getEmail());
        assertNull(stored.getName());
        assertNull(stored.getPicture());
    }

    @Test
    void closingUser_ensureWritesNothing() {
        User closing = disabled("uid-g").withClosing(NOW);
        repo.upsert(closing);
        int writesBefore = repo.writes();

        useCase.execute(command("uid-g", "g@example.com", "google.com"));

        assertEquals(writesBefore, repo.writes());
        assertSame(closing, repo.findById("uid-g").get());
    }

    @Test
    void disabledUser_ensureMergesProfile_andPreservesEveryLifecycleField() {
        User existing = new User("uid-e", "e@example.com", "Viejo", null, null, null, "Pref", "google", "es", true,
                T0, T0, User.STATUS_DISABLED, T0, T0.plusSeconds(5), null, null, "exports/uid-e/old.zip");
        repo.upsert(existing);

        User out = useCase.execute(new EnsureUserCommand("uid-e", "e@example.com", "Nuevo", null, null, null, "google.com", null));

        assertEquals("Nuevo", out.getName());
        User stored = repo.findById("uid-e").get();
        assertEquals("Nuevo", stored.getName());
        assertEquals(User.STATUS_DISABLED, stored.getStatus());
        assertEquals(T0, stored.getDisabledAt());
        assertEquals(T0.plusSeconds(5), stored.getReactivatedAt());
        assertEquals("exports/uid-e/old.zip", stored.getExportKey());
        assertEquals(NOW, stored.getUpdatedAt());
    }

    @Test
    void staleRead_whileJobClaimsAccount_ensureDoesNotOverwriteClosing() {
        User stale = disabled("uid-r");
        StaleOnceRepository racing = new StaleOnceRepository(stale);
        racing.upsert(stale.withClosing(NOW)); // la tarea diaria la reclamó después de nuestra lectura

        new EnsureUserUseCase(racing, Clock.fixed(NOW, ZoneOffset.UTC))
                .execute(new EnsureUserCommand("uid-r", "x@example.com", "X", null, null, null, "google.com", null));

        User stored = racing.findById("uid-r").get();
        assertEquals(User.STATUS_CLOSING, stored.getStatus());
        assertEquals("Ana", stored.getName());
    }

    /** Devuelve una vez una lectura vieja, como si otro proceso escribiera entre la lectura y la escritura. */
    static class StaleOnceRepository extends InMemoryUsersRepository {
        private User stale;

        StaleOnceRepository(User stale) {
            this.stale = stale;
        }

        @Override
        public java.util.Optional<User> findById(String userId) {
            if (stale != null && stale.getUserId().equals(userId)) {
                User s = stale;
                stale = null;
                return java.util.Optional.of(s);
            }
            return super.findById(userId);
        }
    }

    private static User disabled(String id) {
        return new User(id, id + "@example.com", "Ana", null, null, null, "Ana", "google", "es", true,
                T0, T0, User.STATUS_DISABLED, T0, null);
    }

    private static User closedUser(String id) {
        return new User(id, "c@example.com", "Ana", null, null, null, "Ana", "google", "es", true,
                T0, T0, User.STATUS_DISABLED, T0, null)
                .withLifecycle(User.STATUS_CLOSED, NOW.minusSeconds(3600), "tok", "exports/" + id + "/ones-fotos.zip");
    }

    private static EnsureUserCommand command(String uid, String email, String provider) {
        return new EnsureUserCommand(uid, email, null, null, null, null, provider, null);
    }
}
