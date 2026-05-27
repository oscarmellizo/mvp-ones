package com.ones.api.application.events.invitelink;

import java.nio.charset.StandardCharsets;
import java.util.Base64;

import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import com.ones.api.application.events.ports.SecretsProvider;

@Component
public class EventInviteLinkTokenService {

    private static final Base64.Encoder B64_URL = Base64.getUrlEncoder().withoutPadding();

    private final SecretsProvider secretsProvider;
    private final String secretName;

    private volatile byte[] cachedSecret;

    public EventInviteLinkTokenService(
            SecretsProvider secretsProvider,
            @Value("${ones.event-invite-link.secret-name:}") String secretName
    ) {
        this.secretsProvider = secretsProvider;
        this.secretName = secretName;
    }

    public String signatureForEventId(String eventId) {
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("Missing eventId");
        }

        byte[] secret = loadSecret();
        byte[] payload = ("v1|" + eventId.trim()).getBytes(StandardCharsets.UTF_8);
        return B64_URL.encodeToString(hmacSha256(secret, payload));
    }

    public void validate(String eventId, String signature) {
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("Missing eventId");
        }
        if (signature == null || signature.isBlank()) {
            throw new IllegalArgumentException("Missing sig");
        }

        String expected = signatureForEventId(eventId);
        if (!constantTimeEquals(expected, signature.trim())) {
            throw new IllegalArgumentException("Invalid sig");
        }
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
                throw new IllegalStateException("Missing ones.event-invite-link.secret-name");
            }
            if (secretsProvider == null) {
                throw new IllegalStateException("SecretsProvider is not configured");
            }

            String secretString = secretsProvider.getSecretString(secretName.trim());
            if (secretString == null || secretString.isBlank()) {
                throw new IllegalStateException("Event invite link secret is empty: secretName=" + secretName);
            }

            cachedSecret = secretString.getBytes(StandardCharsets.UTF_8);
            return cachedSecret;
        }
    }

    private static byte[] hmacSha256(byte[] secret, byte[] data) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(secret, "HmacSHA256"));
            return mac.doFinal(data);
        } catch (Exception e) {
            throw new IllegalStateException("Unable to sign token");
        }
    }

    private static boolean constantTimeEquals(String a, String b) {
        if (a == null || b == null) return false;
        if (a.length() != b.length()) return false;
        int res = 0;
        for (int i = 0; i < a.length(); i++) {
            res |= (a.charAt(i) ^ b.charAt(i));
        }
        return res == 0;
    }
}
