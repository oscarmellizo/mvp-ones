package com.ones.api.application.events.ports;

import java.time.Instant;
import java.util.Optional;

public interface CoverReservationsRepository {

    void save(
            String reservationId,
            String ownerId,
            Instant createdAt,
            Instant expiresAt,
            String tempBucket,
            String tempKey
    );

    Optional<CoverReservation> findById(String reservationId);

    void deleteById(String reservationId);

    record CoverReservation(
            String reservationId,
            String ownerId,
            Instant createdAt,
            Instant expiresAt,
            String tempBucket,
            String tempKey
    ) {
    }
}
