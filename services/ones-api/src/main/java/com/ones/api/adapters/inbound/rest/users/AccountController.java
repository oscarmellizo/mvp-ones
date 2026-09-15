package com.ones.api.adapters.inbound.rest.users;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.LinkedHashMap;

import com.ones.api.application.users.AccountAccessService;
import com.ones.api.application.users.AccountDeactivateUseCase;
import com.ones.api.application.users.AccountReactivateUseCase;
import com.ones.api.application.users.GetAccountUseCase;
import com.ones.api.application.users.email.AccountEmailService;
import com.ones.api.domain.users.User;

@RestController
@RequestMapping("/v1/account")
public class AccountController {

    private final GetAccountUseCase getAccount;
    private final AccountDeactivateUseCase deactivate;
    private final AccountReactivateUseCase reactivate;
    private final AccountEmailService emailService;
    private final Clock clock;
    private final AccountAccessService accountAccess;

    public AccountController(
            GetAccountUseCase getAccount,
            AccountDeactivateUseCase deactivate,
            AccountReactivateUseCase reactivate,
            AccountEmailService emailService,
            Clock clock,
            AccountAccessService accountAccess
    ) {
        this.getAccount = getAccount;
        this.deactivate = deactivate;
        this.reactivate = reactivate;
        this.emailService = emailService;
        this.clock = clock;
        this.accountAccess = accountAccess;
    }

    @GetMapping
    public ResponseEntity<Map<String, Object>> get(Authentication authentication) {
        String userId = authentication.getName();
        return getAccount.execute(userId)
                .map(u -> ResponseEntity.ok(toResponse(u)))
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping(path = {"/deactivate", ":deactivate"})
    public ResponseEntity<Map<String, Object>> deactivate(Authentication authentication) {
        String userId = authentication.getName();
        Optional<User> result = deactivate.execute(userId);
        accountAccess.evict(userId);
        return result
                .map(u -> {
                    // Send confirmation email (non-blocking best effort)
                    try {
                        Instant disabledAt = u.getDisabledAt() != null ? u.getDisabledAt() : Instant.now(clock);
                        Instant scheduled = disabledAt.plus(Duration.ofDays(30));
                        emailService.sendDeactivationEmail(u, disabledAt, scheduled);
                    } catch (Exception ignore) {}
                    return ResponseEntity.ok(toResponse(u));
                })
                .orElseGet(() -> ResponseEntity.notFound().build());
    }

    @PostMapping(path = {"/reactivate", ":reactivate"})
    public ResponseEntity<Map<String, Object>> reactivate(Authentication authentication) {
        String userId = authentication.getName();
        Optional<User> result = reactivate.execute(userId);
        accountAccess.evict(userId);
        return result
                .map(u -> ResponseEntity.ok(toResponse(u)))
                .orElseGet(() -> ResponseEntity.status(403).build());
    }

    private static Map<String, Object> toResponse(User u) {
        Map<String, Object> out = new LinkedHashMap<>();
        out.put("userId", u.getUserId());
        out.put("status", u.getStatus() != null ? u.getStatus() : "ACTIVE");
        if (u.getDisabledAt() != null) {
            out.put("disabledAt", u.getDisabledAt());
        }
        if (u.getReactivatedAt() != null) {
            out.put("reactivatedAt", u.getReactivatedAt());
        }
        return out;
    }
}
