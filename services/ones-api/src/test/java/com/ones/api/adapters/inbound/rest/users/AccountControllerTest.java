package com.ones.api.adapters.inbound.rest.users;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

import com.ones.api.application.users.AccountAccessService;
import com.ones.api.application.users.AccountDeactivateUseCase;
import com.ones.api.application.users.AccountReactivateUseCase;
import com.ones.api.application.users.GetAccountUseCase;
import com.ones.api.application.users.email.AccountEmailService;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

class AccountControllerTest {

    private static final Instant NOW = Instant.parse("2026-09-15T12:00:00Z");
    private static final Clock CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);

    private final InMemoryUsersRepository repo = new InMemoryUsersRepository();
    private final AccountAccessService accountAccess = mock(AccountAccessService.class);
    private final AccountController controller = new AccountController(
            new GetAccountUseCase(repo),
            new AccountDeactivateUseCase(repo, CLOCK),
            new AccountReactivateUseCase(repo, CLOCK, Duration.ofDays(30)),
            mock(AccountEmailService.class),
            CLOCK,
            accountAccess
    );

    @Test
    void deactivate_evictsAccessCacheForUser() {
        repo.upsert(user("u1", "ACTIVE", null));

        ResponseEntity<Map<String, Object>> res = controller.deactivate(authAs("u1"));

        assertEquals(200, res.getStatusCode().value());
        assertEquals("DISABLED", res.getBody().get("status"));
        verify(accountAccess).evict("u1");
    }

    @Test
    void reactivate_evictsAccessCacheForUser() {
        repo.upsert(user("u1", "DISABLED", NOW.minus(Duration.ofDays(2))));

        ResponseEntity<Map<String, Object>> res = controller.reactivate(authAs("u1"));

        assertEquals(200, res.getStatusCode().value());
        assertEquals("ACTIVE", res.getBody().get("status"));
        verify(accountAccess).evict("u1");
    }

    private static Authentication authAs(String sub) {
        Authentication auth = mock(Authentication.class);
        when(auth.getName()).thenReturn(sub);
        return auth;
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
