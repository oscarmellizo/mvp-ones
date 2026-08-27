package com.ones.api.domain.realtime;

import java.time.Instant;
import java.util.Objects;

public class RealtimeConnection {

    private final String connectionId;
    private final String userId;
    private final Instant createdAt;

    public RealtimeConnection(String connectionId, String userId, Instant createdAt) {
        this.connectionId = Objects.requireNonNull(connectionId);
        this.userId = Objects.requireNonNull(userId);
        this.createdAt = Objects.requireNonNull(createdAt);
    }

    public String getConnectionId() { return connectionId; }
    public String getUserId() { return userId; }
    public Instant getCreatedAt() { return createdAt; }
}
