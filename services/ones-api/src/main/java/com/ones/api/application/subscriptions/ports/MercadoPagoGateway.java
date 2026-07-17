package com.ones.api.application.subscriptions.ports;

import java.util.Optional;

public interface MercadoPagoGateway {

    PreapprovalPlan createPlan(String reason, String billingInterval, long priceCents, String currency, String backUrl, String notificationUrl);

    Optional<PreapprovalPlan> getPlan(String preapprovalPlanId);

    Preapproval createPreapproval(String preapprovalPlanId, String payerEmail, String backUrl);

    Preapproval createPreapproval(String preapprovalPlanId, String payerEmail, String backUrl, String externalReference, String cardTokenId);

    Optional<Preapproval> getPreapproval(String preapprovalId);

    Optional<String> resolvePreapprovalIdFromPayment(String paymentId);

    record PreapprovalPlan(String id, String reason, String initPoint) {
    }

    record Preapproval(String id, String status, String initPoint, String payerEmail, String externalReference) {
    }
}
