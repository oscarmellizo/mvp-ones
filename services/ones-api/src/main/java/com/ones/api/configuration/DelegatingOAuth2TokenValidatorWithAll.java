package com.ones.api.configuration;

import java.util.ArrayList;
import java.util.List;

import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2Token;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;

public class DelegatingOAuth2TokenValidatorWithAll<T extends OAuth2Token> implements OAuth2TokenValidator<T> {

    private final List<OAuth2TokenValidator<T>> delegates;

    @SafeVarargs
    public DelegatingOAuth2TokenValidatorWithAll(OAuth2TokenValidator<T>... delegates) {
        this.delegates = List.of(delegates);
    }

    @Override
    public OAuth2TokenValidatorResult validate(T token) {
        List<OAuth2Error> errors = new ArrayList<>();

        for (OAuth2TokenValidator<T> delegate : delegates) {
            OAuth2TokenValidatorResult result = delegate.validate(token);
            if (result.hasErrors()) {
                errors.addAll(result.getErrors());
            }
        }

        return errors.isEmpty() ? OAuth2TokenValidatorResult.success() : OAuth2TokenValidatorResult.failure(errors);
    }
}
