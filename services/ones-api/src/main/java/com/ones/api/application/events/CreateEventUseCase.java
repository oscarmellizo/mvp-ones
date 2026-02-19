package com.ones.api.application.events;

import java.time.Clock;
import java.time.Instant;
import java.util.UUID;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

public class CreateEventUseCase {

    private final EventsRepository repository;
    private final Clock clock;

    public CreateEventUseCase(EventsRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    public Event execute(String ownerId, String title, String eventTypeId, String location, Instant startAt, Instant endAt) {
        String eventId = UUID.randomUUID().toString();
        Instant createdAt = Instant.now(clock);

        Event event = new Event(eventId, ownerId, createdAt, title, eventTypeId, location, startAt, endAt);
        return repository.save(event);
    }
}
