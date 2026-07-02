package com.ones.api.application.events;

public class EventHasGuestPhotosException extends RuntimeException {

    public EventHasGuestPhotosException(String eventId) {
        super("Event has photos from other guests and cannot be deleted: eventId=" + eventId);
    }
}
