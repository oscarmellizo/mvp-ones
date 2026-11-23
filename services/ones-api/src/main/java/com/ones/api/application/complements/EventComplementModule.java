package com.ones.api.application.complements;

public interface EventComplementModule {

    String id();

    String displayName();

    String defaultTabLabel();

    void initialize(String eventId, String ownerId);
}
