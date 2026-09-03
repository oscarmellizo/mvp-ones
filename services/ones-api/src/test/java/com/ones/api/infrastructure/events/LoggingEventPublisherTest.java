package com.ones.api.infrastructure.events;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import com.ones.api.domain.invitations.Invitation;

public class LoggingEventPublisherTest {

    private Clock clock;
    private LoggingEventPublisher publisher;

    @BeforeEach
    void setUp() {
        clock = Clock.fixed(Instant.parse("2024-01-01T10:00:00Z"), ZoneOffset.UTC);
        publisher = new LoggingEventPublisher(clock);
    }

    @Test
    void whenInvitationCreated_smokeTest_noException() {
        Invitation inv = new Invitation(
                "evt-1",
                "guest@example.com",
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
        assertDoesNotThrow(() -> publisher.publishInvitationCreated(inv));
    }

    @Test
    void whenPhotoUploaded_smokeTest_noException() {
        assertDoesNotThrow(() -> publisher.publishPhotosUploaded("evt-2", "uploader-1", "Juan", 3, "Reunión"));
    }
}
