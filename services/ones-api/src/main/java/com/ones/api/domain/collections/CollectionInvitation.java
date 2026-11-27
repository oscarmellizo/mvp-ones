package com.ones.api.domain.collections;

import java.time.Instant;

public record CollectionInvitation(
        String collectionId,
        String collectionName,
        String invitedByUserId,
        Instant createdAt
) {
    public CollectionInvitation {
        if (collectionId == null || collectionId.isBlank()) {
            throw new IllegalArgumentException("Missing collectionId");
        }
        if (collectionName == null || collectionName.isBlank()) {
            throw new IllegalArgumentException("Missing collectionName");
        }
        if (createdAt == null) {
            throw new IllegalArgumentException("Missing createdAt");
        }
    }
}
