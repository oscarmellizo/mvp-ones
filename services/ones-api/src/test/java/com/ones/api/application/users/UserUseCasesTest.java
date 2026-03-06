package com.ones.api.application.users;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.users.ports.PreferredNamesCacheRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

class UserUseCasesTest {

    @Test
    void getUserById_returnsUserWhenExists() {
        InMemoryUsersRepository repo = new InMemoryUsersRepository();
        Instant now = Instant.parse("2026-01-01T00:00:00Z");
        repo.upsert(new User("u1", "a@b.com", null, null, null, null, null, "google", now, now));

        GetUserByIdUseCase useCase = new GetUserByIdUseCase(repo);
        Optional<User> out = useCase.execute("u1");

        assertTrue(out.isPresent());
        assertEquals("u1", out.get().getUserId());
    }

    @Test
    void lookupUserByEmail_normalizesAndFinds() {
        InMemoryUsersRepository repo = new InMemoryUsersRepository();
        Instant now = Instant.parse("2026-01-01T00:00:00Z");
        repo.upsert(new User("u1", "test@example.com", null, null, null, null, "Test", "google", now, now));

        LookupUserByEmailUseCase useCase = new LookupUserByEmailUseCase(repo);
        Optional<User> out = useCase.execute("  TEST@EXAMPLE.COM  ");

        assertTrue(out.isPresent());
        assertEquals("u1", out.get().getUserId());
    }

    @Test
    void updateUserPreferences_updatesPreferredNameAndUpdatedAt() {
        InMemoryUsersRepository repo = new InMemoryUsersRepository();
        InMemoryPreferredNamesCacheRepository cache = new InMemoryPreferredNamesCacheRepository();
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        Instant t1 = Instant.parse("2026-01-01T00:10:00Z");
        repo.upsert(new User("u1", "a@b.com", null, null, null, null, "Old", "google", t0, t0));

        UpdateUserPreferencesUseCase useCase = new UpdateUserPreferencesUseCase(
                repo,
                cache,
                Clock.fixed(t1, ZoneOffset.UTC)
        );

        Optional<User> out = useCase.execute("u1", "New");

        assertTrue(out.isPresent());
        assertEquals("New", out.get().getPreferredName());
        assertEquals(t1, out.get().getUpdatedAt());
    }

    private static class InMemoryPreferredNamesCacheRepository implements PreferredNamesCacheRepository {
        private final Map<String, CachedPreferredName> byId = new HashMap<>();

        @Override
        public Map<String, CachedPreferredName> getMany(java.util.Set<String> userIds) {
            if (userIds == null || userIds.isEmpty()) {
                return Collections.emptyMap();
            }
            Map<String, CachedPreferredName> out = new HashMap<>();
            for (String id : userIds) {
                if (id == null) continue;
                CachedPreferredName c = byId.get(id);
                if (c != null) out.put(id, c);
            }
            return out;
        }

        @Override
        public void put(String userId, String preferredName, Instant expiresAt, Instant updatedAt) {
            if (userId == null) return;
            byId.put(userId, new CachedPreferredName(userId, preferredName, updatedAt, expiresAt));
        }

        @Override
        public void delete(String userId) {
            if (userId == null) return;
            byId.remove(userId);
        }
    }

    private static class InMemoryUsersRepository implements UsersRepository {
        private final Map<String, User> byId = new HashMap<>();
        private final Map<String, User> byEmail = new HashMap<>();

        @Override
        public Optional<User> findById(String userId) {
            return Optional.ofNullable(byId.get(userId));
        }

        @Override
        public Optional<User> findByEmail(String email) {
            if (email == null) {
                return Optional.empty();
            }
            return Optional.ofNullable(byEmail.get(email));
        }

        @Override
        public User upsert(User user) {
            byId.put(user.getUserId(), user);
            if (user.getEmail() != null) {
                byEmail.put(user.getEmail(), user);
            }
            return user;
        }

        @Override
        public void deleteById(String userId) {
            byId.remove(userId);
        }
    }
}
