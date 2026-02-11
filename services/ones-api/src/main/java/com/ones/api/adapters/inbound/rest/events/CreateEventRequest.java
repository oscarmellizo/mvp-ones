package com.ones.api.adapters.inbound.rest.events;

import jakarta.validation.constraints.NotBlank;

public record CreateEventRequest(
        @NotBlank String title
) {
}
