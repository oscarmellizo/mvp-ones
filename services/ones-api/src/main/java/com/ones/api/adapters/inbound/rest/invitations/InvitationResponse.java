package com.ones.api.adapters.inbound.rest.invitations;

import java.time.Instant;

public record InvitationResponse(
        String eventId,
        String inviteeEmail,
        String inviteeUserId,
        String eventOwnerId,
        String status,
        Instant createdAt,
        Instant updatedAt,
        String eventTitle,
        String eventLocation,
        Instant eventStartAt,
        Instant eventEndAt
) {
}
