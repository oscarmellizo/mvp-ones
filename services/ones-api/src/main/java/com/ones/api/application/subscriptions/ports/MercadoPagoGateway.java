package com.ones.api.application.subscriptions.ports;

import java.util.Optional;

/** Only supports cancellation of subscriptions created before free access. */
public interface MercadoPagoGateway {
    Optional<Preapproval> getPreapproval(String preapprovalId);

    void cancelPreapproval(String preapprovalId);

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
