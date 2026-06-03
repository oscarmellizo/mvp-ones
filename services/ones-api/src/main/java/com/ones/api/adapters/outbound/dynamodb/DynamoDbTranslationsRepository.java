package com.ones.api.adapters.outbound.dynamodb;

import java.util.Map;
import java.util.List;
import java.util.Optional;
import java.util.stream.StreamSupport;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbIndex;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Expression;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.ScanEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;
import software.amazon.awssdk.services.dynamodb.model.AttributeValue;
import software.amazon.awssdk.services.dynamodb.model.ResourceNotFoundException;

import com.ones.api.application.translations.ports.TranslationsRepository;
import com.ones.api.domain.translations.Translation;

@Repository
public class DynamoDbTranslationsRepository implements TranslationsRepository {

    private static final Logger log = LoggerFactory.getLogger(DynamoDbTranslationsRepository.class);

    private final DynamoDbTable<DynamoTranslationItem> table;
    private final Counter scanFallbackCounter;
    private final boolean failOnScanFallback;

    public DynamoDbTranslationsRepository(
            DynamoDbEnhancedClient enhancedClient,
            MeterRegistry meterRegistry,
            @Value("${ones.dynamodb.translations-table-name:ones-translations}") String tableName
            ,
            @Value("${ones.dynamodb.fail-on-scan-fallback:false}") boolean failOnScanFallback
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoTranslationItem.class));
        this.scanFallbackCounter = Counter.builder("ones.dynamodb.scan_fallback")
                .tag("repository", "translations")
                .tag("operation", "getAllTranslations")
                .register(meterRegistry);
        this.failOnScanFallback = failOnScanFallback;
    }

    @Override
    public Optional<Translation> getTranslation(String translationKey, String languageCode) {
        Key key = Key.builder()
                .partitionValue(translationKey)
                .sortValue(languageCode)
                .build();

        DynamoTranslationItem item = table.getItem(key);
        if (item == null) {
            return Optional.empty();
        }

        return Optional.of(mapToTranslation(item));
    }

    @Override
    public List<Translation> getAllTranslations(String languageCode) {
        if (languageCode == null || languageCode.isBlank()) {
            return List.of();
        }

        String normalizedLanguageCode = languageCode.trim().toLowerCase();
        Optional<List<Translation>> byIndex = getAllTranslationsUsingIndex(normalizedLanguageCode);
        if (byIndex.isPresent()) {
            return byIndex.get();
        }

        if (failOnScanFallback) {
            throw new IllegalStateException("DynamoDB Scan fallback disabled for translations.getAllTranslations; missing GSI LanguageCodeIndex");
        }

        log.warn("Falling back to DynamoDB Scan for translations.getAllTranslations; consider creating/fixing GSI LanguageCodeIndex");
        scanFallbackCounter.increment();
        return scanByLanguageCode(normalizedLanguageCode);
    }

    private Optional<List<Translation>> getAllTranslationsUsingIndex(String normalizedLanguageCode) {
        try {
            DynamoDbIndex<DynamoTranslationItem> languageIndex = table.index("LanguageCodeIndex");

            Key key = Key.builder()
                    .partitionValue(normalizedLanguageCode)
                    .build();

            QueryEnhancedRequest queryRequest = QueryEnhancedRequest.builder()
                    .queryConditional(QueryConditional.keyEqualTo(key))
                    .build();

            List<Translation> items = StreamSupport.stream(languageIndex.query(queryRequest).spliterator(), false)
                    .flatMap(page -> page.items().stream())
                    .map(this::mapToTranslation)
                    .toList();

            return Optional.of(items);
        } catch (ResourceNotFoundException e) {
            return Optional.empty();
        } catch (Exception e) {
            String msg = e.getMessage();
            if (msg != null && msg.toLowerCase().contains("languagecodeindex")) {
                return Optional.empty();
            }
            throw e;
        }
    }

    private List<Translation> scanByLanguageCode(String normalizedLanguageCode) {
        Expression filter = Expression.builder()
                .expression("#languageCode = :languageCode")
                .expressionNames(Map.of("#languageCode", "languageCode"))
                .expressionValues(Map.of(
                        ":languageCode",
                        AttributeValue.builder().s(normalizedLanguageCode).build()
                ))
                .build();

        ScanEnhancedRequest scanRequest = ScanEnhancedRequest.builder()
                .filterExpression(filter)
                .build();

        return table.scan(scanRequest)
                .items()
                .stream()
                .map(this::mapToTranslation)
                .toList();
    }

    @Override
    public List<Translation> getAllTranslations() {
        ScanEnhancedRequest scanRequest = ScanEnhancedRequest.builder().build();

        return table.scan(scanRequest)
                .items()
                .stream()
                .map(this::mapToTranslation)
                .toList();
    }

    @Override
    public Translation upsert(Translation translation) {
        DynamoTranslationItem item = mapFromTranslation(translation);
        table.putItem(item);
        return translation;
    }

    @Override
    public void deleteTranslation(String translationKey, String languageCode) {
        Key key = Key.builder()
                .partitionValue(translationKey)
                .sortValue(languageCode)
                .build();

        table.deleteItem(key);
    }

    private Translation mapToTranslation(DynamoTranslationItem item) {
        return new Translation(
                item.getTranslationKey(),
                item.getLanguageCode(),
                item.getValue(),
                item.getContext(),
                item.getCreatedAt(),
                item.getUpdatedAt(),
                item.getCreatedBy(),
                item.getUpdatedBy()
        );
    }

    private DynamoTranslationItem mapFromTranslation(Translation translation) {
        DynamoTranslationItem item = new DynamoTranslationItem();
        item.setTranslationKey(translation.getTranslationKey());
        item.setLanguageCode(translation.getLanguageCode());
        item.setValue(translation.getValue());
        item.setContext(translation.getContext());
        item.setCreatedAt(translation.getCreatedAt());
        item.setUpdatedAt(translation.getUpdatedAt());
        item.setCreatedBy(translation.getCreatedBy());
        item.setUpdatedBy(translation.getUpdatedBy());
        return item;
    }
}
