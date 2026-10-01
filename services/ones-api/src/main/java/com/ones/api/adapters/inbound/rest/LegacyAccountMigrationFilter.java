package com.ones.api.adapters.inbound.rest;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.filter.OncePerRequestFilter;

import com.ones.api.application.users.AccountMigrationService;
import com.ones.api.application.users.AccountMigrationService.Outcome;

/**
 * Migra usuarios de Google legados la primera vez que entran con Firebase. Solo revisa /v1/users/**,
 * que la app siempre consulta al iniciar sesión. Tras 409 ACCOUNT_MIGRATED el cliente vuelve a iniciar
 * sesión en Firebase con la misma credencial de Google y recibe el uid legado.
 */
public class LegacyAccountMigrationFilter extends OncePerRequestFilter {

    public static final String CODE_MIGRATED = "ACCOUNT_MIGRATED";
    public static final String CODE_FAILED = "ACCOUNT_MIGRATION_FAILED";

    private static final Logger log = LoggerFactory.getLogger(LegacyAccountMigrationFilter.class);

    private final AccountMigrationService accountMigrationService;

    public LegacyAccountMigrationFilter(AccountMigrationService accountMigrationService) {
        this.accountMigrationService = accountMigrationService;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        if (path == null || path.isEmpty()) {
            path = request.getRequestURI();
        }
        return !path.startsWith("/v1/users/");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (!(auth instanceof JwtAuthenticationToken) || !AuthClaims.isFirebase(auth)) {
            chain.doFilter(request, response);
            return;
        }

        Outcome outcome;
        try {
            outcome = accountMigrationService.migrateIfLegacy(auth.getName(), AuthClaims.googleIdentity(auth));
        } catch (RuntimeException e) {
            log.error("[migration] falló la migración del uid {}", auth.getName(), e);
            write(response, HttpServletResponse.SC_SERVICE_UNAVAILABLE, CODE_FAILED);
            return;
        }

        if (outcome == Outcome.MIGRATED) {
            write(response, HttpServletResponse.SC_CONFLICT, CODE_MIGRATED);
            return;
        }
        chain.doFilter(request, response);
    }

    private static void write(HttpServletResponse response, int status, String code) throws IOException {
        response.setStatus(status);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write("{\"code\":\"" + code + "\"}");
        response.getWriter().flush();
    }
}
