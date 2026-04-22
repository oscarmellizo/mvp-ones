package com.ones.api.adapters.inbound.rest.events;

import java.time.Instant;
import java.util.List;

public record EventResponse(
        String id,
        String ownerId,
        Instant createdAt,
        String title,
        String objective,
        String location,
        Instant startAt,
        Instant endAt,
        String coverKey,
        boolean allowGuestInvites,
        List<String> frameIds
) {
}
