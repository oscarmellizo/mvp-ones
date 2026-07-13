package com.ones.api.application.users;

import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;

import com.ones.api.application.users.ports.PreferredNamesCacheRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class UpdateUserPreferencesUseCase {

    private final UsersRepository usersRepository;
    private final PreferredNamesCacheRepository preferredNamesCacheRepository;
    private final Clock clock;

    private static final Set<String> VALID_LANGUAGE_CODES = Set.of("es", "en", "pt");

    public UpdateUserPreferencesUseCase(
            UsersRepository usersRepository,
            PreferredNamesCacheRepository preferredNamesCacheRepository,
            Clock clock
    ) {
        this.usersRepository = usersRepository;
        this.preferredNamesCacheRepository = preferredNamesCacheRepository;
        this.clock = clock;
    }

    public Optional<User> execute(String userId, String preferredName, String languagePreference, Boolean termsAccepted) {
        return usersRepository.findById(userId)
                .map(existing -> {
                    Instant now = Instant.now(clock);

                    String effectiveLanguagePreference = normalizeLanguagePreference(
                            languagePreference,
                            existing.getLanguagePreference()
                    );
                    boolean effectiveTermsAccepted = termsAccepted != null
                            ? termsAccepted
                            : existing.isTermsAccepted();
                    User updated = new User(
                            existing.getUserId(),
                            existing.getEmail(),
                            existing.getName(),
                            existing.getGivenName(),
                            existing.getFamilyName(),
                            existing.getPicture(),
                            preferredName,
                            existing.getProvider(),
                            effectiveLanguagePreference,
                            effectiveTermsAccepted,
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

    private String normalizeLanguagePreference(String requested, String existing) {
        String candidate = requested;
        if (candidate == null || candidate.isBlank()) {
            candidate = existing;
        }
        if (candidate == null || candidate.isBlank()) {
            candidate = "es";
        }
        String normalized = candidate.trim().toLowerCase(Locale.ROOT);
        if (!VALID_LANGUAGE_CODES.contains(normalized)) {
            return "es";
        }
        return normalized;
    }
}
