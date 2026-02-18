package com.ones.api.adapters.inbound.rest.users;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.users.EnsureUserCommand;
import com.ones.api.application.users.EnsureUserUseCase;
import com.ones.api.domain.users.User;

@RestController
@RequestMapping("/v1/users")
public class UsersController {

    private final EnsureUserUseCase ensureUserUseCase;

    public UsersController(EnsureUserUseCase ensureUserUseCase) {
        this.ensureUserUseCase = ensureUserUseCase;
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
                u.getProvider(),
                u.getCreatedAt(),
                u.getUpdatedAt()
        );
    }
}
