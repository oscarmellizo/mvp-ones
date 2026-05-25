package com.ones.api.application.translations;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Set;

import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.translations.ports.TranslationsRepository;
import com.ones.api.domain.translations.Translation;

@Service
public class TranslationsManagementService {

    private final TranslationsRepository repository;
    private final Clock clock;

    private static final Set<String> VALID_LANGUAGE_CODES = Set.of("es", "en", "pt");

    public TranslationsManagementService(TranslationsRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    public Translation getTranslation(String translationKey, String languageCode) {
        return repository.getTranslation(translationKey, languageCode).orElse(null);
    }

    public List<Translation> getAllTranslations(String languageCode) {
        return repository.getAllTranslations(languageCode);
    }

    public List<Translation> getAllTranslations() {
        return repository.getAllTranslations();
    }

    public Translation upsert(Authentication authentication, String translationKey, String languageCode, String value, String context) {
        if (translationKey == null || translationKey.isBlank()) {
            throw new IllegalArgumentException("translationKey is required");
        }
        if (languageCode == null || languageCode.isBlank()) {
            throw new IllegalArgumentException("languageCode is required");
        }
        if (!VALID_LANGUAGE_CODES.contains(languageCode.toLowerCase())) {
            throw new IllegalArgumentException("Invalid languageCode. Valid values: es, en, pt");
        }

        Instant now = Instant.now(clock);
        String actor = resolveActor(authentication);

        Translation existing = repository.getTranslation(translationKey, languageCode).orElse(null);
        Instant createdAt = existing != null && existing.getCreatedAt() != null ? existing.getCreatedAt() : now;
        String createdBy = existing != null ? existing.getCreatedBy() : actor;

        Translation toSave = new Translation(
                translationKey.trim(),
                languageCode.toLowerCase(),
                value,
                context,
                createdAt,
                now,
                createdBy,
                actor
        );

        return repository.upsert(toSave);
    }

    public void deleteTranslation(String translationKey, String languageCode) {
        if (translationKey == null || translationKey.isBlank()) {
            throw new IllegalArgumentException("translationKey is required");
        }
        if (languageCode == null || languageCode.isBlank()) {
            throw new IllegalArgumentException("languageCode is required");
        }
        repository.deleteTranslation(translationKey, languageCode);
    }

    private String resolveActor(Authentication authentication) {
        if (authentication != null && authentication.getPrincipal() instanceof AuthClaims claims) {
            return claims.email();
        }
        return "system";
    }
}
