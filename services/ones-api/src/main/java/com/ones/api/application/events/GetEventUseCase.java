package com.ones.api.application.events;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

public class GetEventUseCase {

    private final EventsRepository repository;

    public GetEventUseCase(EventsRepository repository) {
        this.repository = repository;
    }

    public Event execute(String ownerId, String eventId) {
        return repository.findById(eventId)
                .filter(e -> e.getOwnerId().equals(ownerId))
                .orElseThrow(() -> new EventNotFoundException(eventId));
    }
}
