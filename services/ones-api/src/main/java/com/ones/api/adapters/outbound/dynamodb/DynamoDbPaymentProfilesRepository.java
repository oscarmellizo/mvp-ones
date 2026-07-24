package com.ones.api.adapters.outbound.dynamodb;

import com.ones.api.application.subscriptions.ports.PaymentProfilesRepository;
import com.ones.api.domain.subscriptions.PaymentProfile;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

import java.time.Instant;
import java.util.Optional;

@Repository
public class DynamoDbPaymentProfilesRepository implements PaymentProfilesRepository {

    private final DynamoDbTable<DynamoPaymentProfileItem> table;

    public DynamoDbPaymentProfilesRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.payment-profiles-table-name:ones-payment-profiles}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoPaymentProfileItem.class));
    }

    @Override
    public Optional<PaymentProfile> findByUserId(String userId) {
        if (userId == null || userId.isBlank()) return Optional.empty();
        DynamoPaymentProfileItem item = table.getItem(Key.builder().partitionValue(userId.trim()).build());
        return Optional.ofNullable(item).map(DynamoDbPaymentProfilesRepository::toDomain);
    }

    @Override
    public PaymentProfile upsert(PaymentProfile profile) {
        table.putItem(toItem(profile));
        return profile;
    }

    private static DynamoPaymentProfileItem toItem(PaymentProfile p) {
        DynamoPaymentProfileItem i = new DynamoPaymentProfileItem();
        i.setUserId(p.getUserId());
        i.setMercadoPagoEmail(p.getMercadoPagoEmail());
        i.setMercadoPagoEmailLower(p.getMercadoPagoEmail() != null ? p.getMercadoPagoEmail().trim().toLowerCase() : null);
        i.setCountry(p.getCountry());
        i.setDocumentType(p.getDocumentType());
        i.setDocumentNumber(p.getDocumentNumber());
        i.setPhoneNumber(p.getPhoneNumber());
        i.setFullName(p.getFullName());
        i.setCreatedAt(p.getCreatedAt().toString());
        i.setUpdatedAt(p.getUpdatedAt().toString());
        i.setVerifiedAt(p.getVerifiedAt() != null ? p.getVerifiedAt().toString() : null);
        return i;
    }

    private static PaymentProfile toDomain(DynamoPaymentProfileItem i) {
        return new PaymentProfile(
                i.getUserId(),
                i.getMercadoPagoEmail(),
                i.getCountry(),
                i.getDocumentType(),
                i.getDocumentNumber(),
                i.getPhoneNumber(),
                i.getFullName(),
                Instant.parse(i.getCreatedAt()),
                Instant.parse(i.getUpdatedAt()),
                i.getVerifiedAt() != null && !i.getVerifiedAt().isBlank() ? Instant.parse(i.getVerifiedAt()) : null
        );
    }
}
