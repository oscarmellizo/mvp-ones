package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryConditional;
import software.amazon.awssdk.enhanced.dynamodb.model.QueryEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.model.ScanEnhancedRequest;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

import com.ones.api.application.translations.ports.TranslationsRepository;
import com.ones.api.domain.translations.Translation;

@Repository
public class DynamoDbTranslationsRepository implements TranslationsRepository {

    private final DynamoDbTable<DynamoTranslationItem> table;

    public DynamoDbTranslationsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.translations-table-name:ones-translations}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoTranslationItem.class));
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
        // Use scan with filter since languageCode is sort key, not partition key
        ScanEnhancedRequest scanRequest = ScanEnhancedRequest.builder()
                .build();

        return table.scan(scanRequest)
                .items()
                .stream()
                .filter(item -> item.getLanguageCode().equals(languageCode))
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
