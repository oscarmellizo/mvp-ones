package com.ones.api.application.admin;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.security.core.Authentication;
import org.springframework.stereotype.Service;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.admin.ports.AdminsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.configuration.CacheConfig;
import com.ones.api.domain.users.User;

@Service
public class AdminAccessService {

    private final AdminsRepository adminsRepository;
    private final UsersRepository usersRepository;

    public AdminAccessService(AdminsRepository adminsRepository, UsersRepository usersRepository) {
        this.adminsRepository = adminsRepository;
        this.usersRepository = usersRepository;
    }

    public boolean isAdmin(Authentication authentication) {
        String email = resolveEmail(authentication);
        return isAdminByEmail(email);
    }

    @Cacheable(cacheNames = CacheConfig.ADMIN_ACCESS_CACHE)
    public boolean isAdminByEmail(String email) {
        if (email == null || email.isBlank()) {
            return false;
        }
        return adminsRepository.isActiveAdmin(email.trim().toLowerCase());
    }

    private String resolveEmail(Authentication authentication) {
        String userId = authentication != null ? authentication.getName() : null;

        String claimEmail = null;
        try {
            claimEmail = AuthClaims.requireEmail(authentication);
        } catch (Exception ignored) {
            claimEmail = null;
        }

        if (claimEmail != null && !claimEmail.isBlank() && claimEmail.contains("@")) {
            return claimEmail.trim().toLowerCase();
        }

        if (userId != null && !userId.isBlank() && usersRepository != null) {
            User u = usersRepository.findById(userId).orElse(null);
            if (u != null && u.getEmail() != null && !u.getEmail().isBlank() && u.getEmail().contains("@")) {
                return u.getEmail().trim().toLowerCase();
            }
        }

        if (claimEmail != null && !claimEmail.isBlank()) {
            return claimEmail.trim().toLowerCase();
        }

        throw new IllegalStateException("Missing email");
    }
}
