package com.ones.api.application.subscriptions;

import java.time.Clock;
import java.time.Instant;

import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.domain.subscriptions.UserSubscription;

public class GetOrCreateUserSubscriptionUseCase {

    private final UserSubscriptionsRepository subscriptionsRepository;
    private final Clock clock;

    public GetOrCreateUserSubscriptionUseCase(UserSubscriptionsRepository subscriptionsRepository, Clock clock) {
        this.subscriptionsRepository = subscriptionsRepository;
        this.clock = clock;
    }

    public UserSubscription execute(String userId) {
        if (userId == null || userId.isBlank()) {
            throw new IllegalArgumentException("userId is required");
        }
        return subscriptionsRepository.findByUserId(userId)
                .orElseGet(() -> createFreeSubscription(userId));
    }

    private UserSubscription createFreeSubscription(String userId) {
        Instant now = Instant.now(clock);
        UserSubscription free = new UserSubscription(
                userId,
                "free",
                "free",
                null,
                now,
                null,
                null,
                null,
                now
        );
        return subscriptionsRepository.upsert(free);
    }
}
