package com.ones.api.application.push;

import com.ones.api.application.push.ports.DeviceTokensRepository;
import com.ones.api.application.push.ports.PushGateway;
import com.ones.api.domain.notifications.Notification;
import com.ones.api.domain.push.DeviceToken;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Tag;
import io.micrometer.core.instrument.Tags;

public class PushDeliveryService {

    private final DeviceTokensRepository deviceTokensRepository;
    private final PushGateway pushGateway;
    private final MeterRegistry meterRegistry;
    private final boolean autoInvalidateInvalidTokens;

    public PushDeliveryService(DeviceTokensRepository deviceTokensRepository, PushGateway pushGateway, MeterRegistry meterRegistry, boolean autoInvalidateInvalidTokens) {
        this.deviceTokensRepository = deviceTokensRepository;
        this.pushGateway = pushGateway;
        this.meterRegistry = meterRegistry;
        this.autoInvalidateInvalidTokens = autoInvalidateInvalidTokens;
    }

    public Result deliver(Notification n) {
        if (n == null || n.getUserId() == null || n.getUserId().isBlank()) return Result.empty();
        List<DeviceToken> tokens = deviceTokensRepository.listByUserId(n.getUserId(), 200);
        int attempted = 0, success = 0, invalid = 0, failed = 0;
        PushMessage msg = toPushMessage(n);
        for (DeviceToken t : tokens) {
            if (t == null || !t.isEnabled() || t.getToken() == null || t.getToken().isBlank()) continue;
            attempted++;
            try {
                PushGateway.Result r = pushGateway.send(t, msg);
                if (r == PushGateway.Result.OK) {
                    success++;
                } else if (r == PushGateway.Result.INVALID_TOKEN) {
                    invalid++;
                    if (autoInvalidateInvalidTokens) {
                        try { deviceTokensRepository.deleteByUserAndTokenHash(t.getUserId(), t.getPlatform(), t.getTokenHash()); } catch (Exception ignore) {}
                    }
                } else {
                    failed++;
                }
            } catch (Exception e) {
                failed++;
            }
        }
        // metrics
        try {
            if (meterRegistry != null) {
                String type = n.getType() != null ? n.getType() : "unknown";
                Iterable<Tag> tags = Tags.of("type", type);
                meterRegistry.counter("ones.push.attempted", tags).increment(attempted);
                meterRegistry.counter("ones.push.success", tags).increment(success);
                meterRegistry.counter("ones.push.invalid", tags).increment(invalid);
                meterRegistry.counter("ones.push.failed", tags).increment(failed);
            }
        } catch (Exception ignore) {}
        return new Result(attempted, success, invalid, failed);
    }

    private static PushMessage toPushMessage(Notification n) {
        Map<String, String> data = new HashMap<>();
        if (n.getId() != null) data.put("id", n.getId());
        if (n.getType() != null) data.put("type", n.getType());
        if (n.getEntityType() != null) data.put("entityType", n.getEntityType());
        if (n.getEntityId() != null) data.put("entityId", n.getEntityId());
        if (n.getRoute() != null) data.put("route", n.getRoute());
        return new PushMessage(n.getTitle(), n.getBody(), data);
    }

    public record Result(int attempted, int success, int invalid, int failed) {
        public static Result empty() { return new Result(0,0,0,0); }
    }
}
