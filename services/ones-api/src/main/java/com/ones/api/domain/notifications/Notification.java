package com.ones.api.domain.notifications;

import java.time.Instant;
import java.util.Objects;

public class Notification {

    public enum Status {
        CREATED,
        SENT,
        DELIVERED,
        READ,
        FAILED,
        CANCELLED
    }

    public enum Priority {
        HIGH,
        MEDIUM,
        LOW
    }

    private final String userId;
    private final String id;
    private final String type;
    private final String title;
    private final String body;
    private final Instant createdAt;
    private final Instant readAt; // nullable
    private final Status status;
    private final Priority priority;
    private final String actionType;
    private final String entityType;
    private final String entityId;
    private final String route;

    public Notification(
            String userId,
            String id,
            String type,
            String title,
            String body,
            Instant createdAt,
            Instant readAt,
            Status status,
            Priority priority,
            String actionType,
            String entityType,
            String entityId,
            String route
    ) {
        this.userId = Objects.requireNonNull(userId);
        this.id = Objects.requireNonNull(id);
        this.type = Objects.requireNonNull(type);
        this.title = title;
        this.body = body;
        this.createdAt = Objects.requireNonNull(createdAt);
        this.readAt = readAt;
        this.status = status == null ? Status.CREATED : status;
        this.priority = priority == null ? Priority.MEDIUM : priority;
        this.actionType = actionType;
        this.entityType = entityType;
        this.entityId = entityId;
        this.route = route;
    }

    public String getUserId() { return userId; }
    public String getId() { return id; }
    public String getType() { return type; }
    public String getTitle() { return title; }
    public String getBody() { return body; }
    public Instant getCreatedAt() { return createdAt; }
    public Instant getReadAt() { return readAt; }
    public Status getStatus() { return status; }
    public Priority getPriority() { return priority; }
    public String getActionType() { return actionType; }
    public String getEntityType() { return entityType; }
    public String getEntityId() { return entityId; }
    public String getRoute() { return route; }

    public Notification markRead(Instant when) {
        return new Notification(
                userId, id, type, title, body, createdAt,
                when, Status.READ, priority, actionType, entityType, entityId, route
        );
    }
}
