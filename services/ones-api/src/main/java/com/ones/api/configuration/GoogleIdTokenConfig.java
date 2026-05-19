package com.ones.api.configuration;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;

@Configuration
public class GoogleIdTokenConfig {

    @Bean("googleIdTokenDecoder")
    JwtDecoder googleIdTokenDecoder(
            @Value("${ones.auth.google.client-id:}") String googleClientId
    ) {
        NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri("https://www.googleapis.com/oauth2/v3/certs").build();

        OAuth2TokenValidator<Jwt> issuerValidator = JwtValidators.createDefaultWithIssuer("https://accounts.google.com");
        OAuth2TokenValidator<Jwt> audienceValidator = new GoogleAudienceValidator(googleClientId);

        decoder.setJwtValidator(new DelegatingOAuth2TokenValidatorWithAll<>(issuerValidator, audienceValidator));
        return decoder;
    }
}
