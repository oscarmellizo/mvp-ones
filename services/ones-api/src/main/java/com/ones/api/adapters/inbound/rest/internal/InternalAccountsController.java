package com.ones.api.adapters.inbound.rest.internal;

import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.users.lifecycle.AccountLifecycleJob;

@RestController
@RequestMapping("/internal/accounts")
public class InternalAccountsController {

    private final AccountLifecycleJob job;

    public InternalAccountsController(AccountLifecycleJob job) {
        this.job = job;
    }

    @PostMapping("/lifecycle")
    public ResponseEntity<Map<String, Object>> lifecycle() {
        return job.start()
                ? ResponseEntity.accepted().body(Map.of("started", true))
                : ResponseEntity.status(409).body(Map.of("code", "RUN_IN_PROGRESS"));
    }
}
