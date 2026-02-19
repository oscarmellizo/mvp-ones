package com.ones.api.adapters.inbound.rest.users;

import java.time.Clock;
import java.time.Instant;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.users.EnsureUserCommand;
import com.ones.api.application.users.EnsureUserUseCase;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.users.User;

@RestController
@RequestMapping("/v1/users")
public class UsersController {

    private final EnsureUserUseCase ensureUserUseCase;
    private final UsersRepository usersRepository;
    private final Clock clock;

    public UsersController(
            EnsureUserUseCase ensureUserUseCase,
            UsersRepository usersRepository,
            Clock clock
    ) {
        this.ensureUserUseCase = ensureUserUseCase;
        this.usersRepository = usersRepository;
        this.clock = clock;
    }

    @PostMapping("/ensure")
    public ResponseEntity<EnsureUserResponse> ensure(Authentication authentication) {
        String userId = authentication.getName();

        Jwt jwt = null;
        if (authentication instanceof JwtAuthenticationToken jwtAuth) {
            jwt = jwtAuth.getToken();
        }

        EnsureUserCommand cmd = new EnsureUserCommand(
                userId,
                getClaim(jwt, "email"),
                getClaim(jwt, "name"),
                getClaim(jwt, "given_name"),
                getClaim(jwt, "family_name"),
                getClaim(jwt, "picture"),
                "google"
        );

        User ensured = ensureUserUseCase.execute(cmd);
        return ResponseEntity.ok(toResponse(ensured));
    }

    @GetMapping("/me")
    public ResponseEntity<EnsureUserResponse> me(Authentication authentication) {
        String userId = authentication.getName();
        return usersRepository.findById(userId)
                .map(u -> ResponseEntity.ok(toResponse(u)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @GetMapping("/lookup")
    public ResponseEntity<UserLookupResponse> lookupByEmail(
            Authentication authentication,
            @RequestParam("email") String email
    ) {
        if (email == null || email.trim().isEmpty()) {
            return ResponseEntity.badRequest().build();
        }

        return usersRepository.findByEmail(email.trim().toLowerCase())
                .map(u -> ResponseEntity.ok(new UserLookupResponse(
                        u.getEmail(),
                        u.getPreferredName()
                )))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PutMapping("/preferences")
    public ResponseEntity<EnsureUserResponse> updatePreferences(
            Authentication authentication,
            @RequestBody UpdatePreferencesRequest request
    ) {
        String userId = authentication.getName();
        String preferredName = request != null ? request.preferredName() : null;

        return usersRepository.findById(userId)
                .map(existing -> {
                    Instant now = Instant.now(clock);
                    User updated = new User(
                            existing.getUserId(),
                            existing.getEmail(),
                            existing.getName(),
                            existing.getGivenName(),
                            existing.getFamilyName(),
                            existing.getPicture(),
                            preferredName,
                            existing.getProvider(),
                            existing.getCreatedAt(),
                            now
                    );
                    usersRepository.upsert(updated);
                    return ResponseEntity.ok(toResponse(updated));
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    private static String getClaim(Jwt jwt, String name) {
        if (jwt == null) {
            return null;
        }
        Object value = jwt.getClaims().get(name);
        return value != null ? value.toString() : null;
    }

    private static EnsureUserResponse toResponse(User u) {
        return new EnsureUserResponse(
                u.getUserId(),
                u.getEmail(),
                u.getName(),
                u.getGivenName(),
                u.getFamilyName(),
                u.getPicture(),
                u.getPreferredName(),
                u.getProvider(),
                u.getCreatedAt(),
                u.getUpdatedAt()
        );
    }
}

record UpdatePreferencesRequest(String preferredName) {
}

record UserLookupResponse(String email, String preferredName) {
}
