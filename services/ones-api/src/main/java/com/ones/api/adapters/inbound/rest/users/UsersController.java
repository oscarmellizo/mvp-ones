package com.ones.api.adapters.inbound.rest.users;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.users.EnsureUserCommand;
import com.ones.api.application.users.EnsureUserUseCase;
import com.ones.api.application.users.GetUserByIdUseCase;
import com.ones.api.application.users.LookupUserByEmailUseCase;
import com.ones.api.application.users.UpdateUserPreferencesUseCase;
import com.ones.api.domain.users.User;

@RestController
@RequestMapping("/v1/users")
public class UsersController {

    private static final Logger log = LoggerFactory.getLogger(UsersController.class);

    private final EnsureUserUseCase ensureUserUseCase;
    private final GetUserByIdUseCase getUserByIdUseCase;
    private final LookupUserByEmailUseCase lookupUserByEmailUseCase;
    private final UpdateUserPreferencesUseCase updateUserPreferencesUseCase;

    public UsersController(
            EnsureUserUseCase ensureUserUseCase,
            GetUserByIdUseCase getUserByIdUseCase,
            LookupUserByEmailUseCase lookupUserByEmailUseCase,
            UpdateUserPreferencesUseCase updateUserPreferencesUseCase
    ) {
        this.ensureUserUseCase = ensureUserUseCase;
        this.getUserByIdUseCase = getUserByIdUseCase;
        this.lookupUserByEmailUseCase = lookupUserByEmailUseCase;
        this.updateUserPreferencesUseCase = updateUserPreferencesUseCase;
    }

    @PostMapping("/ensure")
    public ResponseEntity<EnsureUserResponse> ensure(Authentication authentication) {
        String userId = authentication.getName();

        EnsureUserCommand cmd = new EnsureUserCommand(
                userId,
                AuthClaims.getClaim(authentication, "email"),
                AuthClaims.getClaim(authentication, "name"),
                AuthClaims.getClaim(authentication, "given_name"),
                AuthClaims.getClaim(authentication, "family_name"),
                AuthClaims.getClaim(authentication, "picture"),
                "google",
                null // languagePreference will default to "es" in EnsureUserUseCase
        );

        User ensured = ensureUserUseCase.execute(cmd);
        return ResponseEntity.ok(toResponse(ensured));
    }

    @GetMapping("/me")
    public ResponseEntity<EnsureUserResponse> me(Authentication authentication) {
        String userId = authentication.getName();
        String email = AuthClaims.getClaim(authentication, "email");
        log.info("[UsersController] GET /me userId={} email={}", userId, email);
        return getUserByIdUseCase.execute(userId)
                .map(u -> { log.info("[UsersController] GET /me found user userId={}", userId); return ResponseEntity.ok(toResponse(u)); })
                .orElseGet(() -> { log.info("[UsersController] GET /me user not found userId={}", userId); return ResponseEntity.notFound().build(); });
    }

    @GetMapping("/lookup")
    public ResponseEntity<UserLookupResponse> lookupByEmail(
            Authentication authentication,
            @RequestParam("email") String email
    ) {
        if (email == null || email.trim().isEmpty()) {
            return ResponseEntity.badRequest().build();
        }

        return lookupUserByEmailUseCase.execute(email)
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
        String languagePreference = request != null ? request.languagePreference() : null;
        Boolean termsAccepted = request != null ? request.termsAccepted() : null;

        if (preferredName == null || preferredName.trim().isEmpty()) {
            throw new IllegalArgumentException("preferredName is required");
        }

        preferredName = preferredName.trim();

        return updateUserPreferencesUseCase.execute(userId, preferredName, languagePreference, termsAccepted)
                .map(updated -> ResponseEntity.ok(toResponse(updated)))
                .orElseGet(() -> ResponseEntity.notFound().build());
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
                u.getLanguagePreference(),
                u.isTermsAccepted(),
                u.getCreatedAt(),
                u.getUpdatedAt()
        );
    }
}

record UpdatePreferencesRequest(String preferredName, String languagePreference, Boolean termsAccepted) {
}

record UserLookupResponse(String email, String preferredName) {
}
