package com.ones.api.application.users;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class AccountDeactivateUseCase {

    private static final Logger log = LoggerFactory.getLogger(AccountDeactivateUseCase.class);

    private final UsersRepository usersRepository;
    private final Clock clock;

    public AccountDeactivateUseCase(UsersRepository usersRepository, Clock clock) {
        this.usersRepository = usersRepository;
        this.clock = clock;
    }

    public Optional<User> execute(String userId) {
        if (userId == null || userId.isBlank()) return Optional.empty();
        Optional<User> existing = usersRepository.findById(userId);
        if (existing.isEmpty()) return Optional.empty();
        User u = existing.get();
        Instant now = Instant.now(clock);
        User updated = new User(
                u.getUserId(), u.getEmail(), u.getName(), u.getGivenName(), u.getFamilyName(), u.getPicture(),
                u.getPreferredName(), u.getProvider(), u.getLanguagePreference(), u.isTermsAccepted(),
                u.getCreatedAt(), now,
                "DISABLED", now, u.getReactivatedAt()
        );
        usersRepository.upsert(updated);
        log.info("[AccountDeactivate] userId={} disabledAt={}", userId, now);
        return Optional.of(updated);
    }
}
