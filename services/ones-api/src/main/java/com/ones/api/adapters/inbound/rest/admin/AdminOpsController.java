package com.ones.api.adapters.inbound.rest.admin;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import com.ones.api.application.admin.AdminOpsService;

@RestController
@RequestMapping("/v1/admin/ops")
public class AdminOpsController {

    private final AdminOpsService adminOpsService;

    public AdminOpsController(AdminOpsService adminOpsService) {
        this.adminOpsService = adminOpsService;
    }

    @GetMapping("/queues")
    public AdminOpsService.QueuesStatus queues() {
        return adminOpsService.queuesStatus();
    }

    @GetMapping("/mappings")
    public AdminOpsService.MappingsStatus mappings() {
        return adminOpsService.mappingsStatus();
    }

    @PostMapping("/mappings/realtime/{enabled}")
    public ResponseEntity<Void> setRealtimeMapping(@PathVariable("enabled") boolean enabled) {
        adminOpsService.setRealtimeMappingEnabled(enabled);
        return ResponseEntity.accepted().build();
    }
}
