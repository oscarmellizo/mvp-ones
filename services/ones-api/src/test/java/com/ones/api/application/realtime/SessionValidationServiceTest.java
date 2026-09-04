package com.ones.api.application.realtime;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.ones.api.application.realtime.ports.RealtimeConnectionsRepository;
import com.ones.api.application.realtime.ports.RealtimeSessionTokensRepository;
import com.ones.api.domain.realtime.RealtimeConnection;
import com.ones.api.domain.realtime.RealtimeSessionToken;

public class SessionValidationServiceTest {

    private RealtimeSessionTokensRepository sessionRepo;
    private RealtimeConnectionsRepository connectionsRepo;
    private Clock clock;
    private SessionValidationService service;

    @BeforeEach
    void setUp() {
        sessionRepo = mock(RealtimeSessionTokensRepository.class);
        connectionsRepo = mock(RealtimeConnectionsRepository.class);
        clock = Clock.fixed(Instant.parse("2024-01-01T10:00:00Z"), ZoneOffset.UTC);
        service = new SessionValidationService(sessionRepo, connectionsRepo, clock);
    }

    @Test
    void validateAndResolveUserId_validToken_returnsUserId() {
        RealtimeSessionToken t = new RealtimeSessionToken("tok", "user-1", Instant.parse("2024-01-01T09:59:00Z"), Instant.parse("2024-01-01T10:02:00Z"));
        when(sessionRepo.findByToken("tok")).thenReturn(Optional.of(t));

        Optional<String> userId = service.validateAndResolveUserId("tok");
        assertTrue(userId.isPresent());
        assertEquals("user-1", userId.get());
    }

    @Test
    void validateAndResolveUserId_expiredToken_returnsEmpty() {
        RealtimeSessionToken t = new RealtimeSessionToken("tok", "user-1", Instant.parse("2024-01-01T09:59:00Z"), Instant.parse("2024-01-01T09:59:30Z"));
        when(sessionRepo.findByToken("tok")).thenReturn(Optional.of(t));

        Optional<String> userId = service.validateAndResolveUserId("tok");
        assertTrue(userId.isEmpty());
    }

    @Test
    void registerAndUnregister_callsRepo() {
        when(connectionsRepo.upsert(any())).thenAnswer(inv -> inv.getArgument(0));
        RealtimeConnection c = service.registerConnection("conn-1", "user-1");
        assertEquals("conn-1", c.getConnectionId());
        verify(connectionsRepo, times(1)).upsert(any());

        service.unregisterConnection("conn-1");
        verify(connectionsRepo, times(1)).deleteByConnectionId("conn-1");
    }
}
