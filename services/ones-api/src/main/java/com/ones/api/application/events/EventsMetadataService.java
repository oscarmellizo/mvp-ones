package com.ones.api.application.events;

import java.util.List;

import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;

import com.ones.api.configuration.CacheConfig;
import com.ones.api.configuration.EventsMetadataProperties;

@Service
public class EventsMetadataService {

    private final EventsMetadataProperties properties;

    public EventsMetadataService(EventsMetadataProperties properties) {
        this.properties = properties;
    }

    @Cacheable(CacheConfig.EVENTS_METADATA_CACHE)
    public EventsMetadataResponse getMetadata() {
        List<EventsMetadataResponse.Category> categories = (properties.getCategories() == null
                ? List.<EventsMetadataProperties.Category>of()
                : properties.getCategories())
                .stream()
                .map(c -> new EventsMetadataResponse.Category(
                        c.getId(),
                        c.getLabel(),
                        (c.getEventTypes() == null ? List.<EventsMetadataProperties.EventType>of() : c.getEventTypes())
                                .stream()
                                .map(t -> new EventsMetadataResponse.EventType(t.getId(), t.getLabel()))
                                .toList()
                ))
                .toList();

        return new EventsMetadataResponse(categories);
    }

    public record EventsMetadataResponse(List<Category> categories) {
        public record Category(String id, String label, List<EventType> eventTypes) {
        }

        public record EventType(String id, String label) {
        }
    }
}
