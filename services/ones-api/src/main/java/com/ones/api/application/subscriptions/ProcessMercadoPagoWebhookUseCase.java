package com.ones.api.application.subscriptions;

import java.time.Clock;
import java.time.Instant;
import java.net.URI;
import java.net.URLDecoder;
import java.nio.charset.StandardCharsets;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.subscriptions.ports.MercadoPagoGateway;
import com.ones.api.application.subscriptions.ports.UserSubscriptionsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.subscriptions.UserSubscription;
import com.ones.api.domain.users.User;

public class ProcessMercadoPagoWebhookUseCase {

    private static final Logger log = LoggerFactory.getLogger(ProcessMercadoPagoWebhookUseCase.class);

    private final UserSubscriptionsRepository subscriptionsRepository;
    private final MercadoPagoGateway mercadoPagoGateway;
    private final UsersRepository usersRepository;
    private final Clock clock;
    private final String testPayerEmail;

    public ProcessMercadoPagoWebhookUseCase(
            UserSubscriptionsRepository subscriptionsRepository,
            MercadoPagoGateway mercadoPagoGateway,
            UsersRepository usersRepository,
            Clock clock,
            String testPayerEmail
    ) {
        this.subscriptionsRepository = subscriptionsRepository;
        this.mercadoPagoGateway = mercadoPagoGateway;
        this.usersRepository = usersRepository;
        this.clock = clock;
        this.testPayerEmail = testPayerEmail;
    }

    public void execute(String topic, String resourceId) {
        log.info("[MP webhook] execute start. topic={} resourceIdPresent={} resourceId={}", topic, resourceId != null && !resourceId.isBlank(), resourceId);
        if (resourceId == null || resourceId.isBlank()) {
            log.warn("Ignoring Mercado Pago webhook without resource id: topic={}", topic);
            return;
        }

        String normalizedTopic = topic != null ? topic.toLowerCase() : "";
        boolean isPaymentTopic = normalizedTopic.contains("payment");
        boolean isSubscriptionTopic = normalizedTopic.contains("subscription") || normalizedTopic.contains("preapproval");
        log.info(
                "[MP webhook] normalizedTopic={} isPaymentTopic={} isSubscriptionTopic={}",
                normalizedTopic,
                isPaymentTopic,
                isSubscriptionTopic
        );
        if (!isSubscriptionTopic && !isPaymentTopic) {
            log.info("Ignoring unsupported Mercado Pago webhook: topic={}", topic);
            return;
        }

        String resolvedPreapprovalId = null;
        Optional<MercadoPagoGateway.Preapproval> preapproval = Optional.empty();
        Optional<MercadoPagoGateway.PaymentCorrelation> paymentCorrelation = Optional.empty();

        if (isPaymentTopic) {
            paymentCorrelation = mercadoPagoGateway.getPaymentCorrelation(resourceId);
            log.info(
                    "[MP webhook] paymentCorrelation present={} paymentId={} preapprovalIdPresent={} externalReferencePresent={} payerEmailPresent={} payerIdPresent={} preapprovalPlanIdPresent={}",
                    paymentCorrelation.isPresent(),
                    resourceId,
                    paymentCorrelation.map(MercadoPagoGateway.PaymentCorrelation::preapprovalId).filter(v -> v != null && !v.isBlank()).isPresent(),
                    paymentCorrelation.map(MercadoPagoGateway.PaymentCorrelation::externalReference).filter(v -> v != null && !v.isBlank()).isPresent(),
                    paymentCorrelation.map(MercadoPagoGateway.PaymentCorrelation::payerEmail).filter(v -> v != null && !v.isBlank()).isPresent(),
                    paymentCorrelation.map(MercadoPagoGateway.PaymentCorrelation::payerId).filter(v -> v != null && !v.isBlank()).isPresent(),
                    paymentCorrelation.map(MercadoPagoGateway.PaymentCorrelation::preapprovalPlanId).filter(v -> v != null && !v.isBlank()).isPresent()
            );
        }

        if (isSubscriptionTopic) {
            resolvedPreapprovalId = resourceId;
            log.info("[MP webhook] Treating resourceId as preapprovalId. preapprovalId={}", resolvedPreapprovalId);
            preapproval = mercadoPagoGateway.getPreapproval(resolvedPreapprovalId);
            log.info("[MP webhook] getPreapproval(preapprovalId) present={}", preapproval.isPresent());
        }

        if (preapproval.isEmpty()) {
            log.info("[MP webhook] Attempting resolvePreapprovalIdFromPayment. paymentId={} topic={}", resourceId, topic);
            Optional<String> maybePreapprovalId = paymentCorrelation
                    .map(MercadoPagoGateway.PaymentCorrelation::preapprovalId)
                    .filter(v -> v != null && !v.isBlank());
            if (maybePreapprovalId.isEmpty()) {
                maybePreapprovalId = mercadoPagoGateway.resolvePreapprovalIdFromPayment(resourceId);
            }
            log.info("[MP webhook] resolvePreapprovalIdFromPayment present={} value={}", maybePreapprovalId.isPresent(), maybePreapprovalId.orElse(null));
            if (maybePreapprovalId.isPresent()) {
                resolvedPreapprovalId = maybePreapprovalId.get();
                log.info(
                        "Resolved Mercado Pago preapprovalId from payment. paymentId={} preapprovalId={} topic={}",
                        resourceId,
                        resolvedPreapprovalId,
                        topic
                );
                preapproval = mercadoPagoGateway.getPreapproval(resolvedPreapprovalId);
                log.info("[MP webhook] getPreapproval(resolvedPreapprovalId) present={}", preapproval.isPresent());
            }
        }

        if (preapproval.isEmpty()) {
            log.warn("Could not fetch Mercado Pago preapproval. resourceId={} resolvedPreapprovalId={} topic={}", resourceId, resolvedPreapprovalId, topic);
            return;
        }

        String mpStatus = preapproval.get().status();
        String status = mapStatus(mpStatus);
        String preapprovalId = preapproval.get().id();
        String payerEmailMasked = maskEmail(preapproval.get().payerEmail());
        String externalReference = preapproval.get().externalReference();
        String backUrl = preapproval.get().backUrl();
        String preapprovalPlanId = preapproval.get().preapprovalPlanId();

        if ((externalReference == null || externalReference.isBlank()) && paymentCorrelation.isPresent()) {
            String correlationExternalReference = paymentCorrelation.get().externalReference();
            if (correlationExternalReference != null && !correlationExternalReference.isBlank()) {
                externalReference = correlationExternalReference;
                log.info("[MP webhook] using externalReference from payment correlation. externalReferencePresent=true");
            }
        }
        if ((externalReference == null || externalReference.isBlank())
                && preapprovalPlanId != null
                && !preapprovalPlanId.isBlank()) {
            Optional<MercadoPagoGateway.PreapprovalPlan> checkoutPlan = mercadoPagoGateway.getPlan(preapprovalPlanId);
            externalReference = checkoutPlan.map(MercadoPagoGateway.PreapprovalPlan::externalReference).orElse(null);
            log.info(
                    "[MP webhook] resolved externalReference from checkout plan. preapprovalPlanId={} planFound={} externalReferencePresent={}",
                    preapprovalPlanId,
                    checkoutPlan.isPresent(),
                    externalReference != null && !externalReference.isBlank()
            );
        }
        log.info(
                "[MP webhook] preapproval fetched. preapprovalId={} mpStatus={} mappedStatus={} initPointPresent={} payerEmailMasked={} externalReferencePresent={} preapprovalPlanIdPresent={}",
                preapprovalId,
                mpStatus,
                status,
                preapproval.get().initPoint() != null && !preapproval.get().initPoint().isBlank(),
                payerEmailMasked,
                externalReference != null && !externalReference.isBlank(),
                preapprovalPlanId != null && !preapprovalPlanId.isBlank()
        );

        Optional<UserSubscription> existing = subscriptionsRepository.findByMercadoPagoPreapprovalId(preapprovalId);
        log.info("[MP webhook] findByMercadoPagoPreapprovalId present={} preapprovalId={}", existing.isPresent(), preapprovalId);
        if (existing.isEmpty()) {
            String payerEmail = preapproval.get().payerEmail();
            log.info("[MP webhook] raw payerEmail present={} masked={}", payerEmail != null && !payerEmail.isBlank(), maskEmail(payerEmail));
            if ((payerEmail == null || payerEmail.isBlank()) && testPayerEmail != null && !testPayerEmail.isBlank()) {
                payerEmail = testPayerEmail;
                log.info("Using configured test payer email as fallback for MP webhook. preapprovalId={}", preapprovalId);
            }

            if ((payerEmail == null || payerEmail.isBlank()) && externalReference != null && !externalReference.isBlank()) {
                String resolvedUserId = externalReference.trim();
                log.info("[MP webhook] attempting userId match via externalReference. userId={}", resolvedUserId);
                Optional<UserSubscription> byUserId = subscriptionsRepository.findByUserId(resolvedUserId);
                log.info("[MP webhook] subscriptionsRepository.findByUserId (externalReference) present={} userId={}", byUserId.isPresent(), resolvedUserId);
                if (byUserId.isPresent()) {
                    UserSubscription attached = byUserId.get()
                            .withMercadoPagoPreapprovalId(preapprovalId, Instant.now(clock))
                            .withStatus(status, Instant.now(clock));
                    subscriptionsRepository.upsert(attached);
                    log.info("Attached preapprovalId and updated status for userId={} to {} from MP webhook (externalReference)", resolvedUserId, status);
                    return;
                }
            }

            if (payerEmail == null || payerEmail.isBlank()) {
                String onesUid = extractQueryParam(backUrl, "ones_uid");
                if (onesUid != null && !onesUid.isBlank()) {
                    String resolvedUserId = onesUid.trim();
                    log.info("[MP webhook] attempting userId match via backUrl ones_uid. userIdPresent={}", true);
                    Optional<UserSubscription> byUserId = subscriptionsRepository.findByUserId(resolvedUserId);
                    log.info("[MP webhook] subscriptionsRepository.findByUserId (backUrl ones_uid) present={} userId={}", byUserId.isPresent(), resolvedUserId);
                    if (byUserId.isPresent()) {
                        UserSubscription attached = byUserId.get()
                                .withMercadoPagoPreapprovalId(preapprovalId, Instant.now(clock))
                                .withStatus(status, Instant.now(clock));
                        subscriptionsRepository.upsert(attached);
                        log.info("Attached preapprovalId and updated status for userId={} to {} from MP webhook (backUrl ones_uid)", resolvedUserId, status);
                        return;
                    }
                }
            }

            if ((payerEmail == null || payerEmail.isBlank()) && isPaymentTopic) {
                Optional<String> paymentPayerEmail = mercadoPagoGateway.getPayerEmailFromPayment(resourceId);
                log.info(
                        "[MP webhook] getPayerEmailFromPayment present={} masked={}"
                        ,
                        paymentPayerEmail.isPresent(),
                        maskEmail(paymentPayerEmail.orElse(null))
                );
                if (paymentPayerEmail.isPresent()) {
                    Optional<User> userByPaymentEmail = usersRepository.findByEmail(paymentPayerEmail.get());
                    log.info(
                            "[MP webhook] usersRepository.findByEmail (payment) present={} payerEmailMasked={}"
                            ,
                            userByPaymentEmail.isPresent(),
                            maskEmail(paymentPayerEmail.get())
                    );
                    if (userByPaymentEmail.isPresent()) {
                        Optional<UserSubscription> byUserId = subscriptionsRepository.findByUserId(userByPaymentEmail.get().getUserId());
                        log.info(
                                "[MP webhook] subscriptionsRepository.findByUserId (payment) present={} userId={}"
                                ,
                                byUserId.isPresent(),
                                userByPaymentEmail.get().getUserId()
                        );
                        if (byUserId.isPresent()) {
                            UserSubscription attached = byUserId.get()
                                    .withMercadoPagoPreapprovalId(preapprovalId, Instant.now(clock))
                                    .withStatus(status, Instant.now(clock));
                            subscriptionsRepository.upsert(attached);
                            log.info("Attached preapprovalId and updated status for userId={} to {} from MP webhook (payment payerEmail)", userByPaymentEmail.get().getUserId(), status);
                            return;
                        }
                    }
                }
            }

            log.info(
                    "[MP webhook] resolved payerEmail after fallback. present={} masked={}",
                    payerEmail != null && !payerEmail.isBlank(),
                    maskEmail(payerEmail)
            );

            if (payerEmail == null || payerEmail.isBlank()) {
                log.warn("No subscription found for preapprovalId={}; cannot resolve payer email", preapprovalId);
                return;
            }

            Optional<User> user = usersRepository.findByEmail(payerEmail);
            log.info(
                    "[MP webhook] usersRepository.findByEmail present={} payerEmailMasked={}",
                    user.isPresent(),
                    maskEmail(payerEmail)
            );
            if (user.isEmpty()) {
                log.warn("No subscription found for preapprovalId={}; no user found for payerEmail={}", preapprovalId, payerEmail);
                return;
            }

            Optional<UserSubscription> byUser = subscriptionsRepository.findByUserId(user.get().getUserId());
            log.info(
                    "[MP webhook] subscriptionsRepository.findByUserId present={} userId={}",
                    byUser.isPresent(),
                    user.get().getUserId()
            );
            if (byUser.isEmpty()) {
                log.warn("No subscription found for preapprovalId={}; no subscription for userId={} payerEmail={}", preapprovalId, user.get().getUserId(), payerEmail);
                return;
            }

            UserSubscription attached = byUser.get()
                    .withMercadoPagoPreapprovalId(preapprovalId, Instant.now(clock))
                    .withStatus(status, Instant.now(clock));
            subscriptionsRepository.upsert(attached);
            log.info("Attached preapprovalId and updated status for userId={} to {} from MP webhook", user.get().getUserId(), status);
            return;
        }

        UserSubscription updated = existing.get().withStatus(status, Instant.now(clock));
        subscriptionsRepository.upsert(updated);
        log.info("Updated subscription status for userId={} to {} from MP webhook", existing.get().getUserId(), status);
    }

    private static String maskEmail(String email) {
        if (email == null || email.isBlank()) {
            return null;
        }
        int at = email.indexOf('@');
        if (at <= 1) {
            return "***";
        }
        String local = email.substring(0, at);
        String domain = email.substring(at);
        String prefix = local.substring(0, 1);
        return prefix + "***" + domain;
    }

    private static String mapStatus(String mpStatus) {
        if (mpStatus == null) {
            return "pending";
        }
        return switch (mpStatus.toLowerCase()) {
            case "authorized", "active" -> "active";
            case "cancelled", "cancelled_by_payer", "cancelled_by_receiver" -> "cancelled";
            case "paused" -> "paused";
            case "payment_failed", "rejected" -> "past_due";
            default -> "pending";
        };
    }

    private static String extractQueryParam(String url, String key) {
        if (url == null || url.isBlank() || key == null || key.isBlank()) {
            return null;
        }
        try {
            URI uri = URI.create(url);
            String query = uri.getRawQuery();
            if (query == null || query.isBlank()) {
                return null;
            }
            for (String part : query.split("&")) {
                int idx = part.indexOf('=');
                if (idx <= 0) {
                    continue;
                }
                String k = URLDecoder.decode(part.substring(0, idx), StandardCharsets.UTF_8);
                if (!key.equals(k)) {
                    continue;
                }
                return URLDecoder.decode(part.substring(idx + 1), StandardCharsets.UTF_8);
            }
            return null;
        } catch (RuntimeException e) {
            return null;
        }
    }
}
