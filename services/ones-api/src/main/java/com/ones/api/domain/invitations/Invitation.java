package com.ones.api.domain.invitations;

import java.time.Instant;
import java.util.Objects;

public class Invitation {

    public enum Status {
        invited,
        accepted,
        rejected
    }

    private final String eventId;
    private final String inviteeEmail;
    private final String inviteeUserId;
    private final String eventOwnerId;
    private final Status status;
    private final Instant createdAt;
    private final Instant updatedAt;

    private final String eventTitle;
    private final String eventLocation;
    private final Instant eventStartAt;
    private final Instant eventEndAt;

    public Invitation(
            String eventId,
            String inviteeEmail,
            String inviteeUserId,
            String eventOwnerId,
            Status status,
            Instant createdAt,
            Instant updatedAt,
            String eventTitle,
            String eventLocation,
            Instant eventStartAt,
            Instant eventEndAt
    ) {
        this.eventId = Objects.requireNonNull(eventId);
        this.inviteeEmail = Objects.requireNonNull(inviteeEmail);
        this.inviteeUserId = inviteeUserId;
        this.eventOwnerId = eventOwnerId;
        this.status = Objects.requireNonNull(status);
        this.createdAt = Objects.requireNonNull(createdAt);
        this.updatedAt = Objects.requireNonNull(updatedAt);
        this.eventTitle = Objects.requireNonNull(eventTitle);
        this.eventLocation = eventLocation;
        this.eventStartAt = Objects.requireNonNull(eventStartAt);
        this.eventEndAt = Objects.requireNonNull(eventEndAt);
    }

    public String getEventId() {
        return eventId;
    }

    public String getInviteeEmail() {
        return inviteeEmail;
    }

    public String getInviteeUserId() {
        return inviteeUserId;
    }

    public String getEventOwnerId() {
        return eventOwnerId;
    }

    public Status getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public String getEventTitle() {
        return eventTitle;
    }

    public String getEventLocation() {
        return eventLocation;
    }

    public Instant getEventStartAt() {
        return eventStartAt;
    }

    public Instant getEventEndAt() {
        return eventEndAt;
    }
}
