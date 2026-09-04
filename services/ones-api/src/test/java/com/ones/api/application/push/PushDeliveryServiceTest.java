package com.ones.api.application.push;

import com.ones.api.application.push.ports.DeviceTokensRepository;
import com.ones.api.application.push.ports.PushGateway;
import com.ones.api.domain.notifications.Notification;
import com.ones.api.domain.push.DeviceToken;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import java.time.Instant;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

public class PushDeliveryServiceTest {

    private DeviceTokensRepository tokensRepo;
    private PushGateway gateway;
    private PushDeliveryService service;

    @BeforeEach
    void setUp() {
        tokensRepo = mock(DeviceTokensRepository.class);
        gateway = mock(PushGateway.class);
        service = new PushDeliveryService(tokensRepo, gateway, null, false);
    }

    @Test
    void deliver_countsOutcomes() throws Exception {
        String userId = "user-1";
        DeviceToken ok = new DeviceToken(userId, "android", "token-1", "h1", Instant.parse("2024-01-01T00:00:00Z"), Instant.parse("2024-01-01T00:00:00Z"), true, null);
        DeviceToken invalid = new DeviceToken(userId, "ios", "token-2", "h2", Instant.parse("2024-01-01T00:00:00Z"), Instant.parse("2024-01-01T00:00:00Z"), true, null);
        DeviceToken disabled = new DeviceToken(userId, "android", "token-3", "h3", Instant.parse("2024-01-01T00:00:00Z"), Instant.parse("2024-01-01T00:00:00Z"), false, null);
        when(tokensRepo.listByUserId(userId, 200)).thenReturn(List.of(ok, invalid, disabled));
        when(gateway.send(eq(ok), any(PushMessage.class))).thenReturn(PushGateway.Result.OK);
        when(gateway.send(eq(invalid), any(PushMessage.class))).thenReturn(PushGateway.Result.INVALID_TOKEN);

        Notification n = new Notification(userId, "n1", "invitations", "title", "body", Instant.parse("2024-01-01T00:00:00Z"), null,
                Notification.Status.CREATED, Notification.Priority.MEDIUM, "open", "event", "evt-1", "/events/evt-1");
        PushDeliveryService.Result r = service.deliver(n);

        assertEquals(2, r.attempted());
        assertEquals(1, r.success());
        assertEquals(1, r.invalid());
        assertEquals(0, r.failed());
    }

    @Test
    void deliver_ignoresMissingUser() {
        PushDeliveryService.Result r = service.deliver(null);
        assertEquals(0, r.attempted());
    }
}
