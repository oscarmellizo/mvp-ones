package com.ones.api.domain.translations;

import java.time.Instant;
import java.util.Objects;

public class Translation {

    private final String translationKey;
    private final String languageCode;
    private final String value;
    private final String context;
    private final Instant createdAt;
    private final Instant updatedAt;
    private final String createdBy;
    private final String updatedBy;

    public Translation(
            String translationKey,
            String languageCode,
            String value,
            String context,
            Instant createdAt,
            Instant updatedAt,
            String createdBy,
            String updatedBy
    ) {
        this.translationKey = Objects.requireNonNull(translationKey);
        this.languageCode = Objects.requireNonNull(languageCode);
        this.value = value;
        this.context = context;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.createdBy = createdBy;
        this.updatedBy = updatedBy;
    }

    public String getTranslationKey() {
        return translationKey;
    }

    public String getLanguageCode() {
        return languageCode;
    }

    public String getValue() {
        return value;
    }

    public String getContext() {
        return context;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public String getUpdatedBy() {
        return updatedBy;
    }
}
