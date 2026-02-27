package com.ones.api.application.users;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class UpdateUserPreferencesUseCase {

    private final UsersRepository usersRepository;
    private final Clock clock;

    public UpdateUserPreferencesUseCase(UsersRepository usersRepository, Clock clock) {
        this.usersRepository = usersRepository;
        this.clock = clock;
    }

    public Optional<User> execute(String userId, String preferredName) {
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
                            existing.getCreatedAt(),
                            now
                    );
                    usersRepository.upsert(updated);
                    return updated;
                });
    }
}
