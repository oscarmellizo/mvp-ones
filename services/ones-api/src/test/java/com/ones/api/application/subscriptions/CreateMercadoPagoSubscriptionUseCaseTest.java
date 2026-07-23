package com.ones.api.application.subscriptions;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;
import com.ones.api.application.subscriptions.ports.SubscriptionPlansRepository;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.subscriptions.PlanFeature;
import com.ones.api.domain.subscriptions.SubscriptionPlan;
import com.ones.api.domain.subscriptions.UserSubscription;
import com.ones.api.domain.users.User;

class CreateMercadoPagoSubscriptionUseCaseTest {

    private static final Instant NOW = Instant.parse("2026-07-23T00:00:00Z");

    @Test
    void createsPendingPreapprovalAndPersistsItsIdBeforeHostedCheckout() {
        InMemorySubscriptionsRepository subscriptions = new InMemorySubscriptionsRepository();
        RecordingMercadoPagoGateway mercadoPago = new RecordingMercadoPagoGateway();
        CreateMercadoPagoSubscriptionUseCase useCase = new CreateMercadoPagoSubscriptionUseCase(
                subscriptions,
                new PaidPlanRepository(),
                new SingleUserRepository(),
                mercadoPago,
                Clock.fixed(NOW, ZoneOffset.UTC),
                "https://app.ones.events",
                null
        );

        CreateMercadoPagoSubscriptionUseCase.Result result = useCase.execute("user-123", "ones-plus-monthly");

        assertEquals("preapproval-123", result.preapprovalId());
        assertEquals("https://www.mercadopago.com.co/subscriptions/checkout?preapproval_id=preapproval-123", result.initPoint());
        assertEquals("user-123", mercadoPago.externalReference);
        assertEquals("https://app.ones.events/plans/success", mercadoPago.backUrl);
        assertNotNull(subscriptions.lastUpsert);
        assertEquals("preapproval-123", subscriptions.lastUpsert.getMercadoPagoPreapprovalId());
        assertEquals("pending", subscriptions.lastUpsert.getStatus());
        assertEquals("ones-plus-monthly", subscriptions.lastUpsert.getPlanId());
    }

    private static class InMemorySubscriptionsRepository implements UserSubscriptionsRepository {
        private UserSubscription lastUpsert;

        @Override
        public Optional<UserSubscription> findByUserId(String userId) {
            return Optional.empty();
        }

        @Override
        public Optional<UserSubscription> findByMercadoPagoPreapprovalId(String preapprovalId) {
            return Optional.empty();
        }

        @Override
        public UserSubscription upsert(UserSubscription subscription) {
            lastUpsert = subscription;
            return subscription;
        }

        @Override
        public void deleteByUserId(String userId) {
        }
    }

    private static class PaidPlanRepository implements SubscriptionPlansRepository {
        @Override
        public Optional<SubscriptionPlan> findById(String planId) {
            return Optional.of(new SubscriptionPlan(
                    planId,
                    "Ones Plus Monthly",
                    "",
                    "paid",
                    19900,
                    "COP",
                    "month",
                    "mp-plan-123",
                    Map.of("maxActiveEvents", new PlanFeature(100L, "number", "Eventos")),
                    true,
                    1,
                    NOW,
                    NOW
            ));
        }

        @Override
        public List<SubscriptionPlan> findAllActive() {
            return List.of();
        }

        @Override
        public SubscriptionPlan upsert(SubscriptionPlan plan) {
            return plan;
        }

        @Override
        public void deleteById(String planId) {
        }
    }

    private static class SingleUserRepository implements UsersRepository {
        @Override
        public Optional<User> findById(String userId) {
            return Optional.of(new User(
                    userId,
                    "user@example.com",
                    "User",
                    "User",
                    "Example",
                    null,
                    null,
                    "google",
                    "es",
                    true,
                    NOW,
                    NOW
            ));
        }

        @Override
        public Optional<User> findByEmail(String email) {
            return Optional.empty();
        }

        @Override
        public User upsert(User user) {
            return user;
        }

        @Override
        public void deleteById(String userId) {
        }
    }

    private static class RecordingMercadoPagoGateway implements MercadoPagoGateway {
        private String externalReference;
        private String backUrl;

        @Override
        public PreapprovalPlan createPlan(String reason, String billingInterval, long priceCents, String currency, String backUrl, String notificationUrl) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<PreapprovalPlan> getPlan(String preapprovalPlanId) {
            return Optional.empty();
        }

        @Override
        public Preapproval createPreapproval(String preapprovalPlanId, String payerEmail, String backUrl) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Preapproval createPreapproval(String preapprovalPlanId, String payerEmail, String backUrl, String externalReference) {
            this.externalReference = externalReference;
            this.backUrl = backUrl;
            return new Preapproval(
                    "preapproval-123",
                    "pending",
                    "https://www.mercadopago.com.co/subscriptions/checkout?preapproval_id=preapproval-123",
                    payerEmail,
                    externalReference,
                    backUrl
            );
        }

        @Override
        public Preapproval createPreapproval(String preapprovalPlanId, String payerEmail, String backUrl, String externalReference, String cardTokenId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Optional<Preapproval> getPreapproval(String preapprovalId) {
            return Optional.empty();
        }

        @Override
        public Optional<String> resolvePreapprovalIdFromPayment(String paymentId) {
            return Optional.empty();
        }

        @Override
        public Optional<String> getPayerEmailFromPayment(String paymentId) {
            return Optional.empty();
        }
    }
}
