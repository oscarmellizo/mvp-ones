package com.ones.api.application.users.lifecycle;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.concurrent.atomic.AtomicInteger;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.Gauge;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.subscriptions.CancelRecurringSubscriptionService;
import com.ones.api.application.users.AccountAccessService;
import com.ones.api.application.users.email.AccountEmailService;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

/** Cierra las cuentas deshabilitadas hace más de la ventana: exporta fotos, envía el correo y pasa a CLOSED. */
public class CloseExpiredAccountsUseCase {

    private static final Logger log = LoggerFactory.getLogger(CloseExpiredAccountsUseCase.class);
    private static final SecureRandom RANDOM = new SecureRandom();

    /** Vigencia del enlace de descarga enviado en el correo de cierre. */
    public static final Duration LINK_TTL = Duration.ofDays(8);

    /** Tras este tiempo un reclamo CLOSING se considera abandonado (tarea caída) y otra corrida lo retoma. */
    public static final Duration CLAIM_LEASE = Duration.ofHours(6);

    /** Margen tras la ventana a partir del cual una cuenta sin cerrar se considera atrasada (día 31). */
    static final Duration OVERDUE_MARGIN = Duration.ofDays(1);

    private final UsersRepository usersRepository;
    private final PhotosExportService photosExportService;
    private final AccountEmailService accountEmailService;
    private final AccountAccessService accountAccessService;
    private final CancelRecurringSubscriptionService cancelSubscriptions;
    private final Clock clock;
    private final Duration window;
    private final String base;
    private final Counter closedCounter;
    private final Counter failedCounter;
    private final AtomicInteger overdue = new AtomicInteger();

    public CloseExpiredAccountsUseCase(UsersRepository usersRepository, PhotosExportService photosExportService,
                                       AccountEmailService accountEmailService, AccountAccessService accountAccessService,
                                       CancelRecurringSubscriptionService cancelSubscriptions, Clock clock, Duration window,
                                       String apiPublicBaseUrl, MeterRegistry meterRegistry) {
        this.usersRepository = usersRepository;
        this.photosExportService = photosExportService;
        this.accountEmailService = accountEmailService;
        this.accountAccessService = accountAccessService;
        this.cancelSubscriptions = cancelSubscriptions;
        this.clock = clock;
        this.window = window;
        // Sin "/" final para no generar "//" al armar el enlace.
        String b = apiPublicBaseUrl == null ? "" : apiPublicBaseUrl.trim();
        while (b.endsWith("/")) b = b.substring(0, b.length() - 1);
        this.base = b;
        this.closedCounter = Counter.builder("ones.account.lifecycle.closed").tag("phase", "close").register(meterRegistry);
        this.failedCounter = Counter.builder("ones.account.lifecycle.failed").tag("phase", "close").register(meterRegistry);
        Gauge.builder("ones.account.lifecycle.overdue", overdue, AtomicInteger::get).tag("phase", "close")
                .description("Cuentas DISABLED hace más de 31 días que esta corrida no pudo cerrar")
                .register(meterRegistry);
    }

    /** @return cantidad de cuentas cerradas en esta corrida. */
    public int execute() {
        Instant now = Instant.now(clock);
        int closed = 0;
        List<String> overdueIds = new ArrayList<>();
        for (User u : usersRepository.findByStatusIn(Set.of(User.STATUS_DISABLED, User.STATUS_CLOSING))) {
            if (!claim(u, now)) continue;
            User claimed = u.withClosing(now);
            boolean ok = false;
            try {
                ok = close(claimed, now);
                if (!ok) revert(claimed, now);
            } catch (Exception e) {
                log.warn("[CloseExpiredAccounts] userId={} falló el cierre; vuelve a DISABLED para reintentar", u.getUserId(), e);
                revert(claimed, now);
            }
            if (ok) {
                closed++;
                closedCounter.increment();
            } else {
                failedCounter.increment();
                if (u.getDisabledAt() != null && now.isAfter(u.getDisabledAt().plus(window).plus(OVERDUE_MARGIN))) {
                    overdueIds.add(u.getUserId());
                }
            }
        }
        overdue.set(overdueIds.size());
        if (!overdueIds.isEmpty()) {
            // Este texto lo cuenta un filtro de métricas de CloudWatch que dispara una alarma.
            log.warn("[AccountLifecycle] ACCOUNT_LIFECYCLE_OVERDUE phase=close count={} userIds={}", overdueIds.size(), overdueIds);
        }
        return closed;
    }

    /**
     * Reclama la cuenta con una escritura condicional para que dos corridas (en tareas distintas) no la cierren
     * a la vez: DISABLED vencida → CLOSING, o CLOSING abandonada hace más de {@link #CLAIM_LEASE} → CLOSING nuevo.
     */
    private boolean claim(User u, Instant now) {
        String status = u.getStatus() == null ? "" : u.getStatus().toUpperCase();
        if (User.STATUS_DISABLED.equals(status)) {
            if (u.getDisabledAt() == null || !now.isAfter(u.getDisabledAt().plus(window))) return false;
            return usersRepository.upsertIfStatus(u.withClosing(now), u.getStatus());
        }
        if (User.STATUS_CLOSING.equals(status)) {
            if (u.getClosingAt() != null && !now.isAfter(u.getClosingAt().plus(CLAIM_LEASE))) return false;
            log.warn("[CloseExpiredAccounts] userId={} quedó en CLOSING desde {}; se reclama de nuevo", u.getUserId(), u.getClosingAt());
            return usersRepository.upsertIfClosing(u.withClosing(now), u.getClosingAt());
        }
        return false;
    }

    /** @return true si quedó CLOSED; false si debe volver a DISABLED para reintentar. */
    private boolean close(User u, Instant now) {
        Optional<String> exportKey = photosExportService.export(u.getUserId());
        if (exportKey.isPresent() && base.isEmpty()) {
            // Sin URL pública el enlace quedaría roto: la cuenta vuelve a DISABLED y se reintenta.
            log.error("[CloseExpiredAccounts] ones.api.public-base-url vacío; no se cierra userId={} (tiene fotos)", u.getUserId());
            return false;
        }
        // Defensivo: la suscripción se cancela al desactivar, pero si sigue activa se cancela aquí.
        // Si Mercado Pago falla, lanza: no hay correo y la cuenta vuelve a DISABLED para reintentar.
        cancelSubscriptions.cancelFor(u.getUserId());
        String token = randomToken();
        String url = exportKey.map(k -> base + "/v1/account-exports/" + u.getUserId() + "." + token).orElse(null);
        Instant linkExpiresAt = now.plus(LINK_TTL);
        // El correo va antes de persistir CLOSED: si falla, la próxima corrida lo reintenta.
        if (!accountEmailService.sendClosureEmail(u, url, linkExpiresAt)) return false;
        if (!usersRepository.upsertIfClosing(u.withLifecycle(User.STATUS_CLOSED, now, token, exportKey.orElse(null)), now)) {
            // Solo pasa si otra corrida reclamó la cuenta tras vencer el lease: ella termina el cierre.
            log.warn("[CloseExpiredAccounts] userId={} perdió el reclamo antes de guardar CLOSED", u.getUserId());
            return true;
        }
        accountAccessService.evict(u.getUserId());
        return true;
    }

    private void revert(User claimed, Instant now) {
        try {
            if (!usersRepository.upsertIfClosing(claimed.withClosingReverted(), now)) {
                log.warn("[CloseExpiredAccounts] userId={} no se devolvió a DISABLED: el reclamo cambió", claimed.getUserId());
            }
        } catch (Exception e) {
            // Queda en CLOSING; otra corrida la reclama cuando venza el lease.
            log.warn("[CloseExpiredAccounts] userId={} no se pudo devolver a DISABLED", claimed.getUserId(), e);
        }
    }

    private static String randomToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
