package com.ones.api.adapters.inbound.rest;

import java.io.IOException;
import java.nio.charset.StandardCharsets;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.http.MediaType;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.filter.OncePerRequestFilter;

import com.ones.api.application.users.AccountAccess;
import com.ones.api.application.users.AccountAccessService;

/**
 * Rechaza con 403 las peticiones autenticadas de cuentas desactivadas.
 * Deja pasar los endpoints necesarios para consultar/reactivar la cuenta y el registro de login.
 */
public class DisabledAccountFilter extends OncePerRequestFilter {

    public static final String CODE_DISABLED = "ACCOUNT_DISABLED";
    public static final String CODE_CLOSED = "ACCOUNT_CLOSED";

    private final AccountAccessService accountAccessService;

    public DisabledAccountFilter(AccountAccessService accountAccessService) {
        this.accountAccessService = accountAccessService;
    }

    @Override
    protected boolean shouldNotFilter(HttpServletRequest request) {
        String path = request.getServletPath();
        if (path == null || path.isEmpty()) {
            path = request.getRequestURI();
        }
        return path.equals("/v1/account")
                || path.startsWith("/v1/account/")
                || path.startsWith("/v1/account:")
                || path.equals("/v1/users/ensure");
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (!(auth instanceof JwtAuthenticationToken) || auth.getName() == null || auth.getName().isBlank()) {
            chain.doFilter(request, response);
            return;
        }

        AccountAccess access = accountAccessService.check(auth.getName());
        if (access == AccountAccess.ACTIVE) {
            chain.doFilter(request, response);
            return;
        }

        String code = access == AccountAccess.CLOSED ? CODE_CLOSED : CODE_DISABLED;
        response.setStatus(HttpServletResponse.SC_FORBIDDEN);
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.setCharacterEncoding(StandardCharsets.UTF_8.name());
        response.getWriter().write("{\"code\":\"" + code + "\",\"status\":\"DISABLED\"}");
        response.getWriter().flush();
    }
}
