package com.ones.api.application.admin;

import java.time.Clock;
import java.time.Instant;

import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.admin.ports.AdminsRepository;
import com.ones.api.configuration.CacheConfig;
import com.ones.api.domain.admin.AdminUser;

@Service
public class AdminsManagementService {

    private final AdminsRepository repository;
    private final Clock clock;
    private final CacheManager cacheManager;

    public AdminsManagementService(AdminsRepository repository, Clock clock, CacheManager cacheManager) {
        this.repository = repository;
        this.clock = clock;
        this.cacheManager = cacheManager;
    }

    public AdminsRepository.ListResult list(int limit, String nextToken) {
        return repository.list(limit, nextToken);
    }

    public AdminUser upsert(Authentication authentication, String email, AdminUser.Status status) {
        if (email == null || email.isBlank()) {
            throw new IllegalArgumentException("email is required");
        }

        String normalizedEmail = email.trim().toLowerCase();
        Instant now = Instant.now(clock);

        String actor;
        try {
            actor = AuthClaims.requireEmail(authentication);
        } catch (Exception ignored) {
            actor = authentication != null ? authentication.getName() : "unknown";
        }

        AdminUser existing = repository.findByEmail(normalizedEmail).orElse(null);
        Instant createdAt = existing != null ? existing.getCreatedAt() : now;
        String createdBy = existing != null ? existing.getCreatedBy() : actor;

        AdminUser toSave = new AdminUser(
                normalizedEmail,
                status != null ? status : AdminUser.Status.inactive,
                createdAt,
                now,
                createdBy,
                actor
        );

        AdminUser saved = repository.upsert(toSave);
        evictAdminAccessCache(normalizedEmail);
        return saved;
    }

    private void evictAdminAccessCache(String normalizedEmail) {
        if (normalizedEmail == null || normalizedEmail.isBlank()) {
            return;
        }
        Cache cache = cacheManager != null ? cacheManager.getCache(CacheConfig.ADMIN_ACCESS_CACHE) : null;
        if (cache != null) {
            cache.evict(normalizedEmail);
        }
    }
}
