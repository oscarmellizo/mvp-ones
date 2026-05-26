package com.ones.api.infrastructure.migrations;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.ones.api.application.translations.ports.TranslationsRepository;
import com.ones.api.domain.translations.Translation;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.context.annotation.Profile;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;

import java.io.InputStream;
import java.time.Instant;
import java.util.Iterator;

@Component
@Profile("migrate-translations")
public class TranslationsMigration implements CommandLineRunner {

    private static final Logger log = LoggerFactory.getLogger(TranslationsMigration.class);
    private static final String RESOURCE_FILE = "initial-translations.json";
    private static final String MIGRATION_ACTOR = "system-migration";

    private final TranslationsRepository translationsRepository;
    private final ObjectMapper objectMapper;

    public TranslationsMigration(TranslationsRepository translationsRepository, ObjectMapper objectMapper) {
        this.translationsRepository = translationsRepository;
        this.objectMapper = objectMapper;
    }

    @Override
    public void run(String... args) throws Exception {
        log.info("Starting translations migration...");

        try {
            InputStream inputStream = new ClassPathResource(RESOURCE_FILE).getInputStream();
            JsonNode rootNode = objectMapper.readTree(inputStream);
            Iterator<String> fieldNames = rootNode.fieldNames();

            int count = 0;
            while (fieldNames.hasNext()) {
                String translationKey = fieldNames.next();
                JsonNode languageNode = rootNode.get(translationKey);

                // Process each language (es, en, pt)
                Iterator<String> languageCodes = languageNode.fieldNames();
                while (languageCodes.hasNext()) {
                    String languageCode = languageCodes.next();
                    String value = languageNode.get(languageCode).asText();

                    Translation translation = new Translation(
                        translationKey,
                        languageCode,
                        value,
                        null, // context
                        Instant.now(),
                        Instant.now(),
                        MIGRATION_ACTOR,
                        MIGRATION_ACTOR
                    );

                    translationsRepository.upsert(translation);
                    count++;
                    log.info("Migrated: {} ({}) = {}", translationKey, languageCode, value);
                }
            }

            log.info("Translation migration completed successfully. Total translations migrated: {}", count);
        } catch (Exception e) {
            log.error("Failed to migrate translations", e);
            throw e;
        }
    }
}
