package com.ones.api.configuration;

import java.util.List;

import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.util.StringUtils;

public class GoogleAudienceValidator implements OAuth2TokenValidator<Jwt> {

    private final String googleClientId;

    public GoogleAudienceValidator(String googleClientId) {
        this.googleClientId = googleClientId;
    }

    @Override
    public OAuth2TokenValidatorResult validate(Jwt token) {
        if (!StringUtils.hasText(googleClientId)) {
            return OAuth2TokenValidatorResult.failure(new OAuth2Error(
                    "invalid_token",
                    "GOOGLE_CLIENT_ID is required to validate Google ID token audience.",
                    null
            ));
        }

        List<String> aud = token.getAudience();
        if (aud != null && aud.contains(googleClientId)) {
            return OAuth2TokenValidatorResult.success();
        }

        return OAuth2TokenValidatorResult.failure(new OAuth2Error(
                "invalid_token",
                "Invalid audience (aud) for Google ID token.",
                null
        ));
    }
}
