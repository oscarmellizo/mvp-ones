package com.ones.api.application.auth;

import java.time.Clock;
import java.time.Instant;
import java.util.Map;

import com.ones.api.configuration.OnesJwtProperties;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;

public class AccessTokenService {

    private final JwtEncoder jwtEncoder;
    private final OnesJwtProperties jwtProperties;
    private final Clock clock;

    public AccessTokenService(JwtEncoder jwtEncoder, OnesJwtProperties jwtProperties, Clock clock) {
        this.jwtEncoder = jwtEncoder;
        this.jwtProperties = jwtProperties;
        this.clock = clock;
    }

    public IssuedAccessToken issue(String userId, Map<String, Object> claims) {
        Instant now = Instant.now(clock);
        Instant exp = now.plus(jwtProperties.accessTtl());

        JwtClaimsSet.Builder builder = JwtClaimsSet.builder()
                .issuer(jwtProperties.issuer())
                .issuedAt(now)
                .expiresAt(exp)
                .subject(userId);

        if (claims != null) {
            claims.forEach(builder::claim);
        }

        String tokenValue = jwtEncoder.encode(JwtEncoderParameters.from(builder.build())).getTokenValue();
        return new IssuedAccessToken(tokenValue, exp);
    }

    public record IssuedAccessToken(String token, Instant expiresAt) {
    }
}
