package com.ones.api.application.events.ports;

import java.util.List;
import java.util.Optional;

import com.ones.api.domain.events.Event;

public interface EventsRepository {

    Event save(Event event);

    Optional<Event> findById(String eventId);

    List<Event> findByIds(List<String> eventIds);

    List<Event> listByOwnerId(String ownerId, int limit);

    void deleteById(String eventId);
}
