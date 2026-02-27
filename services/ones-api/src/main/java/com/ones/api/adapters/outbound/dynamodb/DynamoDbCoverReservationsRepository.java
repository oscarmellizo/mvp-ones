package com.ones.api.adapters.outbound.dynamodb;

import java.time.Instant;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Repository;

import com.ones.api.application.events.ports.CoverReservationsRepository;

import software.amazon.awssdk.enhanced.dynamodb.DynamoDbEnhancedClient;
import software.amazon.awssdk.enhanced.dynamodb.DynamoDbTable;
import software.amazon.awssdk.enhanced.dynamodb.Key;
import software.amazon.awssdk.enhanced.dynamodb.TableSchema;

@Repository
public class DynamoDbCoverReservationsRepository implements CoverReservationsRepository {

    private final DynamoDbTable<DynamoCoverReservationItem> table;

    public DynamoDbCoverReservationsRepository(
            DynamoDbEnhancedClient enhancedClient,
            @Value("${ones.dynamodb.cover-reservations-table-name:ones-cover-reservations}") String tableName
    ) {
        this.table = enhancedClient.table(tableName, TableSchema.fromBean(DynamoCoverReservationItem.class));
    }

    @Override
    public void save(
            String reservationId,
            String ownerId,
            Instant createdAt,
            Instant expiresAt,
            String tempBucket,
            String tempKey
    ) {
        DynamoCoverReservationItem item = new DynamoCoverReservationItem();
        item.setReservationId(reservationId);
        item.setOwnerId(ownerId);
        item.setCreatedAt(createdAt.toString());
        item.setExpiresAt(expiresAt.toString());
        item.setTempBucket(tempBucket);
        item.setTempKey(tempKey);
        table.putItem(item);
    }

    @Override
    public Optional<CoverReservation> findById(String reservationId) {
        DynamoCoverReservationItem item = table.getItem(Key.builder().partitionValue(reservationId).build());
        return Optional.ofNullable(item).map(DynamoDbCoverReservationsRepository::toDomain);
    }

    @Override
    public void deleteById(String reservationId) {
        table.deleteItem(Key.builder().partitionValue(reservationId).build());
    }

    private static CoverReservation toDomain(DynamoCoverReservationItem item) {
        return new CoverReservation(
                item.getReservationId(),
                item.getOwnerId(),
                Instant.parse(item.getCreatedAt()),
                Instant.parse(item.getExpiresAt()),
                item.getTempBucket(),
                item.getTempKey()
        );
    }
}
