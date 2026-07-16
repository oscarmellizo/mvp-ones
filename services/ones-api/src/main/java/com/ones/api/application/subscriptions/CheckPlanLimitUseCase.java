package com.ones.api.application.subscriptions;

import com.ones.api.application.subscriptions.ports.SubscriptionPlansRepository;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.domain.subscriptions.SubscriptionPlan;
import com.ones.api.domain.subscriptions.UserSubscription;

public class CheckPlanLimitUseCase {

    private final UserSubscriptionsRepository subscriptionsRepository;
    private final SubscriptionPlansRepository plansRepository;

    public CheckPlanLimitUseCase(
            UserSubscriptionsRepository subscriptionsRepository,
            SubscriptionPlansRepository plansRepository
    ) {
        this.subscriptionsRepository = subscriptionsRepository;
        this.plansRepository = plansRepository;
    }

    public void execute(String userId, String featureKey, long currentCount) {
        if (userId == null || userId.isBlank()) {
            throw new IllegalArgumentException("userId is required");
        }

        UserSubscription subscription = subscriptionsRepository.findByUserId(userId)
                .orElseThrow(() -> new IllegalStateException("User subscription not found: " + userId));

        SubscriptionPlan plan = plansRepository.findById(subscription.getPlanId())
                .orElseThrow(() -> new IllegalStateException("Subscription plan not found: " + subscription.getPlanId()));

        Long limit = plan.getFeatureValue(featureKey) instanceof Number
                ? ((Number) plan.getFeatureValue(featureKey)).longValue()
                : null;

        if (limit == null) {
            return;
        }

        if (currentCount >= limit) {
            throw new PlanLimitExceededException(
                    "Plan limit exceeded for feature " + featureKey + ": limit=" + limit + ", current=" + currentCount
            );
        }
    }

    public long getLimit(String userId, String featureKey, long defaultValue) {
        if (userId == null || userId.isBlank()) {
            return defaultValue;
        }

        return subscriptionsRepository.findByUserId(userId)
                .flatMap(sub -> plansRepository.findById(sub.getPlanId()))
                .map(plan -> {
                    Object value = plan.getFeatureValue(featureKey);
                    return value instanceof Number ? ((Number) value).longValue() : defaultValue;
                })
                .orElse(defaultValue);
    }

    public static class PlanLimitExceededException extends RuntimeException {
        public PlanLimitExceededException(String message) {
            super(message);
        }
    }
}
