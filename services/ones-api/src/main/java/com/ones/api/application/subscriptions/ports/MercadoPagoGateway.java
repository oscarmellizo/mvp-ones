package com.ones.api.application.subscriptions.ports;

import java.util.Optional;

public interface MercadoPagoGateway {

    PreapprovalPlan createPlan(
            String reason,
            String billingInterval,
            long priceCents,
            String currency,
            String backUrl,
            String notificationUrl,
            String externalReference
    );

    Optional<PreapprovalPlan> getPlan(String preapprovalPlanId);

    Preapproval createPreapproval(String preapprovalPlanId, String payerEmail, String backUrl);

    Preapproval createPreapproval(String preapprovalPlanId, String payerEmail, String backUrl, String externalReference);

    Preapproval createPreapproval(String preapprovalPlanId, String payerEmail, String backUrl, String externalReference, String cardTokenId);

    Optional<Preapproval> getPreapproval(String preapprovalId);

    Optional<String> resolvePreapprovalIdFromPayment(String paymentId);

    Optional<String> getPayerEmailFromPayment(String paymentId);

    record PreapprovalPlan(String id, String reason, String initPoint, String externalReference) {
    }

    record Preapproval(
            String id,
            String status,
            String initPoint,
            String payerEmail,
            String externalReference,
            String backUrl,
            String preapprovalPlanId
    ) {
    }
}
