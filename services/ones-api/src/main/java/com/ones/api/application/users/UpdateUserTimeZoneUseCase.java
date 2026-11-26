package com.ones.api.application.users;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneId;
import java.util.Optional;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class UpdateUserTimeZoneUseCase {
    private final UsersRepository usersRepository;
    private final Clock clock;

    public UpdateUserTimeZoneUseCase(UsersRepository usersRepository, Clock clock) {
        this.usersRepository = usersRepository;
        this.clock = clock;
    }

    public Optional<User> execute(String userId, String requestedTimeZone) {
        if (requestedTimeZone == null || requestedTimeZone.isBlank()) {
            throw new IllegalArgumentException("timeZone is required");
        }
        String normalized = requestedTimeZone.trim();
        if (!ZoneId.getAvailableZoneIds().contains(normalized)) {
            throw new IllegalArgumentException("timeZone must be a valid IANA time zone");
        }

        for (int attempt = 0; attempt < 2; attempt++) {
            Optional<User> found = usersRepository.findById(userId);
            if (found.isEmpty()) return Optional.empty();
            User existing = found.get();
            if (normalized.equals(existing.getTimeZone())) return found;
            User updated = existing.withTimeZone(normalized, Instant.now(clock));
            if (usersRepository.upsertIfStatus(updated, existing.getStatus())) {
                return Optional.of(updated);
            }
        }
        throw new IllegalStateException("Unable to update user time zone after a concurrent account update");
    }
}
