package com.ones.api.application.notifications.ports;

import java.util.List;
import java.util.Optional;

import com.ones.api.domain.notifications.Notification;

public interface NotificationsRepository {
    Notification upsert(Notification notification);
    Optional<Notification> findByUserAndId(String userId, String id);
    List<Notification> listByUserId(String userId, int limit);
    long countUnreadByUserId(String userId);
    Notification markRead(String userId, String id);
}
