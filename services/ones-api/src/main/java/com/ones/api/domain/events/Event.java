package com.ones.api.domain.events;

import java.time.Instant;
import java.util.Objects;

public class Event {

    private final String eventId;
    private final String ownerId;
    private final Instant createdAt;
    private final String title;

    public Event(String eventId, String ownerId, Instant createdAt, String title) {
        this.eventId = Objects.requireNonNull(eventId);
        this.ownerId = Objects.requireNonNull(ownerId);
        this.createdAt = Objects.requireNonNull(createdAt);
        this.title = Objects.requireNonNull(title);
    }

    public String getEventId() {
        return eventId;
    }

    public String getOwnerId() {
        return ownerId;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public String getTitle() {
        return title;
    }
}
