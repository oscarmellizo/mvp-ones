package com.ones.api.application.users;

import java.time.Clock;
import java.time.Instant;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class EnsureUserUseCase {

    private final UsersRepository repository;
    private final Clock clock;

    public EnsureUserUseCase(UsersRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    public User execute(EnsureUserCommand command) {
        Instant now = Instant.now(clock);

        return repository.findById(command.userId())
                .map(existing -> new User(
                        existing.getUserId(),
                        coalesce(command.email(), existing.getEmail()),
                        coalesce(command.name(), existing.getName()),
                        coalesce(command.givenName(), existing.getGivenName()),
                        coalesce(command.familyName(), existing.getFamilyName()),
                        coalesce(command.picture(), existing.getPicture()),
                        existing.getProvider(),
                        existing.getCreatedAt(),
                        now
                ))
                .map(repository::upsert)
                .orElseGet(() -> {
                    User created = new User(
                            command.userId(),
                            command.email(),
                            command.name(),
                            command.givenName(),
                            command.familyName(),
                            command.picture(),
                            command.provider(),
                            now,
                            now
                    );
                    return repository.upsert(created);
                });
    }

    private static String coalesce(String a, String b) {
        return a != null ? a : b;
    }
}
