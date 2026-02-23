package com.ones.api.application.events;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

public class CreateEventUseCase {

    private final EventsRepository repository;
    private final Clock clock;
    private final EventCoversService coversService;

    public CreateEventUseCase(EventsRepository repository, Clock clock, EventCoversService coversService) {
        this.repository = repository;
        this.clock = clock;
        this.coversService = coversService;
    }

    public Event execute(
            String ownerId,
            String title,
            String objective,
            String location,
            Instant startAt,
            Instant endAt,
            String coverReservationId
    ) {
        String eventId = UUID.randomUUID().toString();
        Instant createdAt = Instant.now(clock);

        String coverKey = null;
        if (coverReservationId != null && !coverReservationId.isBlank()) {
            if (coversService == null) {
                throw new IllegalStateException("EventCoversService is not configured");
            }
            coverKey = coversService.consumeReservationAndCopyToEvent(ownerId, coverReservationId.trim(), eventId);
        }

        Event event = new Event(eventId, ownerId, createdAt, title, objective, location, startAt, endAt, coverKey);
        return repository.save(event);
    }
}
