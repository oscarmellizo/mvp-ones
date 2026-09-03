package com.ones.api.adapters.inbound.rest.realtime;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;

import com.ones.api.application.realtime.ports.RealtimeSessionTokensRepository;
import com.ones.api.domain.realtime.RealtimeSessionToken;

public class RealtimeSessionControllerTest {

    private RealtimeSessionTokensRepository repository;
    private Clock clock;
    private RealtimeSessionController controller;

    @BeforeEach
    void setUp() {
        repository = mock(RealtimeSessionTokensRepository.class);
        clock = Clock.fixed(Instant.parse("2024-01-01T10:00:00Z"), ZoneOffset.UTC);
        controller = new RealtimeSessionController(repository, clock);
    }

    @Test
    void createSession_authenticated_persistsTokenWithTtlAndReturnsResponse() {
        Authentication auth = new UsernamePasswordAuthenticationToken("user-abc", null);

        ResponseEntity<Map<String, String>> resp = controller.createSession(auth);
        assertEquals(200, resp.getStatusCode().value());
        Map<String, String> body = resp.getBody();
        assertNotNull(body);
        assertNotNull(body.get("token"));
        assertNotNull(body.get("expiresAt"));
        assertTrue(body.get("token").length() > 10);
        assertEquals("2024-01-01T10:02:00Z", body.get("expiresAt"));

        ArgumentCaptor<RealtimeSessionToken> captor = ArgumentCaptor.forClass(RealtimeSessionToken.class);
        verify(repository, times(1)).upsert(captor.capture());
        RealtimeSessionToken saved = captor.getValue();
        assertEquals("user-abc", saved.getUserId());
        assertEquals(Instant.parse("2024-01-01T10:00:00Z"), saved.getCreatedAt());
        assertEquals(Instant.parse("2024-01-01T10:02:00Z"), saved.getExpiresAt());
        assertNotNull(saved.getToken());
    }

    @Test
    void createSession_unauthenticated_returns401() {
        ResponseEntity<Map<String, String>> resp = controller.createSession(null);
        assertEquals(401, resp.getStatusCode().value());
        verify(repository, never()).upsert(any());
    }
}
