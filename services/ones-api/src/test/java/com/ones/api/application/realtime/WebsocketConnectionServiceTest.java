package com.ones.api.application.realtime;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.ones.api.application.realtime.ports.RealtimeSessionTokensRepository;

public class WebsocketConnectionServiceTest {

    private SessionValidationService sessionService;
    private RealtimeSessionTokensRepository sessionTokensRepository;
    private WebsocketConnectionService service;

    @BeforeEach
    void setUp() {
        sessionService = mock(SessionValidationService.class);
        sessionTokensRepository = mock(RealtimeSessionTokensRepository.class);
        service = new WebsocketConnectionService(sessionService, sessionTokensRepository);
    }

    @Test
    void connect_validToken_registersAndConsumesToken() {
        when(sessionService.validateAndResolveUserId("tok")).thenReturn(Optional.of("user-1"));

        Optional<String> userId = service.connect("conn-1", "tok");
        assertTrue(userId.isPresent());
        assertEquals("user-1", userId.get());
        verify(sessionService, times(1)).registerConnection("conn-1", "user-1");
        verify(sessionTokensRepository, times(1)).deleteByToken("tok");
    }

    @Test
    void connect_invalidToken_returnsEmpty() {
        when(sessionService.validateAndResolveUserId("bad")).thenReturn(Optional.empty());
        Optional<String> userId = service.connect("conn-1", "bad");
        assertTrue(userId.isEmpty());
        verify(sessionService, never()).registerConnection(anyString(), anyString());
        verify(sessionTokensRepository, never()).deleteByToken(anyString());
    }

    @Test
    void disconnect_callsUnregister() {
        service.disconnect("conn-1");
        verify(sessionService, times(1)).unregisterConnection("conn-1");
    }
}
