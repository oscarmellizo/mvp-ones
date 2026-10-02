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

/**
 * Rechaza con 403 las cuentas de correo/contraseña de Firebase que aún no verificaron su correo.
 * Se responde 403 (no 401) para que el cliente no lo confunda con un token expirado.
 */
public class EmailVerifiedFilter extends OncePerRequestFilter {

    public static final String CODE = "EMAIL_NOT_VERIFIED";

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth instanceof JwtAuthenticationToken
                && "password".equals(AuthClaims.provider(auth))
                && !AuthClaims.emailVerified(auth)) {
            response.setStatus(HttpServletResponse.SC_FORBIDDEN);
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.setCharacterEncoding(StandardCharsets.UTF_8.name());
            response.getWriter().write("{\"code\":\"" + CODE + "\"}");
            response.getWriter().flush();
            return;
        }
        chain.doFilter(request, response);
    }
}
