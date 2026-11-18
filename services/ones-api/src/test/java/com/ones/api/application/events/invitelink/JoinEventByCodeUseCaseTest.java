package com.ones.api.application.events.invitelink;

import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

class JoinEventByCodeUseCaseTest {

    @Test
    void resolvesTheEnteredCodeAndAcceptsAnInvitationToThatEvent() {
        EventsRepository eventsRepository = mock(EventsRepository.class);
        AcceptEventInviteLinkUseCase acceptUseCase =
                mock(AcceptEventInviteLinkUseCase.class);
        Clock clock = Clock.fixed(
                Instant.parse("2025-01-01T00:00:00Z"), ZoneOffset.UTC);
        Event event = new Event(
                "event-123",
                "owner-1",
                Instant.parse("2024-12-01T00:00:00Z"),
                "Birthday",
                "celebration",
                "San Jose",
                Instant.parse("2025-01-02T18:00:00Z"),
                Instant.parse("2025-01-02T22:00:00Z"),
                null,
                true,
                true,
                List.of(),
                "123456");
        when(eventsRepository.findByEventCode("123456"))
                .thenReturn(Optional.of(event));
        JoinEventByCodeUseCase useCase =
                new JoinEventByCodeUseCase(eventsRepository, acceptUseCase, clock);

        Event joined = useCase.execute(
                "guest-1", "GUEST@example.com", " 123456 ");

        assertSame(event, joined);
        verify(eventsRepository).findByEventCode("123456");
        verify(acceptUseCase).execute("guest-1", "guest@example.com", event);
    }
}
