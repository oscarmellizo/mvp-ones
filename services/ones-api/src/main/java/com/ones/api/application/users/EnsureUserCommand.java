package com.ones.api.application.users;

public record EnsureUserCommand(
        String userId,
        String email,
        String name,
        String givenName,
        String familyName,
        String picture,
        String provider
) {
}
