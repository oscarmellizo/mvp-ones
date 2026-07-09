package com.ones.api.adapters.inbound.rest;

import org.springframework.security.core.Authentication;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

public final class AuthClaims {

    private AuthClaims() {
    }

    public static String requireEmail(Authentication authentication) {
        Jwt jwt = getJwt(authentication);

        Object value = jwt != null ? jwt.getClaims().get("email") : null;
        if (value == null && jwt != null) {
            value = jwt.getClaims().get("cognito:username");
        }
        if (value == null && jwt != null) {
            value = jwt.getClaims().get("preferred_username");
        }

        String email = value != null ? value.toString().trim().toLowerCase() : "";
        if (email.isEmpty() || !email.contains("@")) {
            throw new IllegalStateException("Missing email claim");
        }
        return email;
    }

    public static String preferredName(Authentication authentication) {
        Jwt jwt = getJwt(authentication);
        if (jwt != null) {
            for (String key : new String[]{"name", "given_name", "preferred_username", "cognito:username", "email"}) {
                Object v = jwt.getClaims().get(key);
                if (v != null) {
                    String s = v.toString().trim();
                    if (!s.isEmpty()) return s;
                }
            }
        }
        String sub = authentication != null ? authentication.getName() : "";
        return sub != null && !sub.isBlank() ? sub : "Alguien";
    }

    public static String getClaim(Authentication authentication, String claimName) {
        Jwt jwt = getJwt(authentication);
        if (jwt == null) {
            return null;
        }
        Object value = jwt.getClaims().get(claimName);
        return value != null ? value.toString() : null;
    }

    private static Jwt getJwt(Authentication authentication) {
        if (authentication instanceof JwtAuthenticationToken jwtAuth) {
            return jwtAuth.getToken();
        }
        return null;
    }
}
