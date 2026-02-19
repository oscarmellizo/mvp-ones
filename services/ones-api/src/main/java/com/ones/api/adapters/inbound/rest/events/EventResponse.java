package com.ones.api.adapters.inbound.rest.events;

import java.time.Instant;

public record EventResponse(
        String id,
        String ownerId,
        Instant createdAt,
        String title,
        String eventTypeId,
        String location,
        Instant startAt,
        Instant endAt
) {
}
