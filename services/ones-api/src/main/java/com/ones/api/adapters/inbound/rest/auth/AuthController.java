package com.ones.api.adapters.inbound.rest.auth;

import com.ones.api.application.auth.AuthService;
import com.ones.api.application.auth.AuthService.SessionResponse;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.ResponseEntity;

@RestController
@RequestMapping("/v1/auth")
public class AuthController {

    private final AuthService authService;

    public AuthController(AuthService authService) {
        this.authService = authService;
    }

    @PostMapping("/session")
    public SessionResponseBody createSession(@RequestBody CreateSessionRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Missing request");
        }
        SessionResponse session = authService.createSessionFromGoogleIdToken(
                request.googleIdToken(),
                request.deviceId()
        );
        return new SessionResponseBody(
                session.accessToken(),
                session.accessExpiresAt().toString(),
                session.refreshToken(),
                session.refreshExpiresAt().toString()
        );
    }

    @PostMapping("/refresh")
    public SessionResponseBody refresh(@RequestBody RefreshRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Missing request");
        }
        SessionResponse session = authService.refreshSession(request.refreshToken(), request.deviceId());
        return new SessionResponseBody(
                session.accessToken(),
                session.accessExpiresAt().toString(),
                session.refreshToken(),
                session.refreshExpiresAt().toString()
        );
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(@RequestBody LogoutRequest request) {
        if (request == null) {
            throw new IllegalArgumentException("Missing request");
        }
        authService.logout(request.refreshToken());
        return ResponseEntity.noContent().build();
    }
}

record CreateSessionRequest(String googleIdToken, String deviceId) {
}

record RefreshRequest(String refreshToken, String deviceId) {
}

record LogoutRequest(String refreshToken) {
}

record SessionResponseBody(String accessToken, String accessExpiresAt, String refreshToken, String refreshExpiresAt) {
}
