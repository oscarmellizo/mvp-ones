package com.ones.api.adapters.inbound.rest.internal;

import java.time.Instant;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.push.PushDeliveryService;
import com.ones.api.domain.notifications.Notification;

@RestController
@RequestMapping("/internal/push")
public class InternalPushController {

    private final PushDeliveryService deliveryService;

    public InternalPushController(PushDeliveryService deliveryService) {
        this.deliveryService = deliveryService;
    }

    public record TestPushRequest(
            String userId,
            String title,
            String body,
            String type,
            String entityType,
            String entityId,
            String route
    ) {}

    public record TestPushResponse(int attempted, int success, int invalid, int failed) {}

    @PostMapping("/test")
    public ResponseEntity<TestPushResponse> test(@RequestBody TestPushRequest req) {
        String userId = req != null && req.userId() != null ? req.userId().trim() : null;
        if (userId == null || userId.isBlank()) {
            return ResponseEntity.badRequest().build();
        }

        String id = UUID.randomUUID().toString();
        Instant now = Instant.now();
        String type = req != null && req.type() != null && !req.type().isBlank() ? req.type().trim() : "system";

        Notification n = new Notification(
                userId,
                id,
                type,
                req != null ? req.title() : null,
                req != null ? req.body() : null,
                now,
                null,
                Notification.Status.CREATED,
                Notification.Priority.MEDIUM,
                null,
                req != null ? req.entityType() : null,
                req != null ? req.entityId() : null,
                req != null ? req.route() : null
        );

        PushDeliveryService.Result r = deliveryService.deliver(n);
        return ResponseEntity.ok(new TestPushResponse(r.attempted(), r.success(), r.invalid(), r.failed()));
    }
}
