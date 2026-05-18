package com.ones.api.application.auth;

import java.time.Instant;
import java.util.Optional;

public interface RefreshTokensRepository {

    Optional<StoredRefreshToken> findByTokenHash(String tokenHash);

    void storeNew(StoredRefreshToken token);

    void rotateSingleUse(String oldTokenHash, StoredRefreshToken newToken, Instant rotatedAt);

    void revoke(String tokenHash, Instant revokedAt);

    record StoredRefreshToken(
            String tokenHash,
            String userId,
            String deviceId,
            Instant createdAt,
            Instant expiresAt,
            Instant revokedAt,
            Instant rotatedAt
    ) {
        public boolean isExpired(Instant now) {
            return expiresAt != null && expiresAt.isBefore(now);
        }

        public boolean isRevoked() {
            return revokedAt != null;
        }

        public boolean isRotated() {
            return rotatedAt != null;
        }
    }
}
