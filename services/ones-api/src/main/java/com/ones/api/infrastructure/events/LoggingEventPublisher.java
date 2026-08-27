package com.ones.api.infrastructure.events;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.ones.api.application.events.bus.DomainEventPublisher;
import com.ones.api.application.notifications.ports.NotificationsRepository;
import com.ones.api.application.realtime.ports.RealtimeNotifier;
import com.ones.api.application.push.ports.PushNotifier;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.notifications.Notification;
import com.ones.api.domain.users.User;

@Component
public class LoggingEventPublisher implements DomainEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(LoggingEventPublisher.class);

    private final UsersRepository usersRepository;
    private final NotificationsRepository notificationsRepository;
    private final RealtimeNotifier realtimeNotifier;
    private final PushNotifier pushNotifier;
    private final Clock clock;

    public LoggingEventPublisher(
            UsersRepository usersRepository,
            NotificationsRepository notificationsRepository,
            RealtimeNotifier realtimeNotifier,
            PushNotifier pushNotifier,
            Clock clock
    ) {
        this.usersRepository = usersRepository;
        this.notificationsRepository = notificationsRepository;
        this.realtimeNotifier = realtimeNotifier;
        this.pushNotifier = pushNotifier;
        this.clock = clock;
    }

    @Override
    public void publishInvitationCreated(Invitation invitation) {
        if (invitation == null) return;
        log.info("[DomainEvent] InvitationCreated eventId={} inviteeEmail={} ownerId={}",
                invitation.getEventId(), invitation.getInviteeEmail(), invitation.getEventOwnerId());

        // In-app notification only for usuarios ya registrados (según requerimiento)
        String email = invitation.getInviteeEmail();
        if (email == null || email.isBlank()) return;

        usersRepository.findByEmail(email.trim().toLowerCase()).ifPresent(user -> {
            createInvitationNotification(user, invitation);
        });
    }

    private void createInvitationNotification(User user, Invitation inv) {
        try {
            String userId = user.getUserId();
            if (userId == null || userId.isBlank()) return;

            Instant now = Instant.now(clock);
            String id = UUID.randomUUID().toString();
            String title = safe("Fuiste invitado a un evento");
            String body = safe(inv.getEventTitle());

            Notification n = new Notification(
                    userId,
                    id,
                    "invitations",
                    title,
                    body,
                    now,
                    null,
                    Notification.Status.CREATED,
                    Notification.Priority.MEDIUM,
                    "open",
                    "event",
                    inv.getEventId(),
                    "/events/" + inv.getEventId()
            );
            notificationsRepository.upsert(n);
            log.info("[Notification] Invitation notification created userId={} eventId={} id={}", userId, inv.getEventId(), id);
            try {
                if (realtimeNotifier != null) {
                    realtimeNotifier.sendNotification(n);
                }
            } catch (Exception ex) {
                log.debug("[Realtime] Failed to send realtime notification userId={} id={} err={}", userId, id, ex.getMessage());
            }
            try {
                if (pushNotifier != null) {
                    pushNotifier.sendNotification(n);
                }
            } catch (Exception ex) {
                log.debug("[Push] Failed to send push notification userId={} id={} err={}", userId, id, ex.getMessage());
            }
        } catch (Exception e) {
            log.warn("[Notification] Failed to create invitation notification for email={} eventId={} err={}",
                    inv.getInviteeEmail(), inv.getEventId(), e.getMessage());
        }
    }

    private static String safe(String s) {
        return s != null ? s : "";
    }
}
