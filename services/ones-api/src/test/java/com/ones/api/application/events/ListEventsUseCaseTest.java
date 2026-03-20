package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;

class ListEventsUseCaseTest {

    @Test
    void includesAcceptedInvitedEventsEvenIfInPast() {
        EventsRepository events = new InMemoryEventsRepository();
        InvitationsRepository invitations = new InMemoryInvitationsRepository(List.of(
                new Invitation(
                        "event-guest-1",
                        "guest@example.com",
                        "guest-user-id",
                        "owner-1",
                        Invitation.Status.accepted,
                        Instant.parse("2025-01-01T00:00:00Z"),
                        Instant.parse("2025-01-01T00:00:00Z"),
                        "Past Event",
                        null,
                        Instant.parse("2025-01-01T18:00:00Z"),
                        Instant.parse("2025-01-01T22:00:00Z")
                )
        ));

        ((InMemoryEventsRepository) events).save(new Event(
                "event-guest-1",
                "owner-1",
                Instant.parse("2025-01-01T00:00:00Z"),
                "Past Event",
                "objective",
                "location",
                Instant.parse("2025-01-01T18:00:00Z"),
                Instant.parse("2025-01-01T22:00:00Z"),
                null,
                true
        ));

        Clock clock = Clock.fixed(Instant.parse("2026-01-01T00:00:00Z"), ZoneOffset.UTC);
        ListEventsUseCase useCase = new ListEventsUseCase(events, invitations, clock);

        List<Event> out = useCase.execute("guest-user-id", "guest@example.com", 50);

        assertEquals(1, out.size());
        assertEquals("event-guest-1", out.get(0).getEventId());
    }

    private static class InMemoryEventsRepository implements EventsRepository {
        private final Map<String, Event> items = new HashMap<>();

        @Override
        public Event save(Event event) {
            items.put(event.getEventId(), event);
            return event;
        }

        @Override
        public Optional<Event> findById(String eventId) {
            return Optional.ofNullable(items.get(eventId));
        }

        @Override
        public List<Event> findByIds(List<String> eventIds) {
            if (eventIds == null || eventIds.isEmpty()) {
                return List.of();
            }
            return eventIds.stream()
                    .filter(id -> id != null && !id.isBlank())
                    .map(items::get)
                    .filter(e -> e != null)
                    .toList();
        }

        @Override
        public List<Event> listByOwnerId(String ownerId, int limit) {
            return items.values().stream()
                    .filter(e -> ownerId.equals(e.getOwnerId()))
                    .limit(limit)
                    .toList();
        }
    }

    private record InMemoryInvitationsRepository(List<Invitation> items) implements InvitationsRepository {
        @Override
        public Optional<Invitation> findByInviteeEmailAndEventId(String inviteeEmail, String eventId) {
            throw new UnsupportedOperationException();
        }

        @Override
        public Invitation upsert(Invitation invitation) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Invitation> listByInviteeEmail(String inviteeEmail, int limit) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Invitation> listByEventId(String eventId, int limit) {
            throw new UnsupportedOperationException();
        }

        @Override
        public List<Invitation> listAcceptedByInviteeEmail(String inviteeEmail, int limit) {
            if (inviteeEmail == null) {
                return List.of();
            }
            String normalized = inviteeEmail.trim().toLowerCase();
            return items.stream()
                    .filter(i -> i.getInviteeEmail() != null && i.getInviteeEmail().trim().toLowerCase().equals(normalized))
                    .filter(i -> i.getStatus() == Invitation.Status.accepted)
                    .limit(limit)
                    .toList();
        }
    }
}
