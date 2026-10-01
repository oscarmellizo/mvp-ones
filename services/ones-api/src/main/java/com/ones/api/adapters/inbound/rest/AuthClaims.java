package com.ones.api.adapters.inbound.rest;

import java.util.List;
import java.util.Map;

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

    public static boolean isFirebase(Authentication authentication) {
        return firebaseClaim(authentication) != null;
    }

    /** Proveedor de inicio de sesión: firebase.sign_in_provider, o "google" para tokens de Google directos. */
    public static String provider(Authentication authentication) {
        Map<?, ?> firebase = firebaseClaim(authentication);
        Object value = firebase != null ? firebase.get("sign_in_provider") : null;
        return value != null ? value.toString() : "google";
    }

    public static boolean emailVerified(Authentication authentication) {
        Jwt jwt = getJwt(authentication);
        Object value = jwt != null ? jwt.getClaims().get("email_verified") : null;
        return Boolean.TRUE.equals(value) || "true".equals(String.valueOf(value));
    }

    /** sub de Google vinculado al usuario de Firebase (firebase.identities["google.com"][0]), o null. */
    public static String googleIdentity(Authentication authentication) {
        Map<?, ?> firebase = firebaseClaim(authentication);
        if (firebase == null || !(firebase.get("identities") instanceof Map<?, ?> identities)) {
            return null;
        }
        if (identities.get("google.com") instanceof List<?> ids && !ids.isEmpty() && ids.get(0) != null) {
            return ids.get(0).toString();
        }
        return null;
    }

    private static Map<?, ?> firebaseClaim(Authentication authentication) {
        Jwt jwt = getJwt(authentication);
        Object value = jwt != null ? jwt.getClaims().get("firebase") : null;
        return value instanceof Map<?, ?> map ? map : null;
    }

    private static Jwt getJwt(Authentication authentication) {
        if (authentication instanceof JwtAuthenticationToken jwtAuth) {
            return jwtAuth.getToken();
        }
        return null;
    }
}
