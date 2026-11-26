package com.ones.api.domain.collections;

import java.time.Instant;
import java.util.Objects;

public record Collection(
        String id,
        String ownerId,
        String name,
        String description,
        CollectionType type,
        String coverKey,
        String purpose,
        Instant createdAt,
        Instant updatedAt,
        boolean joinEnabled,
        String joinTokenHash,
        boolean deleting,
        String partnerSlotKey
) {
    public Collection {
        if (id == null || id.isBlank()) throw new IllegalArgumentException("Collection id is required");
        if (ownerId == null || ownerId.isBlank()) throw new IllegalArgumentException("Collection owner is required");
        if (name == null || name.isBlank()) throw new IllegalArgumentException("Collection name is required");
        if (name.trim().length() > 100) throw new IllegalArgumentException("Collection name is too long");
        Objects.requireNonNull(type, "Collection type is required");
        Objects.requireNonNull(createdAt, "Collection creation time is required");
        Objects.requireNonNull(updatedAt, "Collection update time is required");
        if (type == CollectionType.PRIVATE && joinEnabled) {
            throw new IllegalArgumentException("Private collections cannot enable QR joining");
        }
    }

    public boolean isLifeCollection() {
        return "LIFE".equals(purpose);
    }

    public Collection update(String name, String description, String coverKey, Instant now) {
        return new Collection(
                id, ownerId, name.trim(), normalize(description), type, coverKey,
                purpose, createdAt, now, joinEnabled, joinTokenHash, deleting, partnerSlotKey
        );
    }

    public Collection withJoinQr(boolean enabled, String tokenHash, Instant now) {
        if (enabled && (type == CollectionType.PRIVATE || isLifeCollection())) {
            throw new IllegalArgumentException("This collection cannot enable QR joining");
        }
        return new Collection(
                id, ownerId, name, description, type, coverKey, purpose,
                createdAt, now, enabled, tokenHash, deleting, partnerSlotKey
        );
    }

    public Collection withDeleting(Instant now) {
        return new Collection(
                id, ownerId, name, description, type, coverKey, purpose,
                createdAt, now, false, null, true, partnerSlotKey
        );
    }

    private static String normalize(String value) {
        if (value == null || value.isBlank()) return null;
        return value.trim();
    }
}
