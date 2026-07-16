package com.ones.api.application.subscriptions;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.subscriptions.UserSubscription;
import com.ones.api.domain.users.User;

public class ProcessMercadoPagoWebhookUseCase {

    private static final Logger log = LoggerFactory.getLogger(ProcessMercadoPagoWebhookUseCase.class);

    private final UserSubscriptionsRepository subscriptionsRepository;
    private final MercadoPagoGateway mercadoPagoGateway;
    private final UsersRepository usersRepository;
    private final Clock clock;

    public ProcessMercadoPagoWebhookUseCase(
            UserSubscriptionsRepository subscriptionsRepository,
            MercadoPagoGateway mercadoPagoGateway,
            UsersRepository usersRepository,
            Clock clock
    ) {
        this.subscriptionsRepository = subscriptionsRepository;
        this.mercadoPagoGateway = mercadoPagoGateway;
        this.usersRepository = usersRepository;
        this.clock = clock;
    }

    public void execute(String topic, String resourceId) {
        if (resourceId == null || resourceId.isBlank()) {
            log.warn("Ignoring Mercado Pago webhook without resource id: topic={}", topic);
            return;
        }

        String normalizedTopic = topic != null ? topic.toLowerCase() : "";
        boolean isPaymentTopic = normalizedTopic.contains("payment");
        boolean isSubscriptionTopic = normalizedTopic.contains("subscription") || normalizedTopic.contains("preapproval");
        if (!isSubscriptionTopic && !isPaymentTopic) {
            log.info("Ignoring unsupported Mercado Pago webhook: topic={}", topic);
            return;
        }

        String resolvedPreapprovalId = null;
        Optional<MercadoPagoGateway.Preapproval> preapproval = Optional.empty();

        if (isSubscriptionTopic) {
            resolvedPreapprovalId = resourceId;
            preapproval = mercadoPagoGateway.getPreapproval(resolvedPreapprovalId);
        }

        if (preapproval.isEmpty()) {
            Optional<String> maybePreapprovalId = mercadoPagoGateway.resolvePreapprovalIdFromPayment(resourceId);
            if (maybePreapprovalId.isPresent()) {
                resolvedPreapprovalId = maybePreapprovalId.get();
                log.info(
                        "Resolved Mercado Pago preapprovalId from payment. paymentId={} preapprovalId={} topic={}",
                        resourceId,
                        resolvedPreapprovalId,
                        topic
                );
                preapproval = mercadoPagoGateway.getPreapproval(resolvedPreapprovalId);
            }
        }

        if (preapproval.isEmpty()) {
            log.warn("Could not fetch Mercado Pago preapproval. resourceId={} resolvedPreapprovalId={} topic={}", resourceId, resolvedPreapprovalId, topic);
            return;
        }

        String status = mapStatus(preapproval.get().status());
        String preapprovalId = preapproval.get().id();

        Optional<UserSubscription> existing = subscriptionsRepository.findByMercadoPagoPreapprovalId(preapprovalId);
        if (existing.isEmpty()) {
            String payerEmail = preapproval.get().payerEmail();

            if (payerEmail == null || payerEmail.isBlank()) {
                log.warn("No subscription found for preapprovalId={}; cannot resolve payer email", preapprovalId);
                return;
            }

            Optional<User> user = usersRepository.findByEmail(payerEmail);
            if (user.isEmpty()) {
                log.warn("No subscription found for preapprovalId={}; no user found for payerEmail={}", preapprovalId, payerEmail);
                return;
            }

            Optional<UserSubscription> byUser = subscriptionsRepository.findByUserId(user.get().getUserId());
            if (byUser.isEmpty()) {
                log.warn("No subscription found for preapprovalId={}; no subscription for userId={} payerEmail={}", preapprovalId, user.get().getUserId(), payerEmail);
                return;
            }

            UserSubscription attached = byUser.get()
                    .withMercadoPagoPreapprovalId(preapprovalId, Instant.now(clock))
                    .withStatus(status, Instant.now(clock));
            subscriptionsRepository.upsert(attached);
            log.info("Attached preapprovalId and updated status for userId={} to {} from MP webhook", user.get().getUserId(), status);
            return;
        }

        UserSubscription updated = existing.get().withStatus(status, Instant.now(clock));
        subscriptionsRepository.upsert(updated);
        log.info("Updated subscription status for userId={} to {} from MP webhook", existing.get().getUserId(), status);
    }

    private static String mapStatus(String mpStatus) {
        if (mpStatus == null) {
            return "pending";
        }
        return switch (mpStatus.toLowerCase()) {
            case "authorized", "active" -> "active";
            case "cancelled", "cancelled_by_payer", "cancelled_by_receiver" -> "cancelled";
            case "paused" -> "paused";
            case "payment_failed", "rejected" -> "past_due";
            default -> "pending";
        };
    }
}
