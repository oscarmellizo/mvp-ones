package com.ones.api.domain.collections;

import java.time.Instant;

public record CollectionMember(
        String collectionId,
        String memberKey,
        String userId,
        String email,
        Status status,
        String invitedByUserId,
        Instant createdAt,
        Instant updatedAt
) {
    public enum Status {
        PENDING,
        ACCEPTED,
        REJECTED
    }

    public CollectionMember {
        if (collectionId == null || collectionId.isBlank()) throw new IllegalArgumentException("Missing collectionId");
        if (memberKey == null || memberKey.isBlank()) throw new IllegalArgumentException("Missing memberKey");
        if (status == null) throw new IllegalArgumentException("Missing membership status");
        if (createdAt == null || updatedAt == null) throw new IllegalArgumentException("Missing membership timestamps");
    }

    public boolean accepted() {
        return status == Status.ACCEPTED;
    }
}
