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


        @Override
        public java.util.List<User> findByStatusIn(java.util.Set<String> statuses) {
            return byId.values().stream()
                    .filter(u -> u.getStatus() != null && statuses.contains(u.getStatus().toUpperCase()))
                    .toList();
        }

        @Override public Optional<User> findById(String userId) { return Optional.ofNullable(byId.get(userId)); }
        @Override public Optional<User> findByEmail(String email) {
            return byId.values().stream().filter(u -> email.equalsIgnoreCase(u.getEmail())).findFirst();
        }
        @Override public User upsert(User user) { byId.put(user.getUserId(), user); return user; }
        @Override public void deleteById(String userId) { byId.remove(userId); }
    }
}
