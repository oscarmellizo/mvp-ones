package com.ones.api.adapters.inbound.rest.admin;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.admin.AdminsManagementService;
import com.ones.api.application.admin.ports.AdminsRepository;
import com.ones.api.domain.admin.AdminUser;

@RestController
@RequestMapping("/v1/admin/admins")
public class AdminAdminsController {

    private final AdminsManagementService service;

    public AdminAdminsController(AdminsManagementService service) {
        this.service = service;
    }

    @GetMapping
    public ListAdminsResponse list(
            @RequestParam(value = "limit", required = false) Integer limit,
            @RequestParam(value = "nextToken", required = false) String nextToken
    ) {
        int l = limit != null ? limit : 50;
        AdminsRepository.ListResult res = service.list(l, nextToken);
        List<AdminUserResponse> items = res.items().stream().map(AdminAdminsController::toResponse).toList();
        return new ListAdminsResponse(items, res.nextToken());
    }

    @PostMapping
    public ResponseEntity<AdminUserResponse> upsert(Authentication authentication, @RequestBody UpsertAdminRequest request) {
        String email = request != null ? request.email() : null;
        String statusRaw = request != null ? request.status() : null;

        AdminUser.Status status = parseStatus(statusRaw);
        AdminUser saved = service.upsert(authentication, email, status);
        return ResponseEntity.ok(toResponse(saved));
    }

    @PostMapping("/status")
    public ResponseEntity<AdminUserResponse> updateStatus(
            Authentication authentication,
            @RequestBody UpdateAdminStatusRequest request
    ) {
        String email = request != null ? request.email() : null;
        String statusRaw = request != null ? request.status() : null;

        AdminUser.Status status = parseStatus(statusRaw);
        AdminUser saved = service.upsert(authentication, email, status);
        return ResponseEntity.ok(toResponse(saved));
    }

    private static AdminUser.Status parseStatus(String raw) {
        if (raw == null || raw.isBlank()) {
            return AdminUser.Status.inactive;
        }
        String v = raw.trim().toLowerCase();
        if ("active".equals(v)) {
            return AdminUser.Status.active;
        }
        if ("inactive".equals(v)) {
            return AdminUser.Status.inactive;
        }
        return AdminUser.Status.inactive;
    }

    private static AdminUserResponse toResponse(AdminUser a) {
        return new AdminUserResponse(
                a.getEmail(),
                a.getStatus().name(),
                a.getCreatedAt(),
                a.getUpdatedAt(),
                a.getCreatedBy(),
                a.getUpdatedBy()
        );
    }

    public record AdminUserResponse(
            String email,
            String status,
            java.time.Instant createdAt,
            java.time.Instant updatedAt,
            String createdBy,
            String updatedBy
    ) {
    }

    public record ListAdminsResponse(List<AdminUserResponse> items, String nextToken) {
    }

    public record UpsertAdminRequest(String email, String status) {
    }

    public record UpdateAdminStatusRequest(String email, String status) {
    }
}
