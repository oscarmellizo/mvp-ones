package com.ones.api.domain.users;

import java.time.Instant;
import java.util.Objects;

public class User {

    private final String userId;
    private final String email;
    private final String name;
    private final String givenName;
    private final String familyName;
    private final String picture;
    private final String preferredName;
    private final String provider;
    private final String languagePreference;
    private final boolean termsAccepted;
    private final Instant createdAt;
    private final Instant updatedAt;
    public static final String STATUS_ACTIVE = "ACTIVE";
    public static final String STATUS_DISABLED = "DISABLED";
    public static final String STATUS_CLOSED = "CLOSED";
    public static final String STATUS_DELETED = "DELETED";

    private final String status; // ACTIVE | DISABLED | CLOSED | DELETED
    private final Instant disabledAt;
    private final Instant reactivatedAt;
    private final Instant closedAt;
    private final String exportToken;
    private final String exportKey;

    public User(
            String userId,
            String email,
            String name,
            String givenName,
            String familyName,
            String picture,
            String preferredName,
            String provider,
            String languagePreference,
            boolean termsAccepted,
            Instant createdAt,
            Instant updatedAt
    ) {
        this.userId = Objects.requireNonNull(userId);
        this.email = email;
        this.name = name;
        this.givenName = givenName;
        this.familyName = familyName;
        this.picture = picture;
        this.preferredName = preferredName;
        this.provider = Objects.requireNonNull(provider);
        this.languagePreference = languagePreference;
        this.termsAccepted = termsAccepted;
        this.createdAt = Objects.requireNonNull(createdAt);
        this.updatedAt = Objects.requireNonNull(updatedAt);
        this.status = null;
        this.disabledAt = null;
        this.reactivatedAt = null;
        this.closedAt = null;
        this.exportToken = null;
        this.exportKey = null;
    }

    public User(
            String userId,
            String email,
            String name,
            String givenName,
            String familyName,
            String picture,
            String preferredName,
            String provider,
            String languagePreference,
            boolean termsAccepted,
            Instant createdAt,
            Instant updatedAt,
            String status,
            Instant disabledAt,
            Instant reactivatedAt
    ) {
        this(userId, email, name, givenName, familyName, picture, preferredName, provider,
                languagePreference, termsAccepted, createdAt, updatedAt, status, disabledAt, reactivatedAt,
                null, null, null);
    }

    public User(
            String userId,
            String email,
            String name,
            String givenName,
            String familyName,
            String picture,
            String preferredName,
            String provider,
            String languagePreference,
            boolean termsAccepted,
            Instant createdAt,
            Instant updatedAt,
            String status,
            Instant disabledAt,
            Instant reactivatedAt,
            Instant closedAt,
            String exportToken,
            String exportKey
    ) {
        this.userId = Objects.requireNonNull(userId);
        this.email = email;
        this.name = name;
        this.givenName = givenName;
        this.familyName = familyName;
        this.picture = picture;
        this.preferredName = preferredName;
        this.provider = Objects.requireNonNull(provider);
        this.languagePreference = languagePreference;
        this.termsAccepted = termsAccepted;
        this.createdAt = Objects.requireNonNull(createdAt);
        this.updatedAt = Objects.requireNonNull(updatedAt);
        this.status = status;
        this.disabledAt = disabledAt;
        this.reactivatedAt = reactivatedAt;
        this.closedAt = closedAt;
        this.exportToken = exportToken;
        this.exportKey = exportKey;
    }

    public String getUserId() {
        return userId;
    }

    public String getEmail() {
        return email;
    }

    public String getName() {
        return name;
    }

    public String getGivenName() {
        return givenName;
    }

    public String getFamilyName() {
        return familyName;
    }

    public String getPicture() {
        return picture;
    }

    public String getPreferredName() {
        return preferredName;
    }

    public String getProvider() {
        return provider;
    }

    public String getLanguagePreference() {
        return languagePreference;
    }

    public boolean isTermsAccepted() {
        return termsAccepted;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public String getStatus() {
        return status;
    }

    public Instant getDisabledAt() {
        return disabledAt;
    }

    public Instant getReactivatedAt() {
        return reactivatedAt;
    }

    public Instant getClosedAt() {
        return closedAt;
    }

    public String getExportToken() {
        return exportToken;
    }

    public String getExportKey() {
        return exportKey;
    }

    public User withLifecycle(String status, Instant closedAt, String exportToken, String exportKey) {
        return new User(userId, email, name, givenName, familyName, picture, preferredName, provider,
                languagePreference, termsAccepted, createdAt, updatedAt, status, disabledAt, reactivatedAt,
                closedAt, exportToken, exportKey);
    }

    /** Lápida tras el borrado definitivo: sin datos personales, para que un token viejo no recree la cuenta. */
    public User tombstone(Instant now) {
        return new User(userId, null, null, null, null, null, null, provider, null, false, createdAt, now,
                STATUS_DELETED, disabledAt, reactivatedAt, closedAt, null, null);
    }
}
