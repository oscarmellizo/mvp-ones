package com.ones.api.domain.realtime;

import java.time.Instant;
import java.util.Objects;

public class RealtimeSessionToken {

    private final String token; // PK
    private final String userId;
    private final Instant createdAt;
    private final Instant expiresAt;

    public RealtimeSessionToken(String token, String userId, Instant createdAt, Instant expiresAt) {
        this.token = Objects.requireNonNull(token);
        this.userId = Objects.requireNonNull(userId);
        this.createdAt = Objects.requireNonNull(createdAt);
        this.expiresAt = Objects.requireNonNull(expiresAt);
    }

    public String getToken() { return token; }
    public String getUserId() { return userId; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getExpiresAt() { return expiresAt; }
}
