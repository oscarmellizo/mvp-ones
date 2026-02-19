package com.ones.api.domain.events;

import java.time.Instant;
import java.util.Objects;

public class Event {

    private final String eventId;
    private final String ownerId;
    private final Instant createdAt;
    private final String title;
    private final String eventTypeId;
    private final String location;
    private final Instant startAt;
    private final Instant endAt;
    private final String coverKey;

    public Event(
            String eventId,
            String ownerId,
            Instant createdAt,
            String title,
            String eventTypeId,
            String location,
            Instant startAt,
            Instant endAt,
            String coverKey
    ) {
        this.eventId = Objects.requireNonNull(eventId);
        this.ownerId = Objects.requireNonNull(ownerId);
        this.createdAt = Objects.requireNonNull(createdAt);
        this.title = Objects.requireNonNull(title);
        this.eventTypeId = Objects.requireNonNull(eventTypeId);
        this.location = Objects.requireNonNull(location);
        this.startAt = Objects.requireNonNull(startAt);
        this.endAt = Objects.requireNonNull(endAt);
        this.coverKey = coverKey;
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

    public String getEventTypeId() {
        return eventTypeId;
    }

    public String getLocation() {
        return location;
    }

    public Instant getStartAt() {
        return startAt;
    }

    public Instant getEndAt() {
        return endAt;
    }

    public String getCoverKey() {
        return coverKey;
    }
}
