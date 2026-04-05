package com.ones.api.application.eventtemplates;

public class EventTemplateNotFoundException extends RuntimeException {
    public EventTemplateNotFoundException(String eventTemplateId) {
        super("EventTemplate not found: " + eventTemplateId);
    }
}
