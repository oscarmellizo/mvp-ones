package com.ones.api.adapters.inbound.rest.events;

import jakarta.validation.constraints.NotBlank;

public record GenerateEventCoverRequest(
        @NotBlank String eventName,
        @NotBlank String categoryLabel,
        @NotBlank String eventTypeLabel,
        @NotBlank String location,
        String size
) {
}
