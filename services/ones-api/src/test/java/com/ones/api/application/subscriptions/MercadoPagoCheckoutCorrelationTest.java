package com.ones.api.application.subscriptions;

import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;
import com.ones.api.application.subscriptions.ports.SubscriptionPlansRepository;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.subscriptions.PlanFeature;
import com.ones.api.domain.subscriptions.SubscriptionPlan;
import com.ones.api.domain.subscriptions.UserSubscription;
import com.ones.api.domain.users.User;

class MercadoPagoCheckoutCorrelationTest {

    private static final Instant NOW = Instant.parse("2026-07-23T00:00:00Z");
    private static final Clock CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);

    @Test
    void createsCheckoutPlanWithUserReferenceForHostedCheckout() {
        UserSubscriptionsRepository subscriptions = mock(UserSubscriptionsRepository.class);
        SubscriptionPlansRepository plans = mock(SubscriptionPlansRepository.class);
        UsersRepository users = mock(UsersRepository.class);
        MercadoPagoGateway mercadoPago = mock(MercadoPagoGateway.class);
        when(plans.findById("ones-plus-monthly")).thenReturn(Optional.of(paidPlan()));
        when(users.findById("user-123")).thenReturn(Optional.of(user("user-123")));
        when(subscriptions.findByUserId("user-123")).thenReturn(Optional.empty());
        when(mercadoPago.createPreapproval(any(), any(), any(), any())).thenReturn(new MercadoPagoGateway.Preapproval(
                "preapproval-123",
                "pending",
                "https://www.mercadopago.com.co/subscriptions/checkout?preapproval_id=preapproval-123",
                "user@example.com",
                "user-123",
                "https://app.ones.events/plans/success?ones_uid=user-123",
                "shared-plan-id"
        ));

        CreateMercadoPagoSubscriptionUseCase useCase = new CreateMercadoPagoSubscriptionUseCase(
                subscriptions, plans, users, mercadoPago, CLOCK, "https://app.ones.events", null
        );

        CreateMercadoPagoSubscriptionUseCase.Result result = useCase.execute("user-123", "ones-plus-monthly");

        assertNotNull(result.preapprovalId());
        verify(mercadoPago).createPreapproval(
                eq("shared-plan-id"),
                eq("user@example.com"),
                eq("https://app.ones.events/plans/success?ones_uid=user-123"),
                eq("user-123")
        );
        ArgumentCaptor<UserSubscription> saved = ArgumentCaptor.forClass(UserSubscription.class);
        verify(subscriptions).upsert(saved.capture());
        org.junit.jupiter.api.Assertions.assertEquals("pending", saved.getValue().getStatus());
        org.junit.jupiter.api.Assertions.assertEquals("preapproval-123", saved.getValue().getMercadoPagoPreapprovalId());
    }

    @Test
    void resolvesWebhookThroughCheckoutPlanExternalReference() {
        UserSubscriptionsRepository subscriptions = mock(UserSubscriptionsRepository.class);
        MercadoPagoGateway mercadoPago = mock(MercadoPagoGateway.class);
        UsersRepository users = mock(UsersRepository.class);
        UserSubscription pendingSubscription = new UserSubscription(
                "user-123", "ones-plus-monthly", "pending", null, NOW, null, null, null, NOW
        );
        when(mercadoPago.getPreapproval("preapproval-123")).thenReturn(Optional.of(new MercadoPagoGateway.Preapproval(
                "preapproval-123", "authorized", null, null, null,
                "https://app.ones.events/plans/success?ones_uid=user-123", "checkout-plan-123"
        )));
        when(mercadoPago.getPlan("checkout-plan-123")).thenReturn(Optional.of(new MercadoPagoGateway.PreapprovalPlan(
                "checkout-plan-123", "Ones Plus Monthly", null, "user-123"
        )));
        when(subscriptions.findByMercadoPagoPreapprovalId("preapproval-123")).thenReturn(Optional.empty());
        when(subscriptions.findByUserId("user-123")).thenReturn(Optional.of(pendingSubscription));

        ProcessMercadoPagoWebhookUseCase useCase = new ProcessMercadoPagoWebhookUseCase(
                subscriptions, mercadoPago, users, CLOCK, null
        );

        useCase.execute("subscription_preapproval", "preapproval-123");

        ArgumentCaptor<UserSubscription> saved = ArgumentCaptor.forClass(UserSubscription.class);
        verify(subscriptions).upsert(saved.capture());
        org.junit.jupiter.api.Assertions.assertEquals("preapproval-123", saved.getValue().getMercadoPagoPreapprovalId());
        org.junit.jupiter.api.Assertions.assertEquals("active", saved.getValue().getStatus());
    }

    private static SubscriptionPlan paidPlan() {
        return new SubscriptionPlan(
                "ones-plus-monthly", "Ones Plus Monthly", "", "paid", 19900, "COP", "month", "shared-plan-id",
                Map.of("maxActiveEvents", new PlanFeature(100L, "number", "Eventos")), true, 1, NOW, NOW
        );
    }

    private static User user(String userId) {
        return new User(userId, "user@example.com", "User", "User", "Example", null, null, "google", "es", true, NOW, NOW);
    }
}
