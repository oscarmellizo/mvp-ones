package com.ones.api.application.collections;

import java.security.MessageDigest;
import java.security.SecureRandom;
import java.util.Base64;
import org.springframework.stereotype.Component;

@Component
public class CollectionJoinTokenService {
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final Base64.Encoder ENCODER = Base64.getUrlEncoder().withoutPadding();

    public String create() {
        byte[] token = new byte[32];
        RANDOM.nextBytes(token);
        return ENCODER.encodeToString(token);
    }

    public String hash(String token) {
        if (token == null || token.isBlank()) throw new IllegalArgumentException("QR token is required");
        try {
            return ENCODER.encodeToString(MessageDigest.getInstance("SHA-256")
                    .digest(token.getBytes(java.nio.charset.StandardCharsets.UTF_8)));
        } catch (Exception e) {
            throw new IllegalStateException("Unable to hash collection QR token", e);
        }
    }

    public boolean matches(String storedHash, String token) {
        if (storedHash == null || storedHash.isBlank() || token == null || token.isBlank()) return false;
        return MessageDigest.isEqual(
                storedHash.getBytes(java.nio.charset.StandardCharsets.US_ASCII),
                hash(token).getBytes(java.nio.charset.StandardCharsets.US_ASCII)
        );
    }
}
