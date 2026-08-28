package com.ones.api.infrastructure.events;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.ones.api.application.events.bus.DomainEventPublisher;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.notifications.ports.NotificationsRepository;
import com.ones.api.application.realtime.ports.RealtimeNotifier;
import com.ones.api.application.push.ports.PushNotifier;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.notifications.Notification;
import com.ones.api.domain.users.User;

@Component
public class LoggingEventPublisher implements DomainEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(LoggingEventPublisher.class);

    private final UsersRepository usersRepository;
    private final InvitationsRepository invitationsRepository;
    private final NotificationsRepository notificationsRepository;
    private final RealtimeNotifier realtimeNotifier;
    private final PushNotifier pushNotifier;
    private final Clock clock;

    public LoggingEventPublisher(
            UsersRepository usersRepository,
            InvitationsRepository invitationsRepository,
            NotificationsRepository notificationsRepository,
            RealtimeNotifier realtimeNotifier,
            PushNotifier pushNotifier,
            Clock clock
    ) {
        this.usersRepository = usersRepository;
        this.invitationsRepository = invitationsRepository;
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

    @Override
    public void publishInvitationResponded(Invitation invitation) {
        if (invitation == null) return;
        String ownerId = invitation.getEventOwnerId();
        if (ownerId == null || ownerId.isBlank()) return;
        Instant now = Instant.now(clock);
        String id = UUID.randomUUID().toString();
        String title = safe("Respuesta a tu invitación");
        String status = invitation.getStatus() == null ? "" : invitation.getStatus().name();
        String invitee = invitation.getInviteeEmail() == null ? "Invitado" : invitation.getInviteeEmail();
        String body = safe(invitee + " → " + status.toLowerCase());
        Notification n = new Notification(
                ownerId.trim(),
                id,
                "invitation.responded",
                title,
                body,
                now,
                null,
                Notification.Status.CREATED,
                Notification.Priority.MEDIUM,
                "open",
                "event",
                invitation.getEventId(),
                "/events/" + invitation.getEventId()
        );
        notificationsRepository.upsert(n);
        try { if (realtimeNotifier != null) realtimeNotifier.sendNotification(n); } catch (Exception ignored) {}
        try { if (pushNotifier != null) pushNotifier.sendNotification(n); } catch (Exception ignored) {}
    }

    @Override
    public void publishEventUpdated(Event previous, Event updated) {
        if (updated == null) return;
        String eventId = updated.getEventId();
        String ownerId = updated.getOwnerId();
        if (eventId == null || eventId.isBlank()) return;
        Instant now = Instant.now(clock);
        String title = safe("Evento actualizado");
        String body = safe(updated.getTitle());

        if (ownerId != null && !ownerId.isBlank()) {
            Notification nOwner = new Notification(
                    ownerId.trim(),
                    UUID.randomUUID().toString(),
                    "event.updated",
                    title,
                    body,
                    now,
                    null,
                    Notification.Status.CREATED,
                    Notification.Priority.MEDIUM,
                    "open",
                    "event",
                    eventId,
                    "/events/" + eventId
            );
            notificationsRepository.upsert(nOwner);
            try { if (realtimeNotifier != null) realtimeNotifier.sendNotification(nOwner); } catch (Exception ignored) {}
            try { if (pushNotifier != null) pushNotifier.sendNotification(nOwner); } catch (Exception ignored) {}
        }

        try {
            if (invitationsRepository != null) {
                var invitations = invitationsRepository.listByEventId(eventId, 500);
                for (var inv : invitations) {
                    if (inv == null) continue;
                    if (inv.getStatus() != com.ones.api.domain.invitations.Invitation.Status.accepted) continue;
                    String userId = inv.getInviteeUserId();
                    if (userId == null || userId.isBlank()) continue;
                    Notification n = new Notification(
                            userId.trim(),
                            UUID.randomUUID().toString(),
                            "event.updated",
                            title,
                            body,
                            now,
                            null,
                            Notification.Status.CREATED,
                            Notification.Priority.MEDIUM,
                            "open",
                            "event",
                            eventId,
                            "/events/" + eventId
                    );
                    notificationsRepository.upsert(n);
                    try { if (realtimeNotifier != null) realtimeNotifier.sendNotification(n); } catch (Exception ignored) {}
                    try { if (pushNotifier != null) pushNotifier.sendNotification(n); } catch (Exception ignored) {}
                }
            }
        } catch (Exception e) {
            log.warn("[Notification] Failed to send event.updated for eventId={} err={}", eventId, e.getMessage());
        }
    }

    private static String safe(String s) {
        return s != null ? s : "";
    }
}
