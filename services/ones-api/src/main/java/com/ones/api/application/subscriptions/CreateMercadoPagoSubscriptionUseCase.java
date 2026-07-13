package com.ones.api.application.subscriptions;

import java.time.Clock;
import java.time.Instant;

import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;
import com.ones.api.application.subscriptions.ports.SubscriptionPlansRepository;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.subscriptions.SubscriptionPlan;
import com.ones.api.domain.subscriptions.UserSubscription;
import com.ones.api.domain.users.User;

public class CreateMercadoPagoSubscriptionUseCase {

    private final UserSubscriptionsRepository subscriptionsRepository;
    private final SubscriptionPlansRepository plansRepository;
    private final UsersRepository usersRepository;
    private final MercadoPagoGateway mercadoPagoGateway;
    private final Clock clock;
    private final String appBaseUrl;

    public CreateMercadoPagoSubscriptionUseCase(
            UserSubscriptionsRepository subscriptionsRepository,
            SubscriptionPlansRepository plansRepository,
            UsersRepository usersRepository,
            MercadoPagoGateway mercadoPagoGateway,
            Clock clock,
            String appBaseUrl
    ) {
        this.subscriptionsRepository = subscriptionsRepository;
        this.plansRepository = plansRepository;
        this.usersRepository = usersRepository;
        this.mercadoPagoGateway = mercadoPagoGateway;
        this.clock = clock;
        this.appBaseUrl = appBaseUrl;
    }

    public Result execute(String userId, String planId) {
        if (userId == null || userId.isBlank()) {
            throw new IllegalArgumentException("userId is required");
        }
        if (planId == null || planId.isBlank()) {
            throw new IllegalArgumentException("planId is required");
        }

        SubscriptionPlan plan = plansRepository.findById(planId)
                .orElseThrow(() -> new IllegalArgumentException("Plan not found: " + planId));

        if (!plan.isActive()) {
            throw new IllegalArgumentException("Plan is not active: " + planId);
        }

        if (!"paid".equalsIgnoreCase(plan.getTier())) {
            throw new IllegalArgumentException("Plan is not payable: " + planId);
        }

        User user = usersRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        String backUrl = appendPath(appBaseUrl, "/plans/success");

        MercadoPagoGateway.Preapproval preapproval = mercadoPagoGateway.createPreapproval(
                plan.getMercadoPagoPlanId(),
                user.getEmail(),
                backUrl
        );

        Instant now = Instant.now(clock);
        UserSubscription subscription = subscriptionsRepository.findByUserId(userId)
                .orElse(new UserSubscription(userId, "free", "free", null, now, null, null, null, now));

        UserSubscription updated = subscription
                .withPlan(planId, "pending", now)
                .withMercadoPagoPreapprovalId(preapproval.id(), now);

        subscriptionsRepository.upsert(updated);

        return new Result(preapproval.id(), preapproval.initPoint(), planId);
    }

    private static String appendPath(String baseUrl, String path) {
        if (baseUrl == null || baseUrl.isBlank()) {
            return null;
        }
        String normalized = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        return normalized + path;
    }

    public record Result(String preapprovalId, String initPoint, String planId) {
    }
}
