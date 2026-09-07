package com.ones.api.adapters.inbound.rest.realtime;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.realtime.ports.RealtimeSessionTokensRepository;
import com.ones.api.domain.realtime.RealtimeSessionToken;

@RestController
@RequestMapping("/v1/realtime")
public class RealtimeSessionController {

    private static final SecureRandom RNG = new SecureRandom();
    private static final Logger LOG = LoggerFactory.getLogger(RealtimeSessionController.class);
    private final RealtimeSessionTokensRepository repository;
    private final Clock clock;

    public RealtimeSessionController(RealtimeSessionTokensRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @PostMapping("/session")
    public ResponseEntity<Map<String, String>> createSession(Authentication authentication) {
        String userId = authentication != null ? authentication.getName() : null;
        if (userId == null || userId.isBlank()) {
            LOG.info("[RealtimeSessionController] createSession unauthorized: missing user");
            return ResponseEntity.status(401).build();
        }
        LOG.info("[RealtimeSessionController] createSession requested by userId={}", userId);
        byte[] rnd = new byte[24];
        RNG.nextBytes(rnd);
        String token = Base64.getUrlEncoder().withoutPadding().encodeToString(rnd);
        Instant now = Instant.now(clock);
        Instant expiresAt = now.plusSeconds(3600);
        repository.upsert(new RealtimeSessionToken(token, userId.trim(), now, expiresAt));
        LOG.info("[RealtimeSessionController] session created for userId={} tokenLen={} expiresAt={}",
                userId, token.length(), expiresAt);
        return ResponseEntity.ok(Map.of(
                "token", token,
                "expiresAt", expiresAt.toString()
        ));
    }
}
