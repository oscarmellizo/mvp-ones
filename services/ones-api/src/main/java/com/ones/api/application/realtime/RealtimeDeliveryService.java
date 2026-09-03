package com.ones.api.application.realtime;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Objects;

import com.ones.api.application.realtime.ports.RealtimeConnectionsRepository;
import com.ones.api.domain.realtime.RealtimeConnection;

import software.amazon.awssdk.core.SdkBytes;
import software.amazon.awssdk.services.apigatewaymanagementapi.ApiGatewayManagementApiClient;
import software.amazon.awssdk.services.apigatewaymanagementapi.model.GoneException;
import software.amazon.awssdk.services.apigatewaymanagementapi.model.PostToConnectionRequest;

public class RealtimeDeliveryService {

    private final RealtimeConnectionsRepository connectionsRepository;

    public RealtimeDeliveryService(RealtimeConnectionsRepository connectionsRepository) {
        this.connectionsRepository = connectionsRepository;
    }

    public DeliveryResult deliverTextToUser(String userId, String message, ApiGatewayManagementApiClient mgmt) {
        Objects.requireNonNull(mgmt, "ApiGatewayManagementApiClient required");
        if (userId == null || userId.isBlank()) return DeliveryResult.empty();
        if (message == null) message = "";
        byte[] data = message.getBytes(StandardCharsets.UTF_8);
        return deliverToUser(userId, data, mgmt);
    }

    public DeliveryResult deliverToUser(String userId, byte[] data, ApiGatewayManagementApiClient mgmt) {
        Objects.requireNonNull(mgmt, "ApiGatewayManagementApiClient required");
        if (userId == null || userId.isBlank()) return DeliveryResult.empty();
        List<RealtimeConnection> conns = connectionsRepository.listByUserId(userId.trim(), 200);
        int attempted = 0;
        int success = 0;
        int removed = 0;
        int failed = 0;
        SdkBytes payload = SdkBytes.fromByteArray(data != null ? data : new byte[0]);
        for (RealtimeConnection c : conns) {
            attempted++;
            try {
                mgmt.postToConnection(PostToConnectionRequest.builder()
                        .connectionId(c.getConnectionId())
                        .data(payload)
                        .build());
                success++;
            } catch (GoneException ge) {
                // conexión inválida, eliminar de la tabla
                connectionsRepository.deleteByConnectionId(c.getConnectionId());
                removed++;
            } catch (Exception e) {
                failed++;
            }
        }
        return new DeliveryResult(attempted, success, removed, failed);
    }

    public static class DeliveryResult {
        private final int attempted;
        private final int success;
        private final int removed;
        private final int failed;

        public DeliveryResult(int attempted, int success, int removed, int failed) {
            this.attempted = attempted;
            this.success = success;
            this.removed = removed;
            this.failed = failed;
        }

        public static DeliveryResult empty() { return new DeliveryResult(0,0,0,0); }
        public int getAttempted() { return attempted; }
        public int getSuccess() { return success; }
        public int getRemoved() { return removed; }
        public int getFailed() { return failed; }
    }
}
