package com.ones.api.adapters.inbound.rest.events;

import java.time.Instant;
import java.util.List;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CreateEventRequest(
        @NotBlank String title,
        @NotBlank String objective,
        @NotBlank String location,
        @NotNull Instant startAt,
        @NotNull Instant endAt,
        String coverReservationId,
        List<String> inviteeEmails,
        Boolean allowGuestInvites
) {
}
