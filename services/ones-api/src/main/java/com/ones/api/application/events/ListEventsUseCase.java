package com.ones.api.application.events;

import java.util.List;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

public class ListEventsUseCase {

    private final EventsRepository repository;

    public ListEventsUseCase(EventsRepository repository) {
        this.repository = repository;
    }

    public List<Event> execute(String ownerId, int limit) {
        return repository.listByOwnerId(ownerId, limit);
    }
}
