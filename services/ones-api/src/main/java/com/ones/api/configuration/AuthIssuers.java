package com.ones.api.configuration;

import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.Map;

import jakarta.servlet.http.HttpServletRequest;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.authentication.AuthenticationManager;
import org.springframework.security.authentication.AuthenticationManagerResolver;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.jwt.JwtClaimNames;
import org.springframework.security.oauth2.jwt.JwtClaimValidator;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.oauth2.jwt.JwtValidators;
import org.springframework.security.oauth2.jwt.NimbusJwtDecoder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationProvider;
import org.springframework.security.oauth2.server.resource.authentication.JwtIssuerAuthenticationManagerResolver;
import org.springframework.util.StringUtils;

/**
 * Emisores de ID tokens aceptados: Google directo (legado, apps anteriores a Firebase)
 * y Firebase Auth. Cada token se enruta por su claim iss a su propio decoder.
 */
final class AuthIssuers {

    static final String GOOGLE_ISSUER = "https://accounts.google.com";
    static final String GOOGLE_JWKS = "https://www.googleapis.com/oauth2/v3/certs";
    static final String FIREBASE_JWKS =
            "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

    private static final Logger log = LoggerFactory.getLogger(AuthIssuers.class);

    private AuthIssuers() {
    }

    static String firebaseIssuer(String projectId) {
        return "https://securetoken.google.com/" + projectId;
    }

    static Map<String, OAuth2TokenValidator<Jwt>> validators(
            boolean googleLegacyEnabled,
            String googleClientIds,
            String firebaseProjectId
    ) {
        Map<String, OAuth2TokenValidator<Jwt>> out = new LinkedHashMap<>();

        if (googleLegacyEnabled) {
            out.put(GOOGLE_ISSUER, new DelegatingOAuth2TokenValidatorWithAll<>(
                    JwtValidators.createDefaultWithIssuer(GOOGLE_ISSUER),
                    new GoogleAudienceValidator(googleClientIds)
            ));
        }

        if (StringUtils.hasText(firebaseProjectId)) {
            String projectId = firebaseProjectId.trim();
            String issuer = firebaseIssuer(projectId);
            out.put(issuer, new DelegatingOAuth2TokenValidatorWithAll<>(
                    JwtValidators.createDefaultWithIssuer(issuer),
                    new JwtClaimValidator<Collection<String>>(JwtClaimNames.AUD,
                            aud -> aud != null && aud.contains(projectId))
            ));
        } else {
            log.warn("[auth] FIREBASE_PROJECT_ID vacío: los tokens de Firebase serán rechazados");
        }

        if (out.isEmpty()) {
            throw new IllegalStateException(
                    "No hay emisores de autenticación habilitados: define FIREBASE_PROJECT_ID o GOOGLE_LEGACY_AUTH_ENABLED=true");
        }
        return out;
    }

    static Map<String, JwtDecoder> decoders(Map<String, OAuth2TokenValidator<Jwt>> validators) {
        Map<String, JwtDecoder> out = new LinkedHashMap<>();
        validators.forEach((issuer, validator) -> {
            String jwks = GOOGLE_ISSUER.equals(issuer) ? GOOGLE_JWKS : FIREBASE_JWKS;
            NimbusJwtDecoder decoder = NimbusJwtDecoder.withJwkSetUri(jwks).build();
            decoder.setJwtValidator(validator);
            out.put(issuer, decoder);
        });
        return out;
    }

    static AuthenticationManagerResolver<HttpServletRequest> resolver(
            Map<String, JwtDecoder> decoders,
            JwtAuthenticationConverter converter
    ) {
        Map<String, AuthenticationManager> managers = new HashMap<>();
        decoders.forEach((issuer, decoder) -> {
            JwtAuthenticationProvider provider = new JwtAuthenticationProvider(decoder);
            provider.setJwtAuthenticationConverter(converter);
            managers.put(issuer, provider::authenticate);
        });
        // Un issuer no registrado devuelve null y Spring responde 401 "Invalid issuer".
        return new JwtIssuerAuthenticationManagerResolver(managers::get);
    }
}
