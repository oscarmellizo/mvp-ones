package com.ones.api.adapters.inbound.rest.internal;

import java.time.Instant;
import java.util.UUID;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.adapters.inbound.rest.notifications.NotificationResponse;
import com.ones.api.application.notifications.ports.NotificationsRepository;
import com.ones.api.domain.notifications.Notification;

@RestController
@RequestMapping("/internal/notifications")
public class InternalNotificationsController {

    private final NotificationsRepository repository;

    public InternalNotificationsController(NotificationsRepository repository) {
        this.repository = repository;
    }

    public record SeedNotificationRequest(
            String userId,
            String type,
            String title,
            String body,
            String actionType,
            String entityType,
            String entityId,
            String route,
            String priority
    ) {}

    @PostMapping("/seed")
    public ResponseEntity<NotificationResponse> seed(@RequestBody SeedNotificationRequest req) {
        String userId = req != null ? trimToNull(req.userId()) : null;
        if (userId == null) {
            return ResponseEntity.badRequest().build();
        }

        String id = UUID.randomUUID().toString();
        Instant now = Instant.now();

        Notification.Priority prio = parsePriority(req != null ? req.priority() : null);
        String type = defaultIfBlank(req != null ? req.type() : null, "system");

        Notification n = new Notification(
                userId,
                id,
                type,
                defaultIfBlank(req != null ? req.title() : null, null),
                defaultIfBlank(req != null ? req.body() : null, null),
                now,
                null,
                Notification.Status.CREATED,
                prio,
                defaultIfBlank(req != null ? req.actionType() : null, null),
                defaultIfBlank(req != null ? req.entityType() : null, null),
                defaultIfBlank(req != null ? req.entityId() : null, null),
                defaultIfBlank(req != null ? req.route() : null, null)
        );

        repository.upsert(n);
        return ResponseEntity.ok(toResponse(n));
    }

    private static String trimToNull(String s) {
        if (s == null) return null;
        String t = s.trim();
        return t.isEmpty() ? null : t;
    }

    private static String defaultIfBlank(String s, String def) {
        String t = trimToNull(s);
        return t == null ? def : t;
    }

    private static Notification.Priority parsePriority(String in) {
        String v = trimToNull(in);
        if (v == null) return Notification.Priority.MEDIUM;
        try {
            return Notification.Priority.valueOf(v.trim().toUpperCase());
        } catch (Exception ignored) {
            return Notification.Priority.MEDIUM;
        }
    }

    private static NotificationResponse toResponse(Notification n) {
        return new NotificationResponse(
                n.getId(),
                n.getType(),
                n.getTitle(),
                n.getBody(),
                n.getCreatedAt(),
                n.getReadAt(),
                n.getStatus() != null ? n.getStatus().name() : null,
                n.getPriority() != null ? n.getPriority().name() : null,
                n.getActionType(),
                n.getEntityType(),
                n.getEntityId(),
                n.getRoute()
        );
    }
}
