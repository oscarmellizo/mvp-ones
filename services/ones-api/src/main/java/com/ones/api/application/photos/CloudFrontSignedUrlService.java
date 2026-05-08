package com.ones.api.application.photos;

import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.PrivateKey;
import java.security.Signature;
import java.security.spec.PKCS8EncodedKeySpec;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.ports.SecretsProvider;

@Service
public class CloudFrontSignedUrlService {

    private final SecretsProvider secretsProvider;
    private final Clock clock;

    private final boolean enabled;
    private final String baseUrl;
    private final String keyPairId;
    private final String privateKeySecretName;

    private final long participantUrlTtlMinutes;
    private final long participantUrlRoundingSeconds;

    private final long socialShareTtlDays;

    private volatile PrivateKey cachedPrivateKey;

    public CloudFrontSignedUrlService(
            SecretsProvider secretsProvider,
            Clock clock,
            @Value("${ones.cdn.photos.enabled:false}") boolean enabled,
            @Value("${ones.cdn.photos.base-url:}") String baseUrl,
            @Value("${ones.cdn.photos.signing.key-pair-id:}") String keyPairId,
            @Value("${ones.cdn.photos.signing.private-key-secret-name:}") String privateKeySecretName,
            @Value("${ones.cdn.photos.url-ttl-minutes:120}") long participantUrlTtlMinutes,
            @Value("${ones.cdn.photos.url-rounding-seconds:300}") long participantUrlRoundingSeconds,
            @Value("${ones.cdn.photos.social-share-ttl-days:7}") long socialShareTtlDays
    ) {
        this.secretsProvider = secretsProvider;
        this.clock = clock;
        this.enabled = enabled;
        this.baseUrl = baseUrl;
        this.keyPairId = keyPairId;
        this.privateKeySecretName = privateKeySecretName;
        this.participantUrlTtlMinutes = participantUrlTtlMinutes;
        this.participantUrlRoundingSeconds = participantUrlRoundingSeconds;
        this.socialShareTtlDays = socialShareTtlDays;
    }

    public boolean isEnabled() {
        return enabled;
    }

    public SignedUrlResult signForParticipants(String objectKey) {
        return sign(objectKey, Duration.ofMinutes(participantUrlTtlMinutes), participantUrlRoundingSeconds);
    }

    public SignedUrlResult signForSocialShare(String objectKey) {
        return sign(objectKey, Duration.ofDays(socialShareTtlDays), 0);
    }

    private SignedUrlResult sign(String objectKey, Duration ttl, long roundingSeconds) {
        if (!enabled) {
            return new SignedUrlResult(null, null);
        }
        if (baseUrl == null || baseUrl.isBlank()) {
            throw new IllegalStateException("Missing config: ones.cdn.photos.base-url");
        }
        if (keyPairId == null || keyPairId.isBlank()) {
            throw new IllegalStateException("Missing config: ones.cdn.photos.signing.key-pair-id");
        }
        if (privateKeySecretName == null || privateKeySecretName.isBlank()) {
            throw new IllegalStateException("Missing config: ones.cdn.photos.signing.private-key-secret-name");
        }
        if (objectKey == null || objectKey.isBlank()) {
            return new SignedUrlResult(null, null);
        }

        Instant now = Instant.now(clock);
        Instant expiresAt = now.plus(ttl);
        long epochSeconds = expiresAt.getEpochSecond();

        if (roundingSeconds > 0) {
            long r = roundingSeconds;
            epochSeconds = ((epochSeconds + r - 1) / r) * r;
            expiresAt = Instant.ofEpochSecond(epochSeconds);
        }

        String normalizedKey = objectKey.trim();
        String path = encodeKeyAsPath(normalizedKey);

        String resolvedBase = baseUrl.trim();
        while (resolvedBase.endsWith("/")) {
            resolvedBase = resolvedBase.substring(0, resolvedBase.length() - 1);
        }

        String resourceUrl = resolvedBase + "/" + path;

        String signature = signCannedPolicy(resourceUrl, epochSeconds);

        String out = resourceUrl
                + "?Expires=" + epochSeconds
                + "&Signature=" + signature
                + "&Key-Pair-Id=" + urlEncodeQuery(keyPairId.trim());

        return new SignedUrlResult(out, expiresAt);
    }

    private String signCannedPolicy(String resourceUrl, long expiresEpochSeconds) {
        // Canned policy signature:
        // StringToSign = resourceUrl + "\n" + expires
        // Signature = RSA-SHA1(StringToSign)
        // Then make URL-safe base64 (CloudFront style).
        String toSign = resourceUrl + "\n" + expiresEpochSeconds;

        try {
            Signature sig = Signature.getInstance("SHA1withRSA");
            sig.initSign(loadPrivateKey());
            sig.update(toSign.getBytes(StandardCharsets.UTF_8));
            byte[] raw = sig.sign();

            String b64 = Base64.getEncoder().encodeToString(raw);
            return makeCloudFrontUrlSafe(b64);
        } catch (Exception e) {
            throw new IllegalStateException("Failed to sign CloudFront URL", e);
        }
    }

    private PrivateKey loadPrivateKey() {
        PrivateKey cached = cachedPrivateKey;
        if (cached != null) {
            return cached;
        }

        synchronized (this) {
            if (cachedPrivateKey != null) {
                return cachedPrivateKey;
            }

            String pem = secretsProvider.getSecretString(privateKeySecretName.trim());
            if (pem == null || pem.isBlank()) {
                throw new IllegalStateException("CloudFront private key secret is empty: secretName=" + privateKeySecretName);
            }

            cachedPrivateKey = parsePemPrivateKey(pem);
            return cachedPrivateKey;
        }
    }

    private static PrivateKey parsePemPrivateKey(String pem) {
        try {
            String normalized = pem
                    .replace("-----BEGIN PRIVATE KEY-----", "")
                    .replace("-----END PRIVATE KEY-----", "")
                    .replaceAll("\\s", "");

            byte[] der = Base64.getDecoder().decode(normalized);
            PKCS8EncodedKeySpec spec = new PKCS8EncodedKeySpec(der);
            KeyFactory kf = KeyFactory.getInstance("RSA");
            return kf.generatePrivate(spec);
        } catch (Exception e) {
            throw new IllegalStateException("Failed to parse CloudFront private key (expected PKCS#8 PEM)", e);
        }
    }

    private static String encodeKeyAsPath(String key) {
        // Encode each segment so slashes are preserved.
        String[] parts = key.split("/");
        StringBuilder out = new StringBuilder();
        for (int i = 0; i < parts.length; i++) {
            if (i > 0) out.append('/');
            String seg = parts[i];
            if (seg == null || seg.isEmpty()) {
                continue;
            }
            String enc = URLEncoder.encode(seg, StandardCharsets.UTF_8)
                    .replace("+", "%20");
            out.append(enc);
        }
        return out.toString();
    }

    private static String urlEncodeQuery(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8)
                .replace("+", "%20");
    }

    private static String makeCloudFrontUrlSafe(String b64) {
        // CloudFront URL-safe base64: + -> -, = -> _, / -> ~
        return b64.replace('+', '-').replace('=', '_').replace('/', '~');
    }

    public record SignedUrlResult(String url, Instant expiresAt) {
        public URI uri() {
            if (url == null || url.isBlank()) return null;
            return URI.create(url);
        }
    }
}
