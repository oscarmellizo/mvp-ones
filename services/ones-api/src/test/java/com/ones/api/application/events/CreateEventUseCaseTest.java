package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

class CreateEventUseCaseTest {

    @Test
    void createsEventWithOwnerAndTitle() {
        EventsRepository repo = new InMemoryEventsRepository();
        Clock clock = Clock.fixed(Instant.parse("2025-01-01T00:00:00Z"), ZoneOffset.UTC);

        CreateEventUseCase useCase = new CreateEventUseCase(repo, clock);
        Event created = useCase.execute("user-123", "Hello");

        assertNotNull(created.getEventId());
        assertEquals("user-123", created.getOwnerId());
        assertEquals("Hello", created.getTitle());
        assertEquals(Instant.parse("2025-01-01T00:00:00Z"), created.getCreatedAt());
    }

    private static class InMemoryEventsRepository implements EventsRepository {
        private Event last;

        @Override
        public Event save(Event event) {
            this.last = event;
            return event;
        }

        @Override
        public Optional<Event> findById(String eventId) {
            return Optional.ofNullable(last).filter(e -> e.getEventId().equals(eventId));
        }

        @Override
        public java.util.List<Event> listByOwnerId(String ownerId, int limit) {
            return last != null && last.getOwnerId().equals(ownerId) ? java.util.List.of(last) : java.util.List.of();
        }
    }
}
