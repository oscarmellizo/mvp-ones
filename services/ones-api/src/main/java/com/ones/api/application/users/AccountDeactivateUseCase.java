package com.ones.api.application.users;

import java.time.Clock;
import java.time.Instant;
import java.util.Optional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.subscriptions.CancelRecurringSubscriptionService;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

public class AccountDeactivateUseCase {

    private static final Logger log = LoggerFactory.getLogger(AccountDeactivateUseCase.class);

    private final UsersRepository usersRepository;
    private final Clock clock;

    private final CancelRecurringSubscriptionService cancelSubscriptions;

    public AccountDeactivateUseCase(UsersRepository usersRepository, Clock clock,
                                    CancelRecurringSubscriptionService cancelSubscriptions) {
        this.usersRepository = usersRepository;
        this.clock = clock;
        this.cancelSubscriptions = cancelSubscriptions;
    }

    /**
     * Desactiva una cuenta ACTIVE. Si ya está DISABLED la devuelve tal cual (idempotente).
     * Devuelve vacío si no existe o si está CLOSING/CLOSED/DELETED: una cuenta cerrada no vuelve a DISABLED.
     * Cancela antes la suscripción recurrente de Mercado Pago; si falla lanza
     * {@link com.ones.api.application.subscriptions.SubscriptionCancellationException} y no cambia nada.
     */
    public Optional<User> execute(String userId) {
        if (userId == null || userId.isBlank()) return Optional.empty();
        for (int attempt = 0; attempt < 2; attempt++) {
            Optional<User> existing = usersRepository.findById(userId);
            if (existing.isEmpty()) return Optional.empty();
            User u = existing.get();
            if (u.isClosedOrDeleted()) return Optional.empty();
            // Antes de deshabilitar se deja de cobrar: si Mercado Pago falla, se lanza y la cuenta no cambia,
            // para que la persona reintente (no se desactiva mientras se le sigue cobrando).
            cancelSubscriptions.cancelFor(userId);
            if (User.STATUS_DISABLED.equalsIgnoreCase(u.getStatus())) return Optional.of(u);
            Instant now = Instant.now(clock);
            User updated = u.withStatus(User.STATUS_DISABLED, now, u.getReactivatedAt(), now);
            // Condicional al estado leído: si la tarea diaria o un login lo cambió entre medio, se relee.
            if (usersRepository.upsertIfStatus(updated, u.getStatus())) {
                log.info("[AccountDeactivate] userId={} disabledAt={}", userId, now);
                return Optional.of(updated);
            }
        }
        throw new IllegalStateException("No se pudo desactivar userId=" + userId + ": la cuenta cambió en paralelo");
    }
}
