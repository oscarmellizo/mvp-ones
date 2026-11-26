package com.ones.api.domain.photos;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.HashSet;
import java.util.Set;

import org.junit.jupiter.api.Test;

class PhotoOwnerTest {
    @Test
    void eventPartitionRemainsTheEventIdForExistingPhotoQueries() {
        PhotoOwner owner = PhotoOwner.event("event-123");

        assertEquals("event-123", owner.storagePartitionId("photo-1"));
        assertEquals("event-123", owner.storagePartitionId());
    }

    @Test
    void collectionPhotosUseDeterministicShards() {
        PhotoOwner owner = PhotoOwner.collection("collection-123");
        Set<String> partitions = new HashSet<>();

        for (int i = 0; i < 1024; i++) {
            String photoId = "photo-" + i;
            String partition = owner.storagePartitionId(photoId);
            assertEquals(partition, owner.storagePartitionId(photoId));
            partitions.add(partition);
        }

        assertEquals(PhotoOwner.COLLECTION_SHARD_COUNT, partitions.size());
        assertTrue(partitions.stream().allMatch(value -> value.startsWith("COLLECTION#collection-123#")));
        assertNotEquals(owner.storagePartitionId(), owner.storagePartitionId("photo-1"));
    }
}
