package com.ones.api.application.invitations.email;

import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.ones.api.application.events.ports.SecretsProvider;

@Component
public class InvitationActionTokenService {

    public enum Action {
        accept,
        reject
    }

    public record Decoded(String eventId, String inviteeEmail, Action action) {
    }

    private static final Base64.Encoder B64_URL = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder B64_URL_DEC = Base64.getUrlDecoder();

    private final Clock clock;
    private final SecretsProvider secretsProvider;
    private final String secretName;
    private final Duration ttl;

    private volatile byte[] cachedSecret;

    public InvitationActionTokenService(
            Clock clock,
            SecretsProvider secretsProvider,
            @Value("${ones.email.action-token.secret-name:}") String secretName,
            @Value("${ones.email.action-token.ttl-minutes:10080}") long ttlMinutes
    ) {
        this.clock = clock;
        this.secretsProvider = secretsProvider;
        this.secretName = secretName;
        this.ttl = Duration.ofMinutes(ttlMinutes);
    }

    public String create(String eventId, String inviteeEmail, Action action) {
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("Missing eventId");
        }
        if (inviteeEmail == null || inviteeEmail.isBlank()) {
            throw new IllegalArgumentException("Missing inviteeEmail");
        }
        if (action == null) {
            throw new IllegalArgumentException("Missing action");
        }

        byte[] secret = loadSecret();

        Instant exp = Instant.now(clock).plus(ttl);
        String nonce = UUID.randomUUID().toString();
        String payload = String.join("|",
                "v1",
                Long.toString(exp.getEpochSecond()),
                eventId.trim(),
                inviteeEmail.trim().toLowerCase(),
                action.name(),
                nonce
        );

        byte[] payloadBytes = payload.getBytes(StandardCharsets.UTF_8);
        String payloadB64 = B64_URL.encodeToString(payloadBytes);
        String sigB64 = B64_URL.encodeToString(hmacSha256(secret, payloadBytes));
        return payloadB64 + "." + sigB64;
    }

    public Decoded decodeAndValidate(String token) {
        if (token == null || token.isBlank()) {
            throw new IllegalArgumentException("Missing token");
        }

        byte[] secret = loadSecret();

        String[] parts = token.trim().split("\\.", 2);
        if (parts.length != 2) {
            throw new IllegalArgumentException("Invalid token");
        }

        byte[] payloadBytes;
        byte[] sigBytes;
        try {
            payloadBytes = B64_URL_DEC.decode(parts[0]);
            sigBytes = B64_URL_DEC.decode(parts[1]);
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid token");
        }

        byte[] expected = hmacSha256(secret, payloadBytes);
        if (!constantTimeEquals(expected, sigBytes)) {
            throw new IllegalArgumentException("Invalid token");
        }

        String payload = new String(payloadBytes, StandardCharsets.UTF_8);
        String[] fields = payload.split("\\|", -1);
        if (fields.length < 6) {
            throw new IllegalArgumentException("Invalid token");
        }

        if (!"v1".equals(fields[0])) {
            throw new IllegalArgumentException("Invalid token");
        }

        long exp;
        try {
            exp = Long.parseLong(fields[1]);
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid token");
        }

        Instant now = Instant.now(clock);
        if (now.getEpochSecond() > exp) {
            throw new IllegalArgumentException("Token expired");
        }

        String eventId = fields[2];
        String email = fields[3];
        Action action;
        try {
            action = Action.valueOf(fields[4]);
        } catch (Exception e) {
            throw new IllegalArgumentException("Invalid token");
        }

        if (eventId == null || eventId.isBlank() || email == null || email.isBlank()) {
            throw new IllegalArgumentException("Invalid token");
        }

        return new Decoded(eventId, email, action);
    }

    private byte[] loadSecret() {
        byte[] cached = cachedSecret;
        if (cached != null && cached.length > 0) {
            return cached;
        }

        synchronized (this) {
            if (cachedSecret != null && cachedSecret.length > 0) {
                return cachedSecret;
            }

            if (secretName == null || secretName.isBlank()) {
                throw new IllegalStateException("Missing ones.email.action-token.secret-name");
            }
            if (secretsProvider == null) {
                throw new IllegalStateException("SecretsProvider is not configured");
            }

            String secretString = secretsProvider.getSecretString(secretName.trim());
            if (secretString == null || secretString.isBlank()) {
                throw new IllegalStateException("Invitation action token secret is empty: secretName=" + secretName);
            }

            cachedSecret = secretString.getBytes(StandardCharsets.UTF_8);
            return cachedSecret;
        }
    }

    private byte[] hmacSha256(byte[] secret, byte[] data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return mac.doFinal(data);
        } catch (Exception e) {
            throw new IllegalStateException("Unable to sign token");
        }
    }

    private static boolean constantTimeEquals(byte[] a, byte[] b) {
        if (a == null || b == null) return false;
        if (a.length != b.length) return false;
        int res = 0;
        for (int i = 0; i < a.length; i++) {
            res |= (a[i] ^ b[i]);
        }
        return res == 0;
    }
}
