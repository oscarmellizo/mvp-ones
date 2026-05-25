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
    private final Instant createdAt;
    private final Instant updatedAt;

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
        this.createdAt = Objects.requireNonNull(createdAt);
        this.updatedAt = Objects.requireNonNull(updatedAt);
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

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }
}
