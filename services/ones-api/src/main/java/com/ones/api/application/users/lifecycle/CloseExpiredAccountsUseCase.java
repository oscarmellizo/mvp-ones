package com.ones.api.application.users.lifecycle;

import java.security.SecureRandom;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Base64;
import java.util.Optional;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

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

    private final UsersRepository usersRepository;
    private final PhotosExportService photosExportService;
    private final AccountEmailService accountEmailService;
    private final AccountAccessService accountAccessService;
    private final Clock clock;
    private final Duration window;
    private final String base;

    public CloseExpiredAccountsUseCase(UsersRepository usersRepository, PhotosExportService photosExportService,
                                       AccountEmailService accountEmailService, AccountAccessService accountAccessService,
                                       Clock clock, Duration window, String apiPublicBaseUrl) {
        this.usersRepository = usersRepository;
        this.photosExportService = photosExportService;
        this.accountEmailService = accountEmailService;
        this.accountAccessService = accountAccessService;
        this.clock = clock;
        this.window = window;
        // Sin "/" final para no generar "//" al armar el enlace.
        String b = apiPublicBaseUrl == null ? "" : apiPublicBaseUrl.trim();
        while (b.endsWith("/")) b = b.substring(0, b.length() - 1);
        this.base = b;
    }

    /** @return cantidad de cuentas cerradas en esta corrida. */
    public int execute() {
        Instant now = Instant.now(clock);
        int closed = 0;
        for (User u : usersRepository.findByStatusIn(Set.of(User.STATUS_DISABLED))) {
            if (u.getDisabledAt() == null || !now.isAfter(u.getDisabledAt().plus(window))) continue;
            try {
                Optional<String> exportKey = photosExportService.export(u.getUserId());
                if (exportKey.isPresent() && base.isEmpty()) {
                    // Sin URL pública el enlace quedaría roto: la cuenta sigue DISABLED y se reintenta.
                    log.error("[CloseExpiredAccounts] ones.api.public-base-url vacío; no se cierra userId={} (tiene fotos)", u.getUserId());
                    continue;
                }
                String token = randomToken();
                String url = exportKey.map(k -> base + "/v1/account-exports/" + u.getUserId() + "." + token).orElse(null);
                Instant linkExpiresAt = now.plus(LINK_TTL);
                // El correo va antes de persistir CLOSED: si falla, la próxima corrida lo reintenta.
                if (!accountEmailService.sendClosureEmail(u, url, linkExpiresAt)) continue;
                usersRepository.upsert(u.withLifecycle(User.STATUS_CLOSED, now, token, exportKey.orElse(null)));
                accountAccessService.evict(u.getUserId());
                closed++;
            } catch (Exception e) {
                log.warn("[CloseExpiredAccounts] userId={} err={}", u.getUserId(), e.toString());
            }
        }
        return closed;
    }

    private static String randomToken() {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }
}
