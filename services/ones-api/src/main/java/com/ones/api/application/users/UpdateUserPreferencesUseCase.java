package com.ones.api.application.users;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Optional;

import com.ones.api.application.users.ports.PreferredNamesCacheRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class UpdateUserPreferencesUseCase {

    private final UsersRepository usersRepository;
    private final PreferredNamesCacheRepository preferredNamesCacheRepository;
    private final Clock clock;

    public UpdateUserPreferencesUseCase(
            UsersRepository usersRepository,
            PreferredNamesCacheRepository preferredNamesCacheRepository,
            Clock clock
    ) {
        this.usersRepository = usersRepository;
        this.preferredNamesCacheRepository = preferredNamesCacheRepository;
        this.clock = clock;
    }

    public Optional<User> execute(String userId, String preferredName, String languagePreference) {
        return usersRepository.findById(userId)
                .map(existing -> {
                    Instant now = Instant.now(clock);
                    User updated = new User(
                            existing.getUserId(),
                            existing.getEmail(),
                            existing.getName(),
                            existing.getGivenName(),
                            existing.getFamilyName(),
                            existing.getPicture(),
                            preferredName,
                            existing.getProvider(),
                            languagePreference,
                            existing.getCreatedAt(),
                            now
                    );
                    usersRepository.upsert(updated);

                    Instant expiresAt = now.plus(30, ChronoUnit.DAYS);
                    preferredNamesCacheRepository.put(
                            updated.getUserId(),
                            updated.getPreferredName(),
                            expiresAt,
                            now
                    );
                    return updated;
                });
    }
}
