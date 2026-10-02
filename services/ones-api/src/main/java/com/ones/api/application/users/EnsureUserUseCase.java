package com.ones.api.application.users;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

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

        // Dos intentos: la escritura es condicional al estado leído; si otro proceso lo cambió, se relee.
        for (int attempt = 0; attempt < 2; attempt++) {
            Optional<User> found = repository.findById(command.userId());
            if (found.isEmpty()) return create(command, now);
            User existing = found.get();
            // Cuenta cerrándose, cerrada o borrada: no se escribe nada (ni datos personales sobre la lápida
            // ni se pierden closedAt/exportToken/exportKey).
            if (existing.isClosedOrDeleted()) return existing;
            User merged = existing.withProfile(
                    coalesce(command.email(), existing.getEmail()),
                    coalesce(command.name(), existing.getName()),
                    coalesce(command.givenName(), existing.getGivenName()),
                    coalesce(command.familyName(), existing.getFamilyName()),
                    coalesce(command.picture(), existing.getPicture()),
                    coalesce(command.languagePreference(), existing.getLanguagePreference()),
                    now);
            if (repository.upsertIfStatus(merged, existing.getStatus())) return merged;
        }
        // Perdió la carrera dos veces: se devuelve lo guardado sin escribir.
        return repository.findById(command.userId()).orElseGet(() -> create(command, now));
    }

    private User create(EnsureUserCommand command, Instant now) {
        String normalizedEmail = command.email() != null ? command.email().trim().toLowerCase() : null;
        User existingByEmail = normalizedEmail == null || normalizedEmail.isBlank()
                ? null
                : repository.findByEmail(normalizedEmail).orElse(null);

        // Solo se fusionan los usuarios stub creados por invitaciones. Fusionar una cuenta real
        // borraría su fila y dejaría huérfanos sus eventos y fotos.
        if (existingByEmail != null && !"stub".equals(existingByEmail.getProvider())) {
            throw new EmailConflictException();
        }

        Instant createdAt = existingByEmail != null ? existingByEmail.getCreatedAt() : now;
        String preferredName = existingByEmail != null && existingByEmail.getPreferredName() != null
                ? existingByEmail.getPreferredName()
                : defaultPreferredName(command.givenName(), command.name());
        String languagePref = command.languagePreference() != null ? command.languagePreference() : "es";
        String existingLanguagePref = existingByEmail != null ? existingByEmail.getLanguagePreference() : languagePref;
        boolean existingTermsAccepted = existingByEmail != null && existingByEmail.isTermsAccepted();
        // If we're creating but we already had a user by email, carry over status fields
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
                now,
                existingByEmail != null ? existingByEmail.getStatus() : null,
                existingByEmail != null ? existingByEmail.getDisabledAt() : null,
                existingByEmail != null ? existingByEmail.getReactivatedAt() : null
        );
        User upserted = repository.upsert(created);

        if (existingByEmail != null && !existingByEmail.getUserId().equals(command.userId())) {
            repository.deleteById(existingByEmail.getUserId());
        }

        return upserted;
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
