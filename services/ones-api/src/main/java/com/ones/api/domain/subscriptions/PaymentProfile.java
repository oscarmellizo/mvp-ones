package com.ones.api.domain.subscriptions;

import java.time.Instant;
import java.util.Objects;

public class PaymentProfile {

    private final String userId;
    private final String mercadoPagoEmail;
    private final String country;
    private final String documentType;
    private final String documentNumber;
    private final String phoneNumber;
    private final String fullName;
    private final Instant createdAt;
    private final Instant updatedAt;
    private final Instant verifiedAt;

    public PaymentProfile(
            String userId,
            String mercadoPagoEmail,
            String country,
            String documentType,
            String documentNumber,
            String phoneNumber,
            String fullName,
            Instant createdAt,
            Instant updatedAt,
            Instant verifiedAt
    ) {
        this.userId = Objects.requireNonNull(userId);
        this.mercadoPagoEmail = mercadoPagoEmail;
        this.country = country;
        this.documentType = documentType;
        this.documentNumber = documentNumber;
        this.phoneNumber = phoneNumber;
        this.fullName = fullName;
        this.createdAt = Objects.requireNonNull(createdAt);
        this.updatedAt = Objects.requireNonNull(updatedAt);
        this.verifiedAt = verifiedAt;
    }

    public String getUserId() { return userId; }
    public String getMercadoPagoEmail() { return mercadoPagoEmail; }
    public String getCountry() { return country; }
    public String getDocumentType() { return documentType; }
    public String getDocumentNumber() { return documentNumber; }
    public String getPhoneNumber() { return phoneNumber; }
    public String getFullName() { return fullName; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getUpdatedAt() { return updatedAt; }
    public Instant getVerifiedAt() { return verifiedAt; }

    public PaymentProfile withUpdated(
            String mercadoPagoEmail,
            String country,
            String documentType,
            String documentNumber,
            String phoneNumber,
            String fullName,
            Instant updatedAt
    ) {
        return new PaymentProfile(
                userId,
                mercadoPagoEmail,
                country,
                documentType,
                documentNumber,
                phoneNumber,
                fullName,
                createdAt,
                updatedAt,
                verifiedAt
        );
    }
}
