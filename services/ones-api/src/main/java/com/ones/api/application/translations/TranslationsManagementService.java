package com.ones.api.application.translations;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.Set;

import org.springframework.cache.annotation.CacheEvict;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.translations.ports.TranslationsRepository;
import com.ones.api.configuration.CacheConfig;
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

    @Cacheable(
            cacheNames = CacheConfig.TRANSLATIONS_BY_LANGUAGE_CACHE,
            key = "#languageCode == null ? '' : #languageCode.toLowerCase()",
            sync = true
    )
    public List<Translation> getAllTranslations(String languageCode) {
        if (languageCode == null || languageCode.isBlank()) {
            throw new IllegalArgumentException("languageCode is required");
        }
        return repository.getAllTranslations(languageCode);
    }

    @Cacheable(
            cacheNames = CacheConfig.TRANSLATIONS_BY_LANGUAGE_CACHE,
            key = "'__all__'",
            sync = true
    )
    public List<Translation> getAllTranslations() {
        return repository.getAllTranslations();
    }

    @CacheEvict(
            cacheNames = CacheConfig.TRANSLATIONS_BY_LANGUAGE_CACHE,
            allEntries = true
    )
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

    @CacheEvict(
            cacheNames = CacheConfig.TRANSLATIONS_BY_LANGUAGE_CACHE,
            allEntries = true
    )
    public void deleteTranslation(String translationKey, String languageCode) {
        if (translationKey == null || translationKey.isBlank()) {
            throw new IllegalArgumentException("translationKey is required");
        }
        if (languageCode == null || languageCode.isBlank()) {
            throw new IllegalArgumentException("languageCode is required");
        }
        repository.deleteTranslation(translationKey, languageCode);
    }

    @CacheEvict(
            cacheNames = CacheConfig.TRANSLATIONS_BY_LANGUAGE_CACHE,
            allEntries = true
    )
    public void evictTranslationsCache() {
    }

    @CacheEvict(
            cacheNames = CacheConfig.TRANSLATIONS_BY_LANGUAGE_CACHE,
            key = "#languageCode == null ? '' : #languageCode.toLowerCase()"
    )
    public void evictTranslationsCache(String languageCode) {
    }

    private String resolveActor(Authentication authentication) {
        if (authentication != null) {
            try {
                return AuthClaims.requireEmail(authentication);
            } catch (Exception e) {
                // Fall back to system if email is not available
            }
        }
        return "system";
    }
}
