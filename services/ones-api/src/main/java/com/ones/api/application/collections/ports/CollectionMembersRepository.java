package com.ones.api.application.collections.ports;

import java.time.Instant;
import java.util.List;
import java.util.Optional;

import com.ones.api.domain.collections.Collection;
import com.ones.api.domain.collections.CollectionMember;

public interface CollectionMembersRepository {
    boolean add(Collection collection, CollectionMember member);
    CollectionMember save(CollectionMember member);
    boolean transition(Collection collection, CollectionMember current, CollectionMember next);
    boolean acceptInvitation(Collection collection, CollectionMember pending, String userId, Instant now);
    Optional<CollectionMember> find(String collectionId, String memberKey);
    Optional<CollectionMember> findByCollectionAndUser(String collectionId, String userId);
    Optional<CollectionMember> findByCollectionAndEmail(String collectionId, String email);
    List<CollectionMember> listByCollection(String collectionId, int limit);

    default PageResult<CollectionMember> pageByCollection(
            String collectionId,
            int limit,
            String nextToken
    ) {
        return new PageResult<>(listByCollection(collectionId, limit), null);
    }
    List<CollectionMember> listByUser(String userId, int limit);
    void remove(Collection collection, CollectionMember member);

    default void deleteByCollectionId(String collectionId) {
    }

    default boolean transferOwnership(
            Collection collection,
            String newOwnerId,
            CollectionMember formerOwnerMembership
    ) {
        return false;
    }

    record PageResult<T>(List<T> items, String nextToken) {}
}
