package com.ones.api.application.subscriptions;

import java.time.Clock;
import java.time.Instant;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

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
        return execute(userId, planId, null);
    }

    public Result execute(String userId, String planId, String cardTokenId) {
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

        boolean cardTokenPresent = cardTokenId != null && !cardTokenId.isBlank();
        log.info(
                "Creating MercadoPago preapproval. planId={} mpPlanIdMasked={} mpPlanIdPresent={} testPayerOverrideActive={} backUrlPresent={} cardTokenPresent={} ",
                planId,
                mpPlanIdMasked,
                mpPlanId != null && !mpPlanId.isBlank(),
                testPayerOverrideActive,
                backUrl != null && !backUrl.isBlank(),
                cardTokenPresent
        );

        String externalReference = userId;
        String initPoint;
        String preapprovalId;

        if (cardTokenPresent) {
            MercadoPagoGateway.Preapproval preapproval = mercadoPagoGateway.createPreapproval(
                    mpPlanId, payerEmail, backUrl, externalReference, cardTokenId
            );
            initPoint = preapproval.initPoint();
            preapprovalId = preapproval.id();
        } else {
            String backUrlWithUid = backUrl + (backUrl.contains("?") ? "&" : "?") + "ones_uid=" + urlEncode(userId);
            try {
                MercadoPagoGateway.Preapproval preapproval = mercadoPagoGateway.createPreapproval(
                        mpPlanId,
                        payerEmail,
                        backUrlWithUid,
                        externalReference
                );
                initPoint = preapproval.initPoint();
                preapprovalId = preapproval.id();
            } catch (IllegalArgumentException e) {
                String msg = e.getMessage();
                boolean cardTokenRequired = msg != null && msg.toLowerCase().contains("card_token_id");
                if (!cardTokenRequired) {
                    throw e;
                }
                log.warn(
                        "MercadoPago rejected preapproval without card token; falling back to plan init_point. planId={} mpPlanIdMasked={}",
                        planId,
                        mpPlanIdMasked
                );
                MercadoPagoGateway.PreapprovalPlan checkoutPlan = mercadoPagoGateway.getPlan(mpPlanId)
                        .orElseThrow(() -> new IllegalArgumentException(
                                "Mercado Pago plan not found: " + planId
                        ));
                initPoint = checkoutPlan.initPoint();
                initPoint = appendQueryParam(initPoint, "external_reference", externalReference);
                initPoint = appendQueryParam(initPoint, "ones_uid", userId);
                preapprovalId = null;
            }
        }

        if (initPoint == null || initPoint.isBlank()) {
            throw new IllegalArgumentException("Mercado Pago init_point is not available for plan: " + planId);
        }

        Instant now = Instant.now(clock);
        UserSubscription subscription = subscriptionsRepository.findByUserId(userId)
                .orElse(new UserSubscription(userId, "free", "free", null, now, null, null, null, now));

        UserSubscription updated = subscription
                .withPlan(planId, "pending", now);

        if (preapprovalId != null && !preapprovalId.isBlank()) {
            updated = updated.withMercadoPagoPreapprovalId(preapprovalId, now);
        }

        subscriptionsRepository.upsert(updated);

        return new Result(preapprovalId, initPoint, planId);
    }

    private static String appendPath(String baseUrl, String path) {
        if (baseUrl == null || baseUrl.isBlank()) {
            return null;
        }
        String normalized = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        return normalized + path;
    }

    private static String urlEncode(String value) {
        if (value == null) {
            return null;
        }
        return URLEncoder.encode(value, StandardCharsets.UTF_8);
    }

    private static String appendQueryParam(String url, String key, String value) {
        if (url == null || url.isBlank() || key == null || key.isBlank() || value == null) {
            return url;
        }
        String encodedKey = urlEncode(key);
        String encodedValue = urlEncode(value);
        String separator = url.contains("?") ? "&" : "?";
        return url + separator + encodedKey + "=" + encodedValue;
    }

    public record Result(String preapprovalId, String initPoint, String planId) {
    }
}
