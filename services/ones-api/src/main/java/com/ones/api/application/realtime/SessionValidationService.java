package com.ones.api.application.realtime;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import org.springframework.stereotype.Service;

import com.ones.api.application.realtime.ports.RealtimeConnectionsRepository;
import com.ones.api.application.realtime.ports.RealtimeSessionTokensRepository;
import com.ones.api.domain.realtime.RealtimeConnection;
import com.ones.api.domain.realtime.RealtimeSessionToken;

@Service
public class SessionValidationService {

    private final RealtimeSessionTokensRepository sessionRepo;
    private final RealtimeConnectionsRepository connectionsRepo;
    private final Clock clock;

    public SessionValidationService(
            RealtimeSessionTokensRepository sessionRepo,
            RealtimeConnectionsRepository connectionsRepo,
            Clock clock
    ) {
        this.sessionRepo = sessionRepo;
        this.connectionsRepo = connectionsRepo;
        this.clock = clock;
    }

    public Optional<String> validateAndResolveUserId(String token) {
        if (token == null || token.isBlank()) return Optional.empty();
        Optional<RealtimeSessionToken> found = sessionRepo.findByToken(token.trim());
        if (found.isEmpty()) return Optional.empty();
        RealtimeSessionToken t = found.get();
        Instant now = Instant.now(clock);
        if (t.getExpiresAt().isBefore(now)) return Optional.empty();
        return Optional.ofNullable(t.getUserId());
    }

    public RealtimeConnection registerConnection(String connectionId, String userId) {
        RealtimeConnection c = new RealtimeConnection(connectionId, userId, Instant.now(clock));
        return connectionsRepo.upsert(c);
    }

    public void unregisterConnection(String connectionId) {
        connectionsRepo.deleteByConnectionId(connectionId);
    }
}
