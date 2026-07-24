package com.ones.api.application.subscriptions.ports;

import java.util.Optional;

import com.ones.api.domain.subscriptions.SubscriptionPayment;

public interface SubscriptionPaymentsRepository {

    Optional<SubscriptionPayment> findByPaymentId(String paymentId);

    SubscriptionPayment upsert(SubscriptionPayment payment);
}
