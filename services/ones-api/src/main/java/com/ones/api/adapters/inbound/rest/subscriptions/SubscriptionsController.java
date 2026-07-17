package com.ones.api.adapters.inbound.rest.subscriptions;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.adapters.inbound.rest.users.EnsureUserResponse;
import com.ones.api.application.subscriptions.CreateMercadoPagoSubscriptionUseCase;
import com.ones.api.application.subscriptions.GetOrCreateUserSubscriptionUseCase;
import com.ones.api.application.subscriptions.GetSubscriptionPlansUseCase;
import com.ones.api.application.users.GetUserByIdUseCase;
import com.ones.api.domain.subscriptions.SubscriptionPlan;
import com.ones.api.domain.subscriptions.UserSubscription;
import com.ones.api.domain.users.User;

@RestController
@RequestMapping("/v1")
public class SubscriptionsController {

    private final GetSubscriptionPlansUseCase getSubscriptionPlansUseCase;
    private final GetOrCreateUserSubscriptionUseCase getOrCreateUserSubscriptionUseCase;
    private final CreateMercadoPagoSubscriptionUseCase createMercadoPagoSubscriptionUseCase;
    private final GetUserByIdUseCase getUserByIdUseCase;

    public SubscriptionsController(
            GetSubscriptionPlansUseCase getSubscriptionPlansUseCase,
            GetOrCreateUserSubscriptionUseCase getOrCreateUserSubscriptionUseCase,
            CreateMercadoPagoSubscriptionUseCase createMercadoPagoSubscriptionUseCase,
            GetUserByIdUseCase getUserByIdUseCase
    ) {
        this.getSubscriptionPlansUseCase = getSubscriptionPlansUseCase;
        this.getOrCreateUserSubscriptionUseCase = getOrCreateUserSubscriptionUseCase;
        this.createMercadoPagoSubscriptionUseCase = createMercadoPagoSubscriptionUseCase;
        this.getUserByIdUseCase = getUserByIdUseCase;
    }

    @GetMapping("/subscription-plans")
    public ResponseEntity<List<SubscriptionPlanResponse>> listPlans() {
        List<SubscriptionPlan> plans = getSubscriptionPlansUseCase.execute();
        return ResponseEntity.ok(plans.stream().map(this::toResponse).toList());
    }

    @GetMapping("/users/me/subscription")
    public ResponseEntity<UserSubscriptionResponse> getMySubscription(Authentication authentication) {
        String userId = authentication.getName();
        UserSubscription subscription = getOrCreateUserSubscriptionUseCase.execute(userId);
        return ResponseEntity.ok(toResponse(subscription));
    }

    @PostMapping("/users/me/subscription/mercadopago")
    public ResponseEntity<CreateSubscriptionResponse> createMercadoPagoSubscription(
            Authentication authentication,
            @RequestBody CreateSubscriptionRequest request
    ) {
        String userId = authentication.getName();
        String planId = request != null ? request.planId() : null;
        String cardTokenId = request != null ? request.cardTokenId() : null;
        CreateMercadoPagoSubscriptionUseCase.Result result = createMercadoPagoSubscriptionUseCase.execute(userId, planId, cardTokenId);
        return ResponseEntity.ok(new CreateSubscriptionResponse(
                result.preapprovalId(),
                result.initPoint(),
                result.planId()
        ));
    }

    private SubscriptionPlanResponse toResponse(SubscriptionPlan plan) {
        return new SubscriptionPlanResponse(
                plan.getPlanId(),
                plan.getName(),
                plan.getShortDescription(),
                plan.getTier(),
                plan.getPriceCents(),
                plan.getCurrency(),
                plan.getBillingInterval(),
                plan.getFeatures()
        );
    }

    private UserSubscriptionResponse toResponse(UserSubscription subscription) {
        User user = getUserByIdUseCase.execute(subscription.getUserId()).orElse(null);
        return new UserSubscriptionResponse(
                subscription.getUserId(),
                subscription.getPlanId(),
                subscription.getStatus(),
                subscription.getMercadoPagoPreapprovalId(),
                subscription.getStartedAt() != null ? subscription.getStartedAt().toString() : null,
                subscription.getExpiresAt() != null ? subscription.getExpiresAt().toString() : null,
                subscription.getNextPaymentDate() != null ? subscription.getNextPaymentDate().toString() : null,
                user != null ? new EnsureUserResponse(
                        user.getUserId(),
                        user.getEmail(),
                        user.getName(),
                        user.getGivenName(),
                        user.getFamilyName(),
                        user.getPicture(),
                        user.getPreferredName(),
                        user.getProvider(),
                        user.getLanguagePreference(),
                        user.isTermsAccepted(),
                        user.getCreatedAt(),
                        user.getUpdatedAt()
                ) : null
        );
    }

    public record CreateSubscriptionRequest(String planId, String cardTokenId) {
    }

    public record CreateSubscriptionResponse(String preapprovalId, String initPoint, String planId) {
    }

    public record SubscriptionPlanResponse(
            String planId,
            String name,
            String shortDescription,
            String tier,
            long priceCents,
            String currency,
            String billingInterval,
            java.util.Map<String, com.ones.api.domain.subscriptions.PlanFeature> features
    ) {
    }

    public record UserSubscriptionResponse(
            String userId,
            String planId,
            String status,
            String mercadoPagoPreapprovalId,
            String startedAt,
            String expiresAt,
            String nextPaymentDate,
            EnsureUserResponse user
    ) {
    }
}
