package com.ones.api.adapters.inbound.rest.events;

import jakarta.validation.constraints.NotBlank;

public record SetEventCoverRequest(
        @NotBlank String source, // "upload" | "photo" | "ai" (ai not handled here)
        String uploadKey,
        String photoId,
        String coverId
) {}
