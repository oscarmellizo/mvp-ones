package com.ones.api.application.eventtemplates.ports;

import java.util.List;
import java.util.Optional;

import com.ones.api.domain.eventtemplates.EventTemplate;

public interface EventTemplatesRepository {
    Optional<EventTemplate> findById(String eventTemplateId);

    List<EventTemplate> list(EventTemplate.Status status);

    EventTemplate upsert(EventTemplate eventTemplate);

    void deleteById(String eventTemplateId);
}
