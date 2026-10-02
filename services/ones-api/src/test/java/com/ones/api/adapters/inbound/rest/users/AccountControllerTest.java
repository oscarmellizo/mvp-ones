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

import com.ones.api.application.subscriptions.CancelRecurringSubscriptionService;
import com.ones.api.application.subscriptions.SubscriptionCancellationException;
import com.ones.api.application.users.AccountAccessService;
import com.ones.api.application.users.AccountDeactivateUseCase;
import com.ones.api.application.users.AccountReactivateUseCase;
import com.ones.api.application.users.GetAccountUseCase;
import com.ones.api.application.users.email.AccountEmailService;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.application.users.InMemoryUsersRepository;
import com.ones.api.domain.users.User;

class AccountControllerTest {

    private static final Instant NOW = Instant.parse("2026-09-15T12:00:00Z");
    private static final Clock CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);

    private final InMemoryUsersRepository repo = new InMemoryUsersRepository();
    private final AccountAccessService accountAccess = mock(AccountAccessService.class);
    private final CancelRecurringSubscriptionService cancelSubscriptions = mock(CancelRecurringSubscriptionService.class);
    private final AccountController controller = new AccountController(
            new GetAccountUseCase(repo),
            new AccountDeactivateUseCase(repo, CLOCK, cancelSubscriptions),
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
    void deactivate_closedAccount_returns409AccountClosed_andDoesNotReopen() {
        repo.upsert(user("u1", "DISABLED", NOW.minus(Duration.ofDays(40)))
                .withLifecycle(User.STATUS_CLOSED, NOW.minus(Duration.ofDays(2)), "tok", "exports/u1/ones-fotos.zip"));

        ResponseEntity<Map<String, Object>> res = controller.deactivate(authAs("u1"));

        assertEquals(409, res.getStatusCode().value());
        assertEquals("ACCOUNT_CLOSED", res.getBody().get("code"));
        assertEquals(User.STATUS_CLOSED, repo.findById("u1").get().getStatus());
        assertEquals("tok", repo.findById("u1").get().getExportToken());
    }

    @Test
    void deactivate_subscriptionCancelFails_returns502_andAccountStaysActive() {
        repo.upsert(user("u1", "ACTIVE", null));
        org.mockito.Mockito.doThrow(new SubscriptionCancellationException("u1", new IllegalStateException("MP")))
                .when(cancelSubscriptions).cancelFor("u1");

        ResponseEntity<Map<String, Object>> res = controller.deactivate(authAs("u1"));

        assertEquals(502, res.getStatusCode().value());
        assertEquals("SUBSCRIPTION_CANCEL_FAILED", res.getBody().get("code"));
        assertEquals("ACTIVE", repo.findById("u1").get().getStatus());
    }

    @Test
    void deactivate_unknownUser_returns404() {
        assertEquals(404, controller.deactivate(authAs("nobody")).getStatusCode().value());
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
}
