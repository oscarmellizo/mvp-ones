package com.ones.api.application.users;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.users.AccountMigrationService.Outcome;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin;
import com.ones.api.application.users.ports.FirebaseIdentityAdmin.LegacyGoogleUser;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

class AccountMigrationServiceTest {

    private static final Instant T0 = Instant.parse("2026-01-01T00:00:00Z");

    private final InMemoryUsersRepository repo = new InMemoryUsersRepository();
    private final FirebaseIdentityAdmin admin = mock(FirebaseIdentityAdmin.class);
    private final AccountMigrationService service = new AccountMigrationService(repo, admin);

    @Test
    void legacyGoogleUser_withNewFirebaseUid_isMigrated() {
        when(admin.isConfigured()).thenReturn(true);
        repo.upsert(user("google-sub-1"));

        assertEquals(Outcome.MIGRATED, service.migrateIfLegacy("firebase-uid-9", "google-sub-1"));

        verify(admin).replaceWithLegacyGoogleUser("firebase-uid-9",
                new LegacyGoogleUser("google-sub-1", "google-sub-1@example.com", "Ana", "https://img/a.png"));
    }

    @Test
    void alreadyMigratedUser_uidEqualsGoogleSub_doesNothing() {
        repo.upsert(user("google-sub-1"));

        assertEquals(Outcome.NONE, service.migrateIfLegacy("google-sub-1", "google-sub-1"));
        verify(admin, never()).replaceWithLegacyGoogleUser(anyString(), any());
    }

    @Test
    void brandNewGoogleUser_withoutLegacyRow_doesNothing() {
        assertEquals(Outcome.NONE, service.migrateIfLegacy("firebase-uid-9", "google-sub-new"));
        verify(admin, never()).replaceWithLegacyGoogleUser(anyString(), any());
    }

    @Test
    void firebaseUidThatAlreadyHasRow_doesNothing() {
        repo.upsert(user("firebase-uid-9"));
        repo.upsert(user("google-sub-1"));

        assertEquals(Outcome.NONE, service.migrateIfLegacy("firebase-uid-9", "google-sub-1"));
    }

    @Test
    void nonGoogleAccount_doesNothing() {
        assertEquals(Outcome.NONE, service.migrateIfLegacy("firebase-uid-9", null));
    }

    @Test
    void notConfigured_neverCallsFirebase() {
        when(admin.isConfigured()).thenReturn(false);
        repo.upsert(user("google-sub-1"));

        assertEquals(Outcome.NOT_CONFIGURED, service.migrateIfLegacy("firebase-uid-9", "google-sub-1"));
        verify(admin, never()).replaceWithLegacyGoogleUser(anyString(), any());
    }

    private static User user(String id) {
        return new User(id, id + "@example.com", "Ana", null, null, "https://img/a.png", "Ana", "google", "es", true, T0, T0);
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
        @Override public Optional<User> findByEmail(String email) { return Optional.empty(); }
        @Override public User upsert(User user) { byId.put(user.getUserId(), user); return user; }
        @Override public void deleteById(String userId) { byId.remove(userId); }
    }
}
