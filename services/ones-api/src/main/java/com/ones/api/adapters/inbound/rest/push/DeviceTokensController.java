package com.ones.api.adapters.inbound.rest.push;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.push.ports.DeviceTokensRepository;
import com.ones.api.domain.push.DeviceToken;

@RestController
@RequestMapping("/v1/push/device-tokens")
public class DeviceTokensController {

    private final DeviceTokensRepository repository;

    public DeviceTokensController(DeviceTokensRepository repository) {
        this.repository = repository;
    }

    public record UpsertRequest(String platform, String token, String deviceInfo) {}

    @PostMapping
    public ResponseEntity<Map<String, String>> upsert(Authentication authentication, @RequestBody UpsertRequest req) {
        String userId = authentication != null ? authentication.getName() : null;
        if (userId == null || userId.isBlank() || req == null || req.token == null || req.token.isBlank() || req.platform == null || req.platform.isBlank()) {
            return ResponseEntity.badRequest().build();
        }
        String tokenHash = sha256(req.token);
        DeviceToken dt = new DeviceToken(
                userId.trim(),
                req.platform.trim().toLowerCase(),
                req.token.trim(),
                tokenHash,
                java.time.Instant.now(),
                java.time.Instant.now(),
                true,
                req.deviceInfo
        );
        repository.upsert(dt);
        return ResponseEntity.ok(Map.of("tokenHash", tokenHash));
    }

    public record DeleteRequest(String platform, String token) {}

    @DeleteMapping
    public ResponseEntity<Void> delete(Authentication authentication, @RequestBody DeleteRequest req) {
        String userId = authentication != null ? authentication.getName() : null;
        if (userId == null || userId.isBlank() || req == null || req.token == null || req.token.isBlank() || req.platform == null || req.platform.isBlank()) {
            return ResponseEntity.noContent().build();
        }
        repository.deleteByUserAndTokenHash(userId.trim(), req.platform.trim().toLowerCase(), sha256(req.token));
        return ResponseEntity.noContent().build();
    }

    private static String sha256(String input) {
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
            StringBuilder sb = new StringBuilder();
            for (byte b : digest) sb.append(String.format("%02x", b));
            return sb.toString();
        } catch (Exception e) {
            throw new IllegalStateException("Unable to compute sha256", e);
        }
    }
}
