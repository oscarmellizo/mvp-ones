package com.ones.api.application.collections.ports;

import java.util.List;
import java.util.Optional;

import com.ones.api.domain.collections.Collection;

public interface CollectionsRepository {
    Collection save(Collection collection);
    boolean saveIfAbsent(Collection collection);
    Optional<Collection> findById(String id);
    List<Collection> findByIds(List<String> ids);
    List<Collection> listByOwnerId(String ownerId, int limit);

    default boolean markDeleting(String collectionId, String ownerId) {
        var collection = findById(collectionId).orElse(null);
        if (collection == null || !collection.ownerId().equals(ownerId)) return false;
        if (!collection.deleting()) save(collection.withDeleting(java.time.Instant.now()));
        return true;
    }

    default void deleteById(String collectionId) {
    }
}
