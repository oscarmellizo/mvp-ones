package com.ones.api.application.auth;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.HashMap;
import java.util.Map;

import com.ones.api.application.users.EnsureUserCommand;
import com.ones.api.application.users.EnsureUserUseCase;
import com.ones.api.application.auth.AccessTokenService.IssuedAccessToken;
import com.ones.api.application.auth.RefreshTokenService.IssuedRefreshToken;
import com.ones.api.application.auth.RefreshTokensRepository.StoredRefreshToken;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import io.micrometer.core.instrument.Timer;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtException;

public class AuthService {

    private final JwtDecoder googleIdTokenDecoder;
    private final EnsureUserUseCase ensureUserUseCase;
    private final AccessTokenService accessTokenService;
    private final RefreshTokenService refreshTokenService;
    private final RefreshTokensRepository refreshTokensRepository;
    private final Clock clock;
    private final Duration refreshTtl;

    private final MeterRegistry meterRegistry;

    private final Timer sessionTimer;
    private final Timer refreshTimer;
    private final Counter sessionSuccess;
    private final Counter refreshSuccess;
    private final Counter logoutCounter;

    public AuthService(
            JwtDecoder googleIdTokenDecoder,
            EnsureUserUseCase ensureUserUseCase,
            AccessTokenService accessTokenService,
            RefreshTokenService refreshTokenService,
            RefreshTokensRepository refreshTokensRepository,
            Clock clock,
            Duration refreshTtl,
            MeterRegistry meterRegistry
    ) {
        this.googleIdTokenDecoder = googleIdTokenDecoder;
        this.ensureUserUseCase = ensureUserUseCase;
        this.accessTokenService = accessTokenService;
        this.refreshTokenService = refreshTokenService;
        this.refreshTokensRepository = refreshTokensRepository;
        this.clock = clock;
        this.refreshTtl = refreshTtl;
        this.meterRegistry = meterRegistry;

        this.sessionTimer = Timer.builder("ones.auth.session")
                .publishPercentileHistogram()
                .register(meterRegistry);
        this.refreshTimer = Timer.builder("ones.auth.refresh")
                .publishPercentileHistogram()
                .register(meterRegistry);

        this.sessionSuccess = Counter.builder("ones.auth.session.success").register(meterRegistry);
        this.refreshSuccess = Counter.builder("ones.auth.refresh.success").register(meterRegistry);
        this.logoutCounter = Counter.builder("ones.auth.logout").register(meterRegistry);
    }

    public SessionResponse createSessionFromGoogleIdToken(String googleIdToken, String deviceId) {
        Timer.Sample sample = Timer.start();
        try {
            if (googleIdToken == null || googleIdToken.isBlank()) {
                throw new IllegalArgumentException("Missing googleIdToken");
            }
            if (deviceId == null || deviceId.isBlank()) {
                throw new IllegalArgumentException("Missing deviceId");
            }

            Jwt googleJwt;
            try {
                googleJwt = googleIdTokenDecoder.decode(googleIdToken.trim());
            } catch (JwtException e) {
                throw new AuthException(AuthErrorCode.INVALID_GOOGLE_TOKEN, "Invalid Google token");
            }

            String userId = googleJwt.getSubject();
            EnsureUserCommand ensureCmd = new EnsureUserCommand(
                    userId,
                    asString(googleJwt.getClaims().get("email")),
                    asString(googleJwt.getClaims().get("name")),
                    asString(googleJwt.getClaims().get("given_name")),
                    asString(googleJwt.getClaims().get("family_name")),
                    asString(googleJwt.getClaims().get("picture")),
                    "google"
            );
            ensureUserUseCase.execute(ensureCmd);

            Map<String, Object> claims = new HashMap<>();
            putIfPresent(claims, "email", googleJwt.getClaims().get("email"));
            putIfPresent(claims, "name", googleJwt.getClaims().get("name"));
            putIfPresent(claims, "given_name", googleJwt.getClaims().get("given_name"));
            putIfPresent(claims, "family_name", googleJwt.getClaims().get("family_name"));
            putIfPresent(claims, "picture", googleJwt.getClaims().get("picture"));

            IssuedAccessToken access = accessTokenService.issue(userId, claims);

            IssuedRefreshToken refresh = refreshTokenService.issueNew(userId, deviceId.trim());
            StoredRefreshToken stored = new StoredRefreshToken(
                    refresh.tokenHash(),
                    refresh.userId(),
                    refresh.deviceId(),
                    refresh.createdAt(),
                    refresh.expiresAt(),
                    null,
                    null
            );
            refreshTokensRepository.storeNew(stored);

            sessionSuccess.increment();
            return new SessionResponse(
                    access.token(),
                    access.expiresAt(),
                    refresh.token(),
                    refresh.expiresAt()
            );
        } catch (RuntimeException e) {
            Counter.builder("ones.auth.session.fail")
                    .tag("code", errorCodeFor(e))
                    .register(meterRegistry)
                    .increment();
            throw e;
        } finally {
            sample.stop(sessionTimer);
        }
    }

    public SessionResponse refreshSession(String refreshToken, String deviceId) {
        Timer.Sample sample = Timer.start();
        try {
            if (refreshToken == null || refreshToken.isBlank()) {
                throw new IllegalArgumentException("Missing refreshToken");
            }
            if (deviceId == null || deviceId.isBlank()) {
                throw new IllegalArgumentException("Missing deviceId");
            }

            String hash = RefreshTokenService.sha256Hex(refreshToken.trim());
            StoredRefreshToken stored = refreshTokensRepository.findByTokenHash(hash)
                    .orElseThrow(() -> new AuthException(AuthErrorCode.INVALID_REFRESH_TOKEN, "Invalid refresh token"));

            Instant now = Instant.now(clock);

            if (stored.isRevoked()) {
                throw new AuthException(AuthErrorCode.TOKEN_REVOKED, "Refresh token revoked");
            }
            if (stored.isRotated()) {
                throw new AuthException(AuthErrorCode.TOKEN_REUSED, "Refresh token already rotated");
            }
            if (stored.isExpired(now)) {
                throw new AuthException(AuthErrorCode.TOKEN_EXPIRED, "Refresh token expired");
            }

            if (!stored.deviceId().equals(deviceId.trim())) {
                throw new AuthException(AuthErrorCode.DEVICE_MISMATCH, "Refresh token device mismatch");
            }

            Map<String, Object> claims = Map.of();
            IssuedAccessToken access = accessTokenService.issue(stored.userId(), claims);

            Instant refreshExpiresAt = stored.expiresAt();
            if (refreshExpiresAt == null) {
                refreshExpiresAt = now.plus(refreshTtl);
            }

            IssuedRefreshToken rotated = refreshTokenService.rotate(stored.userId(), stored.deviceId(), refreshExpiresAt);
            StoredRefreshToken newStored = new StoredRefreshToken(
                    rotated.tokenHash(),
                    rotated.userId(),
                    rotated.deviceId(),
                    rotated.createdAt(),
                    rotated.expiresAt(),
                    null,
                    null
            );

            try {
                refreshTokensRepository.rotateSingleUse(stored.tokenHash(), newStored, now);
            } catch (RefreshTokenRotationRejectedException e) {
                throw new AuthException(AuthErrorCode.TOKEN_REUSED, "Refresh token already rotated");
            }

            refreshSuccess.increment();
            return new SessionResponse(
                    access.token(),
                    access.expiresAt(),
                    rotated.token(),
                    rotated.expiresAt()
            );
        } catch (RuntimeException e) {
            Counter.builder("ones.auth.refresh.fail")
                    .tag("code", errorCodeFor(e))
                    .register(meterRegistry)
                    .increment();
            throw e;
        } finally {
            sample.stop(refreshTimer);
        }
    }

    public void logout(String refreshToken) {
        if (refreshToken == null || refreshToken.isBlank()) {
            return;
        }

        String hash = RefreshTokenService.sha256Hex(refreshToken.trim());
        Instant now = Instant.now(clock);
        refreshTokensRepository.revoke(hash, now);
        logoutCounter.increment();
    }

    private static void putIfPresent(Map<String, Object> out, String key, Object value) {
        if (value == null) {
            return;
        }
        if (value instanceof String s) {
            if (s.isBlank()) {
                return;
            }
        }
        out.put(key, value);
    }

    private static String asString(Object value) {
        return value != null ? value.toString() : null;
    }

    public record SessionResponse(
            String accessToken,
            Instant accessExpiresAt,
            String refreshToken,
            Instant refreshExpiresAt
    ) {
    }

    public enum AuthErrorCode {
        INVALID_GOOGLE_TOKEN,
        INVALID_REFRESH_TOKEN,
        TOKEN_EXPIRED,
        TOKEN_REVOKED,
        TOKEN_REUSED,
        DEVICE_MISMATCH
    }

    public static class AuthException extends RuntimeException {
        private final AuthErrorCode code;

        public AuthException(AuthErrorCode code, String message) {
            super(message);
            this.code = code;
        }

        public AuthErrorCode code() {
            return code;
        }
    }

    private static String errorCodeFor(RuntimeException e) {
        if (e instanceof AuthException ae) {
            return ae.code().name();
        }
        if (e instanceof IllegalArgumentException) {
            return "INVALID_ARGUMENT";
        }
        return "UNKNOWN";
    }
}
