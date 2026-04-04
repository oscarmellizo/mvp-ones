package com.ones.api.adapters.inbound.rest.admin;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.admin.AdminAccessService;

@RestController
@RequestMapping("/v1/admin")
public class AdminMeController {

    private final AdminAccessService adminAccessService;

    public AdminMeController(AdminAccessService adminAccessService) {
        this.adminAccessService = adminAccessService;
    }

    @GetMapping("/me")
    public AdminMeResponse me(Authentication authentication) {
        boolean isAdmin = adminAccessService.isAdmin(authentication);
        return new AdminMeResponse(isAdmin);
    }

    public record AdminMeResponse(boolean isAdmin) {
    }
}
