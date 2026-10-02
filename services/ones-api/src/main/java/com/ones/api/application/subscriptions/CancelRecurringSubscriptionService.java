package com.ones.api.application.subscriptions;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.domain.subscriptions.UserSubscription;

/**
 * Cancela en Mercado Pago la suscripción recurrente (preapproval) de una cuenta y la marca cancelada localmente.
 * Se usa al desactivar la cuenta y, por si acaso, al cerrarla. Idempotente.
 */
public class CancelRecurringSubscriptionService {

    private static final Logger log = LoggerFactory.getLogger(CancelRecurringSubscriptionService.class);

    private final UserSubscriptionsRepository subscriptionsRepository;
    private final MercadoPagoGateway mercadoPagoGateway;
    private final Clock clock;

    public CancelRecurringSubscriptionService(UserSubscriptionsRepository subscriptionsRepository,
                                              MercadoPagoGateway mercadoPagoGateway, Clock clock) {
        this.subscriptionsRepository = subscriptionsRepository;
        this.mercadoPagoGateway = mercadoPagoGateway;
        this.clock = clock;
    }

    /** @throws SubscriptionCancellationException si Mercado Pago falla; en ese caso no se cambia nada local. */
    public void cancelFor(String userId) {
        Optional<UserSubscription> found = subscriptionsRepository.findByUserId(userId);
        if (found.isEmpty()) return;
        UserSubscription s = found.get();
        String preapprovalId = s.getMercadoPagoPreapprovalId();
        if (preapprovalId == null || preapprovalId.isBlank() || isCancelled(s.getStatus())) return;

        try {
            // Si en Mercado Pago ya no existe o ya está cancelada, no se vuelve a pedir (MP rechaza cambiarla).
            Optional<MercadoPagoGateway.Preapproval> remote = mercadoPagoGateway.getPreapproval(preapprovalId);
            if (remote.isPresent() && !isCancelled(remote.get().status())) {
                mercadoPagoGateway.cancelPreapproval(preapprovalId);
            }
        } catch (RuntimeException e) {
            throw new SubscriptionCancellationException(userId, e);
        }

        Instant now = Instant.now(clock);
        subscriptionsRepository.upsert(new UserSubscription(s.getUserId(), s.getPlanId(), "cancelled", preapprovalId,
                s.getStartedAt(), s.getExpiresAt(), null, now, now));
        log.info("[Subscriptions] suscripción recurrente cancelada userId={} preapprovalId={}", userId, preapprovalId);
    }

    private static boolean isCancelled(String status) {
        return status != null && status.toLowerCase().startsWith("cancelled");
    }
}
