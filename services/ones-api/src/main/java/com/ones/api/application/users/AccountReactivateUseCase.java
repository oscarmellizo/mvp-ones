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
        for (int attempt = 0; attempt < 2; attempt++) {
            Optional<User> existing = usersRepository.findById(userId);
            if (existing.isEmpty()) return Optional.empty();
            User u = existing.get();
            if (u.isClosedOrDeleted()) {
                return Optional.empty(); // cuenta cerrándose, cerrada o borrada: no se puede reactivar
            }
            if (!User.STATUS_DISABLED.equalsIgnoreCase(u.getStatus())) {
                return Optional.of(u); // already active or unknown status
            }
            Instant now = Instant.now(clock);
            Instant disabledAt = u.getDisabledAt();
            if (disabledAt != null && now.isAfter(disabledAt.plus(reactivationWindow))) {
                log.info("[AccountReactivate] userId={} beyond window disabledAt={} now={}", userId, disabledAt, now);
                return Optional.empty();
            }
            // disabledAt == null: se permite reactivar de forma defensiva.
            User updated = u.withStatus(User.STATUS_ACTIVE, null, now, now);
            // Condicional: si la tarea diaria la reclamó (CLOSING) entre medio, no se reabre.
            if (usersRepository.upsertIfStatus(updated, u.getStatus())) {
                log.info("[AccountReactivate] userId={} reactivatedAt={}", userId, now);
                return Optional.of(updated);
            }
        }
        return Optional.empty();
    }
}
