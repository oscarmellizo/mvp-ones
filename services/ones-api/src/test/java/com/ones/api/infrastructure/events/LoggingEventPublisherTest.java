package com.ones.api.infrastructure.events;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;

import com.ones.api.application.notifications.ports.NotificationsRepository;
import com.ones.api.application.realtime.ports.RealtimeNotifier;
import com.ones.api.application.push.ports.PushNotifier;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.notifications.Notification;
import com.ones.api.domain.users.User;

public class LoggingEventPublisherTest {

    private UsersRepository usersRepository;
    private NotificationsRepository notificationsRepository;
    private RealtimeNotifier realtimeNotifier;
    private PushNotifier pushNotifier;
    private Clock clock;
    private LoggingEventPublisher publisher;

    @BeforeEach
    void setUp() {
        usersRepository = mock(UsersRepository.class);
        notificationsRepository = mock(NotificationsRepository.class);
        realtimeNotifier = mock(RealtimeNotifier.class);
        pushNotifier = mock(PushNotifier.class);
        clock = Clock.fixed(Instant.parse("2024-01-01T10:00:00Z"), ZoneOffset.UTC);
        publisher = new LoggingEventPublisher(usersRepository, notificationsRepository, realtimeNotifier, pushNotifier, clock);
    }

    @Test
    void whenInvitationCreated_andUserExists_createsInAppNotification() {
        String email = "guest@example.com";
        String userId = "user-123";
        User user = new User(userId, email, null, null, null, null, null, "stub", null, true,
                Instant.parse("2023-12-31T00:00:00Z"), Instant.parse("2023-12-31T00:00:00Z"));
        when(usersRepository.findByEmail(email)).thenReturn(Optional.of(user));

        Invitation inv = new Invitation(
                "evt-1",
                email,
                null,
                "owner-1",
                Invitation.Status.invited,
                Instant.parse("2023-12-30T00:00:00Z"),
                Instant.parse("2023-12-30T00:00:00Z"),
                "Cumpleaños",
                "Bogotá",
                Instant.parse("2024-01-01T08:00:00Z"),
                Instant.parse("2024-01-01T09:00:00Z")
        );

        publisher.publishInvitationCreated(inv);

        ArgumentCaptor<Notification> captor = ArgumentCaptor.forClass(Notification.class);
        verify(notificationsRepository, times(1)).upsert(captor.capture());
        Notification n = captor.getValue();
        assertEquals(userId, n.getUserId());
        assertEquals("invitations", n.getType());
        assertEquals("event", n.getEntityType());
        assertEquals("evt-1", n.getEntityId());
        assertEquals("/events/evt-1", n.getRoute());
        assertNull(n.getReadAt());
        assertEquals(Notification.Status.CREATED, n.getStatus());
        verify(realtimeNotifier, times(1)).sendNotification(any(Notification.class));
        verify(pushNotifier, times(1)).sendNotification(any(Notification.class));
    }

    @Test
    void whenInvitationCreated_andUserDoesNotExist_doesNotCreateNotification() {
        String email = "nouser@example.com";
        when(usersRepository.findByEmail(email)).thenReturn(Optional.empty());

        Invitation inv = new Invitation(
                "evt-2",
                email,
                null,
                "owner-2",
                Invitation.Status.invited,
                Instant.parse("2023-12-30T00:00:00Z"),
                Instant.parse("2023-12-30T00:00:00Z"),
                "Reunión",
                null,
                Instant.parse("2024-01-01T08:00:00Z"),
                Instant.parse("2024-01-01T09:00:00Z")
        );

        publisher.publishInvitationCreated(inv);

        verify(notificationsRepository, never()).upsert(any());
    }
}
