package com.ones.api.adapters.inbound.rest.notifications;

import java.time.Instant;

public record NotificationResponse(
        String id,
        String type,
        String title,
        String body,
        Instant createdAt,
        Instant readAt,
        String status,
        String priority,
        String actionType,
        String entityType,
        String entityId,
        String route
) {
}
