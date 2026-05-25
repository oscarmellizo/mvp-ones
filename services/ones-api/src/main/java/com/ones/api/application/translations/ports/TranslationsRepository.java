package com.ones.api.application.translations.ports;

import java.util.List;
import java.util.Optional;

import com.ones.api.domain.translations.Translation;

public interface TranslationsRepository {

    Optional<Translation> getTranslation(String translationKey, String languageCode);

    List<Translation> getAllTranslations(String languageCode);

    List<Translation> getAllTranslations();

    Translation upsert(Translation translation);

    void deleteTranslation(String translationKey, String languageCode);
}
