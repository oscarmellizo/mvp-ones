package com.ones.api.application.users.lifecycle;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import io.micrometer.core.instrument.simple.SimpleMeterRegistry;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.ones.api.application.subscriptions.CancelRecurringSubscriptionService;
import com.ones.api.application.subscriptions.SubscriptionCancellationException;
import com.ones.api.application.users.AccountAccessService;
import com.ones.api.application.users.InMemoryUsersRepository;
import com.ones.api.application.users.email.AccountEmailService;
import com.ones.api.domain.users.User;

class CloseExpiredAccountsUseCaseTest {

    private static final Instant NOW = Instant.parse("2026-10-02T08:00:00Z");

    private InMemoryUsersRepository repo;
    private PhotosExportService exporter;
    private AccountEmailService email;
    private AccountAccessService access;
    private CancelRecurringSubscriptionService cancelSubscriptions;
    private SimpleMeterRegistry meters;
    private CloseExpiredAccountsUseCase useCase;

    @BeforeEach
    void setUp() {
        repo = new InMemoryUsersRepository();
        exporter = mock(PhotosExportService.class);
        email = mock(AccountEmailService.class);
        access = mock(AccountAccessService.class);
        cancelSubscriptions = mock(CancelRecurringSubscriptionService.class);
        meters = new SimpleMeterRegistry();
        useCase = build("https://api.ones.events/");
    }

    private CloseExpiredAccountsUseCase build(String baseUrl) {
        return new CloseExpiredAccountsUseCase(repo, exporter, email, access, cancelSubscriptions,
                Clock.fixed(NOW, ZoneOffset.UTC), Duration.ofDays(30), baseUrl, meters);
    }

    private static User user(String id, String status, Instant disabledAt) {
        return new User(id, id + "@x.com", "N", "N", "N", null, null, "google", "es", true,
                NOW.minus(Duration.ofDays(400)), NOW.minus(Duration.ofDays(400)), status, disabledAt, null);
    }

    private static User disabled(String id, Instant at) {
        return user(id, User.STATUS_DISABLED, at);
    }

    private static User active(String id) {
        return user(id, User.STATUS_ACTIVE, null);
    }

    @Test
    void day29_isNotClosed() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(29))));
        assertEquals(0, useCase.execute());
        assertEquals("DISABLED", repo.findById("u1").get().getStatus());
        verifyNoInteractions(email);
    }

    @Test
    void day30_closes_exportsAndEmailsOnce() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(30)).minusSeconds(1)));
        when(exporter.export("u1")).thenReturn(Optional.of("exports/u1/ones-fotos.zip"));
        when(email.sendClosureEmail(any(), any(), any())).thenReturn(true);

        assertEquals(1, useCase.execute());
        assertEquals(0, useCase.execute()); // segunda corrida: ya está CLOSED

        User u = repo.findById("u1").get();
        assertEquals("CLOSED", u.getStatus());
        assertEquals(NOW, u.getClosedAt());
        assertEquals("exports/u1/ones-fotos.zip", u.getExportKey());
        assertTrue(u.getExportToken().length() >= 32);
        verify(email, times(1)).sendClosureEmail(any(),
                eq("https://api.ones.events/v1/account-exports/u1." + u.getExportToken()),
                eq(NOW.plus(Duration.ofDays(8))));
        verify(access).evict("u1");
    }

    @Test
    void noPhotos_closesWithoutLink() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
        when(exporter.export("u1")).thenReturn(Optional.empty());
        when(email.sendClosureEmail(any(), isNull(), any())).thenReturn(true);
        assertEquals(1, useCase.execute());
        assertNull(repo.findById("u1").get().getExportKey());
    }

    @Test
    void emailFails_staysDisabled_forRetry() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
        when(exporter.export("u1")).thenReturn(Optional.empty());
        when(email.sendClosureEmail(any(), any(), any())).thenReturn(false);
        assertEquals(0, useCase.execute());
        assertEquals("DISABLED", repo.findById("u1").get().getStatus());
    }

    @Test
    void exportFails_otherAccountsStillProcessed() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
        repo.upsert(disabled("u2", NOW.minus(Duration.ofDays(31))));
        when(exporter.export("u1")).thenThrow(new RuntimeException("s3"));
        when(exporter.export("u2")).thenReturn(Optional.empty());
        when(email.sendClosureEmail(any(), any(), any())).thenReturn(true);
        assertEquals(1, useCase.execute());
        assertEquals("DISABLED", repo.findById("u1").get().getStatus());
    }

    @Test
    void claimLostToAnotherRun_skipsWithoutExportOrEmail() {
        User u = disabled("u1", NOW.minus(Duration.ofDays(31)));
        // Otra corrida (otra tarea) ya la reclamó; esta vio la fila antes del reclamo.
        InMemoryUsersRepository racing = new InMemoryUsersRepository() {
            @Override
            public java.util.List<User> findByStatusIn(java.util.Set<String> statuses) {
                return java.util.List.of(u);
            }
        };
        racing.upsert(u.withClosing(NOW.minusSeconds(5)));
        repo = racing;
        useCase = build("https://api.ones.events");

        assertEquals(0, useCase.execute());

        verifyNoInteractions(exporter, email);
        assertEquals(User.STATUS_CLOSING, repo.findById("u1").get().getStatus());
        assertEquals(NOW.minusSeconds(5), repo.findById("u1").get().getClosingAt());
    }

    @Test
    void accountIsClaimedAsClosing_beforeExport() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
        when(exporter.export("u1")).thenAnswer(i -> {
            User during = repo.findById("u1").get();
            assertEquals(User.STATUS_CLOSING, during.getStatus());
            assertEquals(NOW, during.getClosingAt());
            return Optional.empty();
        });
        when(email.sendClosureEmail(any(), any(), any())).thenReturn(true);

        assertEquals(1, useCase.execute());
        User u = repo.findById("u1").get();
        assertEquals(User.STATUS_CLOSED, u.getStatus());
    }

    @Test
    void staleClosingOlderThan6h_isReclaimedAndClosed() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))).withClosing(NOW.minus(Duration.ofHours(7))));
        when(exporter.export("u1")).thenReturn(Optional.empty());
        when(email.sendClosureEmail(any(), any(), any())).thenReturn(true);

        assertEquals(1, useCase.execute());

        assertEquals(User.STATUS_CLOSED, repo.findById("u1").get().getStatus());
        verify(exporter).export("u1");
    }

    @Test
    void recentClosing_isLeftToTheRunThatOwnsIt() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))).withClosing(NOW.minus(Duration.ofHours(1))));

        assertEquals(0, useCase.execute());

        verifyNoInteractions(exporter, email);
        assertEquals(User.STATUS_CLOSING, repo.findById("u1").get().getStatus());
    }

    @Test
    void failureAfterClaim_revertsToDisabledWithoutClosingAt() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
        when(exporter.export("u1")).thenThrow(new RuntimeException("s3 caído"));

        assertEquals(0, useCase.execute());

        User u = repo.findById("u1").get();
        assertEquals(User.STATUS_DISABLED, u.getStatus());
        assertNull(u.getClosingAt());
        assertEquals(NOW.minus(Duration.ofDays(31)), u.getDisabledAt());
    }

    @Test
    void closure_defensivelyCancelsStillActiveSubscription_beforeEmail() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
        when(exporter.export("u1")).thenReturn(Optional.empty());
        when(email.sendClosureEmail(any(), any(), any())).thenReturn(true);

        assertEquals(1, useCase.execute());

        org.mockito.InOrder order = org.mockito.Mockito.inOrder(cancelSubscriptions, email);
        order.verify(cancelSubscriptions).cancelFor("u1");
        order.verify(email).sendClosureEmail(any(), any(), any());
    }

    @Test
    void closure_subscriptionCancelFails_noEmail_revertsToDisabled() {
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
        when(exporter.export("u1")).thenReturn(Optional.empty());
        org.mockito.Mockito.doThrow(new SubscriptionCancellationException("u1", new IllegalStateException("MP")))
                .when(cancelSubscriptions).cancelFor("u1");

        assertEquals(0, useCase.execute());

        verifyNoInteractions(email);
        assertEquals(User.STATUS_DISABLED, repo.findById("u1").get().getStatus());
    }

    @Test
    void metrics_countClosedAndFailed_withPhaseTag() {
        repo.upsert(disabled("ok", NOW.minus(Duration.ofDays(31))));
        repo.upsert(disabled("ko", NOW.minus(Duration.ofDays(31))));
        when(exporter.export("ok")).thenReturn(Optional.empty());
        when(exporter.export("ko")).thenThrow(new RuntimeException("s3"));
        when(email.sendClosureEmail(any(), any(), any())).thenReturn(true);

        useCase.execute();

        assertEquals(1.0, meters.get("ones.account.lifecycle.closed").tag("phase", "close").counter().count());
        assertEquals(1.0, meters.get("ones.account.lifecycle.failed").tag("phase", "close").counter().count());
    }

    @Test
    void overdue_countsOnlyAccountsPast31DaysLeftUnclosed() {
        repo.upsert(disabled("late-ko", NOW.minus(Duration.ofDays(32))));   // atrasada y falla → overdue
        repo.upsert(disabled("late-ok", NOW.minus(Duration.ofDays(32))));   // atrasada pero se cierra hoy
        repo.upsert(disabled("fresh-ko", NOW.minus(Duration.ofDays(30)).minusSeconds(5))); // falla, aún no atrasada
        when(exporter.export("late-ko")).thenThrow(new RuntimeException("s3"));
        when(exporter.export("fresh-ko")).thenThrow(new RuntimeException("s3"));
        when(exporter.export("late-ok")).thenReturn(Optional.empty());
        when(email.sendClosureEmail(any(), any(), any())).thenReturn(true);

        useCase.execute();

        assertEquals(1.0, meters.get("ones.account.lifecycle.overdue").tag("phase", "close").gauge().value());
    }

    @Test
    void reactivatedAccount_isIgnored() {
        repo.upsert(active("u1"));
        assertEquals(0, useCase.execute());
    }

    @Test
    void blankBaseUrl_accountWithPhotosStaysDisabled_withoutPhotosCloses() {
        CloseExpiredAccountsUseCase noBase = build("  ");
        repo.upsert(disabled("u1", NOW.minus(Duration.ofDays(31))));
        repo.upsert(disabled("u2", NOW.minus(Duration.ofDays(31))));
        when(exporter.export("u1")).thenReturn(Optional.of("exports/u1/ones-fotos.zip"));
        when(exporter.export("u2")).thenReturn(Optional.empty());
        when(email.sendClosureEmail(any(), isNull(), any())).thenReturn(true);

        assertEquals(1, noBase.execute());
        assertEquals("DISABLED", repo.findById("u1").get().getStatus());
        assertEquals("CLOSED", repo.findById("u2").get().getStatus());
        verify(email, times(1)).sendClosureEmail(any(), any(), any());
    }
}
