package com.ones.api.adapters.inbound.rest.notifications;

import java.util.List;
import java.util.Map;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.adapters.inbound.rest.AuthClaims;

@RestController
@RequestMapping("/v1/notifications")
public class NotificationsController {

    @GetMapping
    public List<NotificationResponse> list(Authentication authentication) {
        String userId = authentication != null ? authentication.getName() : null;
        if (userId == null || userId.isBlank()) {
            return List.of();
        }
        return List.of();
    }

    @GetMapping("/unread-count")
    public Map<String, Long> unreadCount(Authentication authentication) {
        String userId = authentication != null ? authentication.getName() : null;
        long count = 0L;
        return Map.of("unread", count);
    }

    @PostMapping("/{id}/read")
    public ResponseEntity<Void> markRead(Authentication authentication, @PathVariable("id") String id) {
        String userId = authentication != null ? authentication.getName() : null;
        return ResponseEntity.noContent().build();
    }
}
