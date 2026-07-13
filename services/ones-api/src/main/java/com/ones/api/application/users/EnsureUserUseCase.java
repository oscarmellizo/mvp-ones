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
                .map(existing -> {
                    User merged = new User(
                            existing.getUserId(),
                            coalesce(command.email(), existing.getEmail()),
                            coalesce(command.name(), existing.getName()),
                            coalesce(command.givenName(), existing.getGivenName()),
                            coalesce(command.familyName(), existing.getFamilyName()),
                            coalesce(command.picture(), existing.getPicture()),
                            existing.getPreferredName(),
                            existing.getProvider(),
                            coalesce(command.languagePreference(), existing.getLanguagePreference()),
                            existing.isTermsAccepted(),
                            existing.getCreatedAt(),
                            now
                    );
                    return repository.upsert(merged);
                })
                .orElseGet(() -> {
                    String normalizedEmail = command.email() != null ? command.email().trim().toLowerCase() : null;
                    User existingByEmail = normalizedEmail == null || normalizedEmail.isBlank()
                            ? null
                            : repository.findByEmail(normalizedEmail).orElse(null);

                    Instant createdAt = existingByEmail != null ? existingByEmail.getCreatedAt() : now;
                    String preferredName = existingByEmail != null && existingByEmail.getPreferredName() != null
                            ? existingByEmail.getPreferredName()
                            : defaultPreferredName(command.givenName(), command.name());
                    String languagePref = command.languagePreference() != null ? command.languagePreference() : "es";
                    String existingLanguagePref = existingByEmail != null ? existingByEmail.getLanguagePreference() : languagePref;
                    boolean existingTermsAccepted = existingByEmail != null && existingByEmail.isTermsAccepted();
                    User created = new User(
                            command.userId(),
                            normalizedEmail,
                            coalesce(command.name(), existingByEmail != null ? existingByEmail.getName() : null),
                            coalesce(command.givenName(), existingByEmail != null ? existingByEmail.getGivenName() : null),
                            coalesce(command.familyName(), existingByEmail != null ? existingByEmail.getFamilyName() : null),
                            coalesce(command.picture(), existingByEmail != null ? existingByEmail.getPicture() : null),
                            preferredName,
                            command.provider(),
                            existingLanguagePref,
                            existingTermsAccepted,
                            createdAt,
                            now
                    );
                    User upserted = repository.upsert(created);

                    if (existingByEmail != null && !existingByEmail.getUserId().equals(command.userId())) {
                        repository.deleteById(existingByEmail.getUserId());
                    }

                    return upserted;
                });
    }

    private static String coalesce(String a, String b) {
        return a != null ? a : b;
    }

    private static String defaultPreferredName(String givenName, String name) {
        String raw = givenName != null && !givenName.isBlank() ? givenName : name;
        if (raw == null || raw.isBlank()) {
            return "Guest";
        }
        String trimmed = raw.trim();
        int space = trimmed.indexOf(' ');
        return (space > 0 ? trimmed.substring(0, space) : trimmed);
    }
}
