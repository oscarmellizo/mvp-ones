package com.ones.api.domain.photos;

import java.util.Objects;
import java.util.Locale;

public record PhotoOwner(Type type, String id) {
    public static final int COLLECTION_SHARD_COUNT = 16;

    public PhotoOwner {
        Objects.requireNonNull(type, "type");
        if (id == null || id.isBlank()) {
            throw new IllegalArgumentException("Photo owner id is required");
        }
        id = id.trim();
    }

    public static PhotoOwner event(String eventId) {
        return new PhotoOwner(Type.EVENT, eventId);
    }

    public static PhotoOwner collection(String collectionId) {
        return new PhotoOwner(Type.COLLECTION, collectionId);
    }

    public String storagePartitionId() {
        return type == Type.EVENT ? id : "COLLECTION#" + id;
    }

    public String storagePartitionId(String photoId) {
        if (type == Type.EVENT) return id;
        int shard = Math.floorMod(photoId == null ? 0 : photoId.hashCode(), COLLECTION_SHARD_COUNT);
        return collectionPartitionId(shard);
    }

    public String collectionPartitionId(int shard) {
        if (type != Type.COLLECTION || shard < 0 || shard >= COLLECTION_SHARD_COUNT) {
            throw new IllegalArgumentException("Invalid collection photo shard");
        }
        return "COLLECTION#" + id + "#" + String.format(Locale.ROOT, "%02d", shard);
    }

    public enum Type {
        EVENT,
        COLLECTION
    }
}
