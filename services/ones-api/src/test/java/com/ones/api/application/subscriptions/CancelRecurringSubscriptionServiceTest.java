package com.ones.api.application.subscriptions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.domain.subscriptions.UserSubscription;

class CancelRecurringSubscriptionServiceTest {

    private static final Instant NOW = Instant.parse("2026-10-02T08:00:00Z");

    private UserSubscriptionsRepository subs;
    private MercadoPagoGateway mp;
    private CancelRecurringSubscriptionService service;

    @BeforeEach
    void setUp() {
        subs = mock(UserSubscriptionsRepository.class);
        mp = mock(MercadoPagoGateway.class);
        service = new CancelRecurringSubscriptionService(subs, mp, Clock.fixed(NOW, ZoneOffset.UTC));
    }

    static UserSubscription sub(String status, String preapprovalId) {
        Instant t0 = Instant.parse("2026-01-01T00:00:00Z");
        return new UserSubscription("u1", "ones-plus-monthly", status, preapprovalId, t0, null, t0.plusSeconds(60), null, t0);
    }

    private static MercadoPagoGateway.Preapproval remote(String status) {
        return new MercadoPagoGateway.Preapproval("pre-1", status, null, null, "u1", null, "plan-1");
    }

    @Test
    void activePreapproval_isCancelledInMercadoPago_andMarkedLocally() {
        when(subs.findByUserId("u1")).thenReturn(Optional.of(sub("active", "pre-1")));
        when(mp.getPreapproval("pre-1")).thenReturn(Optional.of(remote("authorized")));

        service.cancelFor("u1");

        verify(mp).cancelPreapproval("pre-1");
        ArgumentCaptor<UserSubscription> saved = ArgumentCaptor.forClass(UserSubscription.class);
        verify(subs).upsert(saved.capture());
        assertEquals("cancelled", saved.getValue().getStatus());
        assertEquals(NOW, saved.getValue().getCancelledAt());
        assertEquals("pre-1", saved.getValue().getMercadoPagoPreapprovalId());
    }

    @Test
    void alreadyCancelledInMercadoPago_onlyMarksLocally() {
        when(subs.findByUserId("u1")).thenReturn(Optional.of(sub("active", "pre-1")));
        when(mp.getPreapproval("pre-1")).thenReturn(Optional.of(remote("cancelled")));

        service.cancelFor("u1");

        verify(mp, never()).cancelPreapproval(anyString());
        verify(subs).upsert(any());
    }

    @Test
    void noRecurringPreapproval_orAlreadyCancelledLocally_doesNothing() {
        when(subs.findByUserId("u1")).thenReturn(Optional.of(sub("free", null)));
        service.cancelFor("u1");
        when(subs.findByUserId("u1")).thenReturn(Optional.of(sub("cancelled", "pre-1")));
        service.cancelFor("u1");
        when(subs.findByUserId("u1")).thenReturn(Optional.empty());
        service.cancelFor("u1");

        verify(mp, never()).cancelPreapproval(anyString());
        verify(mp, never()).getPreapproval(anyString());
        verify(subs, never()).upsert(any());
    }

    @Test
    void mercadoPagoFailure_throws_andLeavesSubscriptionUntouched() {
        when(subs.findByUserId("u1")).thenReturn(Optional.of(sub("active", "pre-1")));
        when(mp.getPreapproval("pre-1")).thenReturn(Optional.of(remote("authorized")));
        doThrow(new IllegalArgumentException("HTTP 500")).when(mp).cancelPreapproval("pre-1");

        assertThrows(SubscriptionCancellationException.class, () -> service.cancelFor("u1"));
        verify(subs, never()).upsert(any());
    }
}
