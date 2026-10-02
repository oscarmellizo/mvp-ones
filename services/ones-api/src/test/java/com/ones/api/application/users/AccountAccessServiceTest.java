package com.ones.api.application.users;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

class AccountAccessServiceTest {

    private static final Instant NOW = Instant.parse("2026-09-15T12:00:00Z");
    private static final Clock CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);
    private static final Duration WINDOW = Duration.ofDays(30);

    @Test
    void activeUser_isActive() {
        InMemoryUsersRepository repo = new InMemoryUsersRepository();
        repo.upsert(user("u1", "ACTIVE", null));

        AccountAccessService service = new AccountAccessService(repo, CLOCK, WINDOW);

        assertEquals(AccountAccess.ACTIVE, service.check("u1"));
    }

    @Test
    void unknownUser_isActive_becauseRegistrationHasNotHappenedYet() {
        AccountAccessService service = new AccountAccessService(new InMemoryUsersRepository(), CLOCK, WINDOW);

        assertEquals(AccountAccess.ACTIVE, service.check("missing"));
    }

    @Test
    void userWithoutStatus_isActive() {
        InMemoryUsersRepository repo = new InMemoryUsersRepository();
        repo.upsert(user("u1", null, null));

        AccountAccessService service = new AccountAccessService(repo, CLOCK, WINDOW);

        assertEquals(AccountAccess.ACTIVE, service.check("u1"));
    }

    @Test
    void disabledWithinWindow_isDisabled() {
        InMemoryUsersRepository repo = new InMemoryUsersRepository();
        repo.upsert(user("u1", "DISABLED", NOW.minus(Duration.ofDays(10))));

        AccountAccessService service = new AccountAccessService(repo, CLOCK, WINDOW);

        assertEquals(AccountAccess.DISABLED, service.check("u1"));
    }

    @Test
    void disabledBeyondWindow_isClosed() {
        InMemoryUsersRepository repo = new InMemoryUsersRepository();
        repo.upsert(user("u1", "DISABLED", NOW.minus(Duration.ofDays(31))));

        AccountAccessService service = new AccountAccessService(repo, CLOCK, WINDOW);

        assertEquals(AccountAccess.CLOSED, service.check("u1"));
    }

    @Test
    void disabledWithoutDisabledAt_isDisabled_notClosed() {
        InMemoryUsersRepository repo = new InMemoryUsersRepository();
        repo.upsert(user("u1", "DISABLED", null));

        AccountAccessService service = new AccountAccessService(repo, CLOCK, WINDOW);

        assertEquals(AccountAccess.DISABLED, service.check("u1"));
    }

    @Test
    void closedStatus_isClosed_evenInsideTheWindow() {
        InMemoryUsersRepository repo = new InMemoryUsersRepository();
        repo.upsert(user("u1", "DISABLED", NOW.minus(Duration.ofDays(2))).withLifecycle("CLOSED", NOW, "t", null));

        assertEquals(AccountAccess.CLOSED, new AccountAccessService(repo, CLOCK, WINDOW).check("u1"));
    }

    @Test
    void deletedTombstone_isClosed() {
        InMemoryUsersRepository repo = new InMemoryUsersRepository();
        repo.upsert(user("u1", "DISABLED", NOW.minus(Duration.ofDays(40))).tombstone(NOW));

        assertEquals(AccountAccess.CLOSED, new AccountAccessService(repo, CLOCK, WINDOW).check("u1"));
    }

    private static User user(String id, String status, Instant disabledAt) {
        Instant created = Instant.parse("2026-01-01T00:00:00Z");
        return new User(id, id + "@example.com", null, null, null, null, null, "google", null, true,
                created, created, status, disabledAt, null);
    }

}
