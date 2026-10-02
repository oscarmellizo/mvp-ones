package com.ones.api.adapters.inbound.rest.users;

import static java.nio.charset.StandardCharsets.UTF_8;

import java.net.URI;
import java.net.URL;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Optional;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.users.lifecycle.CloseExpiredAccountsUseCase;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

/** Descarga pública del ZIP de fotos de una cuenta cerrada, protegida por un token del enlace. */
@RestController
@RequestMapping("/v1/account-exports")
public class AccountExportsController {

    private static final Duration PRESIGN_TTL = Duration.ofMinutes(5);

    private final UsersRepository usersRepository;
    private final ObjectStoragePresigner presigner;
    private final Clock clock;
    private final String exportsBucket;

    public AccountExportsController(UsersRepository usersRepository, ObjectStoragePresigner presigner, Clock clock,
                                    @Value("${ones.account.exports-bucket:}") String exportsBucket) {
        this.usersRepository = usersRepository;
        this.presigner = presigner;
        this.clock = clock;
        this.exportsBucket = exportsBucket;
    }

    @GetMapping("/{ref}")
    public ResponseEntity<Void> download(@PathVariable("ref") String ref) {
        int dot = ref.indexOf('.');
        if (dot <= 0) {
            return ResponseEntity.notFound().build();
        }
        String userId = ref.substring(0, dot);
        String token = ref.substring(dot + 1);
        Optional<User> found = usersRepository.findById(userId);
        // Todos los fallos devuelven el mismo 404 sin detalle: no se revela si la cuenta existe.
        if (found.isEmpty() || !isDownloadable(found.get(), token, Instant.now(clock))) {
            return ResponseEntity.notFound().build();
        }
        URL url = presigner.presignGet(exportsBucket, found.get().getExportKey(), PRESIGN_TTL);
        return ResponseEntity.status(HttpStatus.FOUND).location(URI.create(url.toString())).build();
    }

    private static boolean isDownloadable(User user, String token, Instant now) {
        return User.STATUS_CLOSED.equals(user.getStatus())
                && user.getExportKey() != null
                && user.getExportToken() != null
                && user.getClosedAt() != null
                // Comparación en tiempo constante para no filtrar el token por temporización.
                && MessageDigest.isEqual(user.getExportToken().getBytes(UTF_8), token.getBytes(UTF_8))
                && now.isBefore(user.getClosedAt().plus(CloseExpiredAccountsUseCase.LINK_TTL));
    }
}
