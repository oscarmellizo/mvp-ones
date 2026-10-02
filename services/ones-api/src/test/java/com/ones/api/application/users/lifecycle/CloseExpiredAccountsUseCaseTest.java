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

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

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
    private CloseExpiredAccountsUseCase useCase;

    @BeforeEach
    void setUp() {
        repo = new InMemoryUsersRepository();
        exporter = mock(PhotosExportService.class);
        email = mock(AccountEmailService.class);
        access = mock(AccountAccessService.class);
        useCase = build("https://api.ones.events/");
    }

    private CloseExpiredAccountsUseCase build(String baseUrl) {
        return new CloseExpiredAccountsUseCase(repo, exporter, email, access,
                Clock.fixed(NOW, ZoneOffset.UTC), Duration.ofDays(30), baseUrl);
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
