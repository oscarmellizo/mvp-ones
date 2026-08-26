package com.ones.api.domain.push;

import java.time.Instant;
import java.util.Objects;

public class DeviceToken {

    private final String userId;
    private final String platform; // ios|android|web
    private final String token;    // raw token (optional to store)
    private final String tokenHash; // sha256 of token (hex)
    private final Instant createdAt;
    private final Instant lastUsedAt;
    private final boolean enabled;
    private final String deviceInfo; // optional

    public DeviceToken(
            String userId,
            String platform,
            String token,
            String tokenHash,
            Instant createdAt,
            Instant lastUsedAt,
            boolean enabled,
            String deviceInfo
    ) {
        this.userId = Objects.requireNonNull(userId);
        this.platform = Objects.requireNonNull(platform);
        this.token = token;
        this.tokenHash = Objects.requireNonNull(tokenHash);
        this.createdAt = Objects.requireNonNull(createdAt);
        this.lastUsedAt = lastUsedAt != null ? lastUsedAt : createdAt;
        this.enabled = enabled;
        this.deviceInfo = deviceInfo;
    }

    public String getUserId() { return userId; }
    public String getPlatform() { return platform; }
    public String getToken() { return token; }
    public String getTokenHash() { return tokenHash; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getLastUsedAt() { return lastUsedAt; }
    public boolean isEnabled() { return enabled; }
    public String getDeviceInfo() { return deviceInfo; }

    public DeviceToken touch(Instant when) {
        return new DeviceToken(userId, platform, token, tokenHash, createdAt, when, enabled, deviceInfo);
    }

    public DeviceToken disable() {
        return new DeviceToken(userId, platform, token, tokenHash, createdAt, lastUsedAt, false, deviceInfo);
    }
}
