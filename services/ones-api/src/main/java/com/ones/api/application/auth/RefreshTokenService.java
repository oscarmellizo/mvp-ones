package com.ones.api.application.auth;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;

public class RefreshTokenService {

    private final Clock clock;
    private final SecureRandom random;
    private final Duration refreshTtl;

    public RefreshTokenService(Clock clock, Duration refreshTtl) {
        this.clock = clock;
        this.refreshTtl = refreshTtl;
        this.random = new SecureRandom();
    }

    public IssuedRefreshToken issueNew(String userId, String deviceId) {
        Instant now = Instant.now(clock);
        Instant exp = now.plus(refreshTtl);
        return issueWithExpiry(userId, deviceId, exp);
    }

    public IssuedRefreshToken rotate(String userId, String deviceId, Instant refreshExpiresAt) {
        return issueWithExpiry(userId, deviceId, refreshExpiresAt);
    }

    private IssuedRefreshToken issueWithExpiry(String userId, String deviceId, Instant exp) {
        String raw = generateTokenValue();
        String hash = sha256Hex(raw);
        Instant now = Instant.now(clock);

        return new IssuedRefreshToken(raw, hash, userId, deviceId, now, exp);
    }

    private String generateTokenValue() {
        byte[] bytes = new byte[32];
        random.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    public static String sha256Hex(String input) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            byte[] hashed = digest.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder(hashed.length * 2);
            for (byte b : hashed) {
                sb.append(Character.forDigit((b >> 4) & 0xF, 16));
                sb.append(Character.forDigit((b & 0xF), 16));
            }
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException("Failed to hash refresh token", e);
        }
    }

    public record IssuedRefreshToken(
            String token,
            String tokenHash,
            String userId,
            String deviceId,
            Instant createdAt,
            Instant expiresAt
    ) {
    }
}
