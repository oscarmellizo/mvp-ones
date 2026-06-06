package com.ones.api.adapters.inbound.rest.translations;

import java.util.List;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.translations.TranslationsManagementService;
import com.ones.api.domain.translations.Translation;

@RestController
@RequestMapping("/v1/translations")
public class TranslationsController {

    private final TranslationsManagementService service;

    public TranslationsController(TranslationsManagementService service) {
        this.service = service;
    }

    @GetMapping
    public List<Translation> list(
            @RequestParam("languageCode") String languageCode
    ) {
        return service.getAllTranslations(languageCode);
    }
}
