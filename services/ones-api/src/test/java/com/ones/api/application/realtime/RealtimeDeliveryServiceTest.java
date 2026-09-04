package com.ones.api.application.realtime;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.ones.api.application.realtime.RealtimeDeliveryService.DeliveryResult;
import com.ones.api.application.realtime.ports.RealtimeConnectionsRepository;
import com.ones.api.domain.realtime.RealtimeConnection;

import software.amazon.awssdk.services.apigatewaymanagementapi.ApiGatewayManagementApiClient;
import software.amazon.awssdk.services.apigatewaymanagementapi.model.GoneException;
import software.amazon.awssdk.services.apigatewaymanagementapi.model.PostToConnectionRequest;
import software.amazon.awssdk.services.apigatewaymanagementapi.model.PostToConnectionResponse;

public class RealtimeDeliveryServiceTest {

    private RealtimeConnectionsRepository repo;
    private ApiGatewayManagementApiClient mgmt;
    private RealtimeDeliveryService service;

    @BeforeEach
    void setUp() {
        repo = mock(RealtimeConnectionsRepository.class);
        mgmt = mock(ApiGatewayManagementApiClient.class);
        service = new RealtimeDeliveryService(repo);
    }

    @Test
    void deliverTextToUser_noConnections_returnsEmptyResultCounts() {
        when(repo.listByUserId("user-1", 200)).thenReturn(List.of());
        DeliveryResult res = service.deliverTextToUser("user-1", "hello", mgmt);
        assertEquals(0, res.getAttempted());
        assertEquals(0, res.getSuccess());
        assertEquals(0, res.getRemoved());
        assertEquals(0, res.getFailed());
    }

    @Test
    void deliverTextToUser_successAndGone_removesGone() {
        when(repo.listByUserId("user-1", 200)).thenReturn(List.of(
            new RealtimeConnection("c-ok", "user-1", java.time.Instant.EPOCH),
            new RealtimeConnection("c-gone", "user-1", java.time.Instant.EPOCH)
        ));
        when(mgmt.postToConnection(any(PostToConnectionRequest.class))).thenReturn(PostToConnectionResponse.builder().build());
        when(mgmt.postToConnection(argThat((PostToConnectionRequest req) -> "c-gone".equals(req.connectionId()))))
            .thenThrow(GoneException.builder().build());

        DeliveryResult res = service.deliverTextToUser("user-1", "hello", mgmt);
        assertEquals(2, res.getAttempted());
        assertEquals(1, res.getSuccess());
        assertEquals(1, res.getRemoved());
        assertEquals(0, res.getFailed());
        verify(repo, times(1)).deleteByConnectionId("c-gone");
    }

    @Test
    void deliverTextToUser_otherFailure_countsFailed() {
        when(repo.listByUserId("user-1", 200)).thenReturn(List.of(
            new RealtimeConnection("c-fail", "user-1", java.time.Instant.EPOCH)
        ));
        when(mgmt.postToConnection(any(PostToConnectionRequest.class))).thenThrow(new RuntimeException("boom"));

        DeliveryResult res = service.deliverTextToUser("user-1", "hello", mgmt);
        assertEquals(1, res.getAttempted());
        assertEquals(0, res.getSuccess());
        assertEquals(0, res.getRemoved());
        assertEquals(1, res.getFailed());
    }
}
