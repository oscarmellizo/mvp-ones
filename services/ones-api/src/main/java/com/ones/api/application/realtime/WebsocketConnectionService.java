package com.ones.api.application.realtime;

import java.util.Optional;

import org.springframework.stereotype.Service;

import com.ones.api.application.realtime.ports.RealtimeSessionTokensRepository;

@Service
public class WebsocketConnectionService {

    private final SessionValidationService sessionService;
    private final RealtimeSessionTokensRepository sessionTokensRepository;

    public WebsocketConnectionService(
            SessionValidationService sessionService,
            RealtimeSessionTokensRepository sessionTokensRepository
    ) {
        this.sessionService = sessionService;
        this.sessionTokensRepository = sessionTokensRepository;
    }

    public Optional<String> connect(String connectionId, String sessionToken) {
        if (connectionId == null || connectionId.isBlank()) return Optional.empty();
        if (sessionToken == null || sessionToken.isBlank()) return Optional.empty();

        Optional<String> userId = sessionService.validateAndResolveUserId(sessionToken.trim());
        if (userId.isEmpty()) return Optional.empty();

        sessionService.registerConnection(connectionId.trim(), userId.get());
        // Consumir el token para uso one-time (defensa en profundidad)
        sessionTokensRepository.deleteByToken(sessionToken.trim());
        return userId;
    }

    public void disconnect(String connectionId) {
        if (connectionId == null || connectionId.isBlank()) return;
        sessionService.unregisterConnection(connectionId.trim());
    }
}
