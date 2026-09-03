package com.ones.api.adapters.inbound.rest.push;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.Map;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.ResponseEntity;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;

import com.ones.api.application.push.ports.DeviceTokensRepository;

public class DeviceTokensControllerTest {

    private DeviceTokensRepository repository;
    private DeviceTokensController controller;

    @BeforeEach
    void setUp() {
        repository = mock(DeviceTokensRepository.class);
        controller = new DeviceTokensController(repository);
    }

    @Test
    void upsert_validRequest_returnsHashAndStores() throws Exception {
        Authentication auth = new UsernamePasswordAuthenticationToken("user-123", null);
        String token = "raw-token-value";
        String platform = "Android";
        String expectedHash = sha256(token);

        DeviceTokensController.UpsertRequest req = new DeviceTokensController.UpsertRequest(platform, token, "Pixel 8");
        ResponseEntity<Map<String, String>> resp = controller.upsert(auth, req);

        assertEquals(200, resp.getStatusCode().value());
        var body = resp.getBody();
        assertNotNull(body);
        assertEquals(expectedHash, body.get("tokenHash"));

        verify(repository, times(1)).upsert(any());
    }

    @Test
    void upsert_missingFields_returnsBadRequest() {
        Authentication auth = new UsernamePasswordAuthenticationToken("user-123", null);

        // Missing token
        var req1 = new DeviceTokensController.UpsertRequest("android", null, null);
        assertEquals(400, controller.upsert(auth, req1).getStatusCode().value());

        // Missing platform
        var req2 = new DeviceTokensController.UpsertRequest(null, "t", null);
        assertEquals(400, controller.upsert(auth, req2).getStatusCode().value());

        // Missing auth
        assertEquals(400, controller.upsert(null, new DeviceTokensController.UpsertRequest("android", "t", null)).getStatusCode().value());

        verify(repository, never()).upsert(any());
    }

    @Test
    void delete_validRequest_deletesAndReturnsNoContent() {
        Authentication auth = new UsernamePasswordAuthenticationToken("user-123", null);
        var req = new DeviceTokensController.DeleteRequest("Android", "raw-token-value");
        var resp = controller.delete(auth, req);
        assertEquals(204, resp.getStatusCode().value());
        verify(repository, times(1)).deleteByUserAndTokenHash(eq("user-123"), eq("android"), anyString());
    }

    @Test
    void delete_missingFields_noopReturnsNoContent() {
        Authentication auth = new UsernamePasswordAuthenticationToken("user-123", null);
        var req1 = new DeviceTokensController.DeleteRequest(null, "t");
        assertEquals(204, controller.delete(auth, req1).getStatusCode().value());
        verify(repository, never()).deleteByUserAndTokenHash(any(), any(), any());
    }

    private static String sha256(String input) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        byte[] digest = md.digest(input.getBytes(StandardCharsets.UTF_8));
        StringBuilder sb = new StringBuilder();
        for (byte b : digest) sb.append(String.format("%02x", b));
        return sb.toString();
    }
}
