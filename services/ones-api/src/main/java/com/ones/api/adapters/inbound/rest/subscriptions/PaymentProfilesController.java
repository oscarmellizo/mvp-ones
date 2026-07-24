package com.ones.api.adapters.inbound.rest.subscriptions;

import com.ones.api.application.subscriptions.ports.PaymentProfilesRepository;
import com.ones.api.domain.subscriptions.PaymentProfile;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;

import java.time.Clock;
import java.time.Instant;
import java.util.Objects;

@RestController
@RequestMapping("/v1")
public class PaymentProfilesController {

    private static final Logger log = LoggerFactory.getLogger(PaymentProfilesController.class);

    private final PaymentProfilesRepository repository;
    private final Clock clock;

    public PaymentProfilesController(PaymentProfilesRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @GetMapping("/users/me/payment-profile")
    public ResponseEntity<PaymentProfileResponse> getMyProfile(Authentication authentication) {
        String userId = authentication.getName();
        return ResponseEntity.ok(
                repository.findByUserId(userId)
                        .map(PaymentProfilesController::toResponse)
                        .orElse(new PaymentProfileResponse(userId, null, null, null, null, null, null, null, null))
        );
    }

    @PutMapping("/users/me/payment-profile")
    public ResponseEntity<PaymentProfileResponse> upsertMyProfile(Authentication authentication, @RequestBody PaymentProfileRequest request) {
        String userId = authentication.getName();
        Instant now = Instant.now(clock);
        var existing = repository.findByUserId(userId).orElse(null);
        PaymentProfile profile;
        if (existing == null) {
            profile = new PaymentProfile(
                    userId,
                    request.mercadoPagoEmail(),
                    request.country(),
                    request.documentType(),
                    request.documentNumber(),
                    request.phoneNumber(),
                    request.fullName(),
                    now,
                    now,
                    null
            );
        } else {
            profile = existing.withUpdated(
                    request.mercadoPagoEmail(),
                    request.country(),
                    request.documentType(),
                    request.documentNumber(),
                    request.phoneNumber(),
                    request.fullName(),
                    now
            );
        }
        repository.upsert(profile);
        return ResponseEntity.ok(toResponse(profile));
    }

    private static PaymentProfileResponse toResponse(PaymentProfile p) {
        return new PaymentProfileResponse(
                p.getUserId(),
                p.getMercadoPagoEmail(),
                p.getCountry(),
                p.getDocumentType(),
                p.getDocumentNumber(),
                p.getPhoneNumber(),
                p.getFullName(),
                p.getCreatedAt() != null ? p.getCreatedAt().toString() : null,
                p.getUpdatedAt() != null ? p.getUpdatedAt().toString() : null
        );
    }

    public record PaymentProfileRequest(
            String mercadoPagoEmail,
            String country,
            String documentType,
            String documentNumber,
            String phoneNumber,
            String fullName
    ) {}

    public record PaymentProfileResponse(
            String userId,
            String mercadoPagoEmail,
            String country,
            String documentType,
            String documentNumber,
            String phoneNumber,
            String fullName,
            String createdAt,
            String updatedAt
    ) {}
}
