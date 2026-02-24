package com.ones.api.application.events;

public class EventForbiddenException extends RuntimeException {

    public EventForbiddenException(String eventId) {
        super("Forbidden for event: " + eventId);
    }
}
