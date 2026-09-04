package com.ones.api.application.push.ports;

import com.ones.api.domain.notifications.Notification;

public interface PushNotifier {
    void sendNotification(Notification notification);
}
