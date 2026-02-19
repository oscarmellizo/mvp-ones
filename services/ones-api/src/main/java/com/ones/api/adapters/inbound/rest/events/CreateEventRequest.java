package com.ones.api.adapters.inbound.rest.events;

import java.time.Instant;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

public record CreateEventRequest(
        @NotBlank String title,
        @NotBlank String eventTypeId,
        @NotBlank String location,
        @NotNull Instant startAt,
        @NotNull Instant endAt
) {
}
