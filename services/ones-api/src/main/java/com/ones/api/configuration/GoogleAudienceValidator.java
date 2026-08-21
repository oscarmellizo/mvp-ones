package com.ones.api.configuration;

import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.util.StringUtils;

public class GoogleAudienceValidator implements OAuth2TokenValidator<Jwt> {

    private final Set<String> allowedAudiences;

    /**
     * @param googleClientIds uno o varios OAuth client IDs separados por coma. Cada
     *                        plataforma acuna el ID token para su propio client: Web y
     *                        Android usan el client web (via serverClientId), mientras que
     *                        iOS lo acuna siempre para su client de tipo iOS.
     */
    public GoogleAudienceValidator(String googleClientIds) {
        this.allowedAudiences = StringUtils.hasText(googleClientIds)
                ? Arrays.stream(googleClientIds.split(","))
                        .map(String::trim)
                        .filter(StringUtils::hasText)
                        .collect(Collectors.toCollection(LinkedHashSet::new))
                : Set.of();
    }

    @Override
    public OAuth2TokenValidatorResult validate(Jwt token) {
        if (allowedAudiences.isEmpty()) {
            return OAuth2TokenValidatorResult.failure(new OAuth2Error(
                    "invalid_token",
                    "GOOGLE_CLIENT_ID is required to validate Google ID token audience.",
                    null
            ));
        }

        List<String> aud = token.getAudience();
        if (aud != null && aud.stream().anyMatch(allowedAudiences::contains)) {
            return OAuth2TokenValidatorResult.success();
        }

        return OAuth2TokenValidatorResult.failure(new OAuth2Error(
                "invalid_token",
                "Invalid audience (aud) for Google ID token.",
                null
        ));
    }
}
