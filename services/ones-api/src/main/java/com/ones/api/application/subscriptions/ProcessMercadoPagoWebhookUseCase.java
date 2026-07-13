package com.ones.api.application.subscriptions;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.domain.subscriptions.UserSubscription;

public class ProcessMercadoPagoWebhookUseCase {

    private static final Logger log = LoggerFactory.getLogger(ProcessMercadoPagoWebhookUseCase.class);

    private final UserSubscriptionsRepository subscriptionsRepository;
    private final MercadoPagoGateway mercadoPagoGateway;
    private final Clock clock;

    public ProcessMercadoPagoWebhookUseCase(
            UserSubscriptionsRepository subscriptionsRepository,
            MercadoPagoGateway mercadoPagoGateway,
            Clock clock
    ) {
        this.subscriptionsRepository = subscriptionsRepository;
        this.mercadoPagoGateway = mercadoPagoGateway;
        this.clock = clock;
    }

    public void execute(String topic, String resourceId) {
        if (resourceId == null || resourceId.isBlank()) {
            log.warn("Ignoring Mercado Pago webhook without resource id: topic={}", topic);
            return;
        }

        String normalizedTopic = topic != null ? topic.toLowerCase() : "";
        if (!normalizedTopic.contains("subscription") && !normalizedTopic.contains("preapproval")) {
            log.info("Ignoring non-subscription Mercado Pago webhook: topic={}", topic);
            return;
        }

        Optional<MercadoPagoGateway.Preapproval> preapproval = mercadoPagoGateway.getPreapproval(resourceId);
        if (preapproval.isEmpty()) {
            log.warn("Could not fetch Mercado Pago preapproval: id={}", resourceId);
            return;
        }

        String status = mapStatus(preapproval.get().status());
        String preapprovalId = preapproval.get().id();

        Optional<UserSubscription> existing = subscriptionsRepository.findByMercadoPagoPreapprovalId(preapprovalId);
        if (existing.isEmpty()) {
            log.warn("No subscription found for preapprovalId={}; cannot update status", preapprovalId);
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
