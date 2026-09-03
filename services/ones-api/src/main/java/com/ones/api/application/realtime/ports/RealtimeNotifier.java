package com.ones.api.application.realtime.ports;

import com.ones.api.domain.notifications.Notification;

public interface RealtimeNotifier {
    void sendNotification(Notification notification);
}
