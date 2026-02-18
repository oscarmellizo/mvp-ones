package com.ones.api.adapters.inbound.rest.users;

import java.time.Instant;

public record EnsureUserResponse(
        String userId,
        String email,
        String name,
        String givenName,
        String familyName,
        String picture,
        String provider,
        Instant createdAt,
        Instant updatedAt
) {
}
