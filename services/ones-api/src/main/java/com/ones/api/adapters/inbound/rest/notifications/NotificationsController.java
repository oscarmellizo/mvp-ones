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

import com.ones.api.application.notifications.ports.NotificationsRepository;
import com.ones.api.domain.notifications.Notification;

@RestController
@RequestMapping("/v1/notifications")
public class NotificationsController {

    private final NotificationsRepository repository;

    public NotificationsController(NotificationsRepository repository) {
        this.repository = repository;
    }

    @GetMapping
    public List<NotificationResponse> list(Authentication authentication) {
        String userId = authentication != null ? authentication.getName() : null;
        if (userId == null || userId.isBlank()) {
            return List.of();
        }
        return repository.listByUserId(userId.trim(), 100)
                .stream()
                .map(NotificationsController::toResponse)
                .toList();
    }

    @GetMapping("/unread-count")
    public Map<String, Long> unreadCount(Authentication authentication) {
        String userId = authentication != null ? authentication.getName() : null;
        long count = (userId == null || userId.isBlank()) ? 0L : repository.countUnreadByUserId(userId.trim());
        return Map.of("unread", count);
    }

    @PostMapping("/{id}/read")
    public ResponseEntity<Void> markRead(Authentication authentication, @PathVariable("id") String id) {
        String userId = authentication != null ? authentication.getName() : null;
        if (userId == null || userId.isBlank() || id == null || id.isBlank()) {
            return ResponseEntity.noContent().build();
        }
        repository.markRead(userId.trim(), id.trim());
        return ResponseEntity.noContent().build();
    }

    private static NotificationResponse toResponse(Notification n) {
        return new NotificationResponse(
                n.getId(),
                n.getType(),
                n.getTitle(),
                n.getBody(),
                n.getCreatedAt(),
                n.getReadAt(),
                n.getStatus() != null ? n.getStatus().name() : null,
                n.getPriority() != null ? n.getPriority().name() : null,
                n.getActionType(),
                n.getEntityType(),
                n.getEntityId(),
                n.getRoute()
        );
    }
}
