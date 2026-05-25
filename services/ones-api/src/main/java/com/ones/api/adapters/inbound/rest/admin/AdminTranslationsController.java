package com.ones.api.adapters.inbound.rest.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
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

    public AdminTranslationsController(TranslationsManagementService service) {
        this.service = service;
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

    public record UpsertTranslationRequest(
            String translationKey,
            String languageCode,
            String value,
            String context
    ) {
    }
}
