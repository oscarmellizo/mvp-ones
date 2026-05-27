package com.ones.api.domain.events;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

public class Event {

    private final String eventId;
    private final String ownerId;
    private final Instant createdAt;
    private final String title;
    private final String objective;
    private final String location;
    private final Instant startAt;
    private final Instant endAt;
    private final String coverKey;
    private final boolean allowGuestInvites;
    private final boolean inviteLinkEnabled;
    private final List<String> frameIds;

    public Event(
            String eventId,
            String ownerId,
            Instant createdAt,
            String title,
            String objective,
            String location,
            Instant startAt,
            Instant endAt,
            String coverKey,
            boolean allowGuestInvites,
            boolean inviteLinkEnabled,
            List<String> frameIds
    ) {
        this.eventId = Objects.requireNonNull(eventId);
        this.ownerId = Objects.requireNonNull(ownerId);
        this.createdAt = Objects.requireNonNull(createdAt);
        this.title = Objects.requireNonNull(title);
        this.objective = Objects.requireNonNull(objective);
        this.location = Objects.requireNonNull(location);
        this.startAt = Objects.requireNonNull(startAt);
        this.endAt = Objects.requireNonNull(endAt);
        this.coverKey = coverKey;
        this.allowGuestInvites = allowGuestInvites;
        this.inviteLinkEnabled = inviteLinkEnabled;
        this.frameIds = frameIds == null ? List.of() : List.copyOf(frameIds);
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

    public String getObjective() {
        return objective;
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

    public boolean isAllowGuestInvites() {
        return allowGuestInvites;
    }

    public boolean isInviteLinkEnabled() {
        return inviteLinkEnabled;
    }

    public List<String> getFrameIds() {
        return frameIds;
    }
}
