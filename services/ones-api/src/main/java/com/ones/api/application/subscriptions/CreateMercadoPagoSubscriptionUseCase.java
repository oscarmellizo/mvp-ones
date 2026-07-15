package com.ones.api.application.subscriptions;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;
import com.ones.api.application.subscriptions.ports.SubscriptionPlansRepository;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.subscriptions.SubscriptionPlan;
import com.ones.api.domain.subscriptions.UserSubscription;
import com.ones.api.domain.users.User;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class CreateMercadoPagoSubscriptionUseCase {

    private static final Logger log = LoggerFactory.getLogger(CreateMercadoPagoSubscriptionUseCase.class);

    private final UserSubscriptionsRepository subscriptionsRepository;
    private final SubscriptionPlansRepository plansRepository;
    private final UsersRepository usersRepository;
    private final MercadoPagoGateway mercadoPagoGateway;
    private final Clock clock;
    private final String appBaseUrl;
    private final String testPayerEmail;

    public CreateMercadoPagoSubscriptionUseCase(
            UserSubscriptionsRepository subscriptionsRepository,
            SubscriptionPlansRepository plansRepository,
            UsersRepository usersRepository,
            MercadoPagoGateway mercadoPagoGateway,
            Clock clock,
            String appBaseUrl,
            String testPayerEmail
    ) {
        this.subscriptionsRepository = subscriptionsRepository;
        this.plansRepository = plansRepository;
        this.usersRepository = usersRepository;
        this.mercadoPagoGateway = mercadoPagoGateway;
        this.clock = clock;
        this.appBaseUrl = appBaseUrl;
        this.testPayerEmail = testPayerEmail;
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

        String mpPlanId = plan.getMercadoPagoPlanId();
        if (mpPlanId == null || mpPlanId.isBlank()) {
            throw new IllegalArgumentException("Mercado Pago plan id is not configured for plan: " + planId);
        }
        String mpPlanIdRaw = mpPlanId;
        mpPlanId = mpPlanId.trim();
        if (!mpPlanId.equals(mpPlanIdRaw)) {
            log.warn(
                    "MercadoPago plan id has leading/trailing whitespace. planId={} mpPlanIdLengthRaw={} mpPlanIdLengthTrimmed={}",
                    planId,
                    mpPlanIdRaw.length(),
                    mpPlanId.length()
            );
        }
        if (mpPlanId.startsWith("ONES_")) {
            throw new IllegalArgumentException(
                    "Mercado Pago plan id is a placeholder for plan: " + planId + ". " +
                            "Set MP_MONTHLY_PLAN_ID / MP_YEARLY_PLAN_ID and re-seed subscription plans."
            );
        }

        User user = usersRepository.findById(userId)
                .orElseThrow(() -> new IllegalArgumentException("User not found: " + userId));

        boolean testPayerOverrideActive = (testPayerEmail != null && !testPayerEmail.isBlank());
        String payerEmail = testPayerOverrideActive
                ? testPayerEmail
                : user.getEmail();

        String backUrl = appendPath(appBaseUrl, "/plans/success");

        String mpPlanIdMasked = mpPlanId == null ? null : (mpPlanId.length() <= 8
                ? "***"
                : (mpPlanId.substring(0, 4) + "..." + mpPlanId.substring(mpPlanId.length() - 4)));

        log.info(
                "Creating MercadoPago preapproval. planId={} mpPlanIdMasked={} mpPlanIdPresent={} testPayerOverrideActive={} backUrlPresent={} ",
                planId,
                mpPlanIdMasked,
                mpPlanId != null && !mpPlanId.isBlank(),
                testPayerOverrideActive,
                backUrl != null && !backUrl.isBlank()
        );

        Optional<MercadoPagoGateway.PreapprovalPlan> planDetails = mercadoPagoGateway.getPlan(mpPlanId);
        if (planDetails.isEmpty() || planDetails.get().initPoint() == null || planDetails.get().initPoint().isBlank()) {
            throw new IllegalArgumentException("Mercado Pago plan init_point is not available for plan: " + planId);
        }

        Instant now = Instant.now(clock);
        UserSubscription subscription = subscriptionsRepository.findByUserId(userId)
                .orElse(new UserSubscription(userId, "free", "free", null, now, null, null, null, now));

        UserSubscription updated = subscription
                .withPlan(planId, "pending", now)
                .withMercadoPagoPreapprovalId(null, now);

        subscriptionsRepository.upsert(updated);

        return new Result(null, planDetails.get().initPoint(), planId);
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
