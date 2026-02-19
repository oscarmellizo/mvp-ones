package com.ones.api.application.events;

public class EventCoverNotFoundException extends RuntimeException {

    public EventCoverNotFoundException(String eventId) {
        super("Event cover not found for event: " + eventId);
    }
}
