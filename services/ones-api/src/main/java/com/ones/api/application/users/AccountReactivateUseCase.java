package com.ones.api.application.users;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class AccountReactivateUseCase {

    private static final Logger log = LoggerFactory.getLogger(AccountReactivateUseCase.class);

    private final UsersRepository usersRepository;
    private final Clock clock;
    private final Duration reactivationWindow;

    public AccountReactivateUseCase(UsersRepository usersRepository, Clock clock, Duration reactivationWindow) {
        this.usersRepository = usersRepository;
        this.clock = clock;
        this.reactivationWindow = reactivationWindow != null ? reactivationWindow : Duration.ofDays(30);
    }

    public Optional<User> execute(String userId) {
        if (userId == null || userId.isBlank()) return Optional.empty();
        Optional<User> existing = usersRepository.findById(userId);
        if (existing.isEmpty()) return Optional.empty();
        User u = existing.get();
        if (!"DISABLED".equalsIgnoreCase(u.getStatus())) {
            return Optional.of(u); // already active or unknown status
        }
        Instant now = Instant.now(clock);
        Instant disabledAt = u.getDisabledAt();
        if (disabledAt == null) {
            // allow reactivation defensively
            User updated = new User(
                    u.getUserId(), u.getEmail(), u.getName(), u.getGivenName(), u.getFamilyName(), u.getPicture(),
                    u.getPreferredName(), u.getProvider(), u.getLanguagePreference(), u.isTermsAccepted(),
                    u.getCreatedAt(), now,
                    "ACTIVE", null, now
            );
            usersRepository.upsert(updated);
            log.info("[AccountReactivate] userId={} reactivatedAt={} (no disabledAt)", userId, now);
            return Optional.of(updated);
        }
        if (now.isAfter(disabledAt.plus(reactivationWindow))) {
            log.info("[AccountReactivate] userId={} beyond window disabledAt={} now={}", userId, disabledAt, now);
            return Optional.empty();
        }
        User updated = new User(
                u.getUserId(), u.getEmail(), u.getName(), u.getGivenName(), u.getFamilyName(), u.getPicture(),
                u.getPreferredName(), u.getProvider(), u.getLanguagePreference(), u.isTermsAccepted(),
                u.getCreatedAt(), now,
                "ACTIVE", null, now
        );
        usersRepository.upsert(updated);
        log.info("[AccountReactivate] userId={} reactivatedAt={}", userId, now);
        return Optional.of(updated);
    }
}
