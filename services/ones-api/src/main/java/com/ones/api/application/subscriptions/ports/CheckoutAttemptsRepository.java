package com.ones.api.application.subscriptions.ports;

import java.util.Optional;

import com.ones.api.domain.subscriptions.CheckoutAttempt;

public interface CheckoutAttemptsRepository {

    /**
     * Creates a new active attempt for the payerEmailLower if no other active attempt exists.
     * Implementations should be concurrency-safe if possible; otherwise, they must at least
     * check for an existing non-expired active attempt and reject.
     */
    CheckoutAttempt create(CheckoutAttempt attempt);

    Optional<CheckoutAttempt> findActiveByPayerEmailLower(String payerEmailLower);

    void markCompleted(String payerEmailLower, String createdAt);
}
