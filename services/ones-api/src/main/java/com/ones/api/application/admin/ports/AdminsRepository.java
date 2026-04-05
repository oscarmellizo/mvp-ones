package com.ones.api.application.admin.ports;

import java.util.List;
import java.util.Optional;

import com.ones.api.domain.admin.AdminUser;

public interface AdminsRepository {

    record ListResult(List<AdminUser> items, String nextToken) {
    }

    boolean isActiveAdmin(String email);

    Optional<AdminUser> findByEmail(String email);

    ListResult list(int limit, String nextToken);

    AdminUser upsert(AdminUser adminUser);
}
