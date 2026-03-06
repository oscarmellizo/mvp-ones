package com.ones.api.application.users.ports;

import java.time.Instant;
import java.util.Map;
import java.util.Set;

public interface PreferredNamesCacheRepository {

    Map<String, CachedPreferredName> getMany(Set<String> userIds);

    void put(String userId, String preferredName, Instant expiresAt, Instant updatedAt);

    void delete(String userId);

    record CachedPreferredName(String userId, String preferredName, Instant updatedAt, Instant expiresAt) {
    }
}
