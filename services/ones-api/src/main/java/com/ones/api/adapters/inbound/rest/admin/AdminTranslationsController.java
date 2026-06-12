package com.ones.api.adapters.inbound.rest.admin;

import java.io.InputStream;
import java.util.Iterator;
import java.util.List;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.springframework.http.ResponseEntity;
import org.springframework.core.io.ClassPathResource;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.translations.TranslationsManagementService;
import com.ones.api.domain.translations.Translation;

@RestController
@RequestMapping("/v1/admin/translations")
public class AdminTranslationsController {

    private final TranslationsManagementService service;
    private final ObjectMapper objectMapper;

    public AdminTranslationsController(TranslationsManagementService service, ObjectMapper objectMapper) {
        this.service = service;
        this.objectMapper = objectMapper;
    }

    @GetMapping
    public List<Translation> list(
            @RequestParam(value = "languageCode", required = false) String languageCode
    ) {
        if (languageCode == null || languageCode.isBlank()) {
            return service.getAllTranslations();
        }
        return service.getAllTranslations(languageCode);
    }

    @GetMapping("/{translationKey}/{languageCode}")
    public ResponseEntity<Translation> get(
            @PathVariable("translationKey") String translationKey,
            @PathVariable("languageCode") String languageCode
    ) {
        Translation translation = service.getTranslation(translationKey, languageCode);
        if (translation == null) {
            return ResponseEntity.notFound().build();
        }
        return ResponseEntity.ok(translation);
    }

    @PostMapping
    public ResponseEntity<Translation> upsert(Authentication authentication, @RequestBody UpsertTranslationRequest request) {
        Translation saved = service.upsert(
                authentication,
                request.translationKey(),
                request.languageCode(),
                request.value(),
                request.context()
        );
        return ResponseEntity.ok(saved);
    }

    @DeleteMapping("/{translationKey}/{languageCode}")
    public ResponseEntity<Void> delete(
            @PathVariable("translationKey") String translationKey,
            @PathVariable("languageCode") String languageCode
    ) {
        service.deleteTranslation(translationKey, languageCode);
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/cache/evict")
    public ResponseEntity<Void> evictCache(
            @RequestParam(value = "languageCode", required = false) String languageCode
    ) {
        if (languageCode == null || languageCode.isBlank()) {
            service.evictTranslationsCache();
        } else {
            service.evictTranslationsCache(languageCode);
        }
        return ResponseEntity.noContent().build();
    }

    @PostMapping("/cache/refresh")
    public ResponseEntity<RefreshTranslationsCacheResponse> refreshCache(
            @RequestParam(value = "languageCode", required = false) String languageCode
    ) {
        String normalizedLanguageCode = languageCode == null ? null : languageCode.trim().toLowerCase();
        if (normalizedLanguageCode == null || normalizedLanguageCode.isBlank()) {
            service.evictTranslationsCache();
            List<String> languages = List.of("es", "en", "pt");
            int total = 0;
            for (String lang : languages) {
                total += service.getAllTranslations(lang).size();
            }
            return ResponseEntity.ok(new RefreshTranslationsCacheResponse(languages, total));
        }

        service.evictTranslationsCache(normalizedLanguageCode);
        int count = service.getAllTranslations(normalizedLanguageCode).size();
        return ResponseEntity.ok(new RefreshTranslationsCacheResponse(List.of(normalizedLanguageCode), count));
    }

    @PostMapping("/seed/initial")
    public ResponseEntity<SeedTranslationsResponse> seedInitial(Authentication authentication) throws Exception {
        InputStream inputStream = new ClassPathResource("initial-translations.json").getInputStream();
        JsonNode rootNode = objectMapper.readTree(inputStream);

        int inserted = 0;
        int skipped = 0;

        Iterator<String> fieldNames = rootNode.fieldNames();
        while (fieldNames.hasNext()) {
            String translationKey = fieldNames.next();
            JsonNode languageNode = rootNode.get(translationKey);
            if (languageNode == null || !languageNode.isObject()) {
                continue;
            }

            Iterator<String> languageCodes = languageNode.fieldNames();
            while (languageCodes.hasNext()) {
                String languageCode = languageCodes.next();
                JsonNode valueNode = languageNode.get(languageCode);
                String value = valueNode != null ? valueNode.asText() : null;
                if (value == null) {
                    continue;
                }

                Translation existing = service.getTranslation(translationKey, languageCode);
                if (existing != null && existing.getValue() != null && !existing.getValue().isBlank()) {
                    skipped++;
                    continue;
                }

                service.upsert(authentication, translationKey, languageCode, value, "seed:initial");
                inserted++;
            }
        }

        service.evictTranslationsCache();

        return ResponseEntity.ok(new SeedTranslationsResponse(inserted, skipped));
    }

    public record RefreshTranslationsCacheResponse(
            List<String> languagesWarmed,
            int totalTranslationsLoaded
    ) {
    }

    public record SeedTranslationsResponse(
            int inserted,
            int skipped
    ) {
    }

    public record UpsertTranslationRequest(
            String translationKey,
            String languageCode,
            String value,
            String context
    ) {
    }
}
