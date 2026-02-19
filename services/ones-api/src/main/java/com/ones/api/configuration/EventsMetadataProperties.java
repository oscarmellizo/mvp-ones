package com.ones.api.configuration;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "ones.events.metadata")
public class EventsMetadataProperties {

    private List<Category> categories = new ArrayList<>();

    public List<Category> getCategories() {
        return categories;
    }

    public void setCategories(List<Category> categories) {
        this.categories = categories;
    }

    public static class Category {
        private String id;
        private String label;
        private List<EventType> eventTypes = new ArrayList<>();

        public String getId() {
            return id;
        }

        public void setId(String id) {
            this.id = id;
        }

        public String getLabel() {
            return label;
        }

        public void setLabel(String label) {
            this.label = label;
        }

        public List<EventType> getEventTypes() {
            return eventTypes;
        }

        public void setEventTypes(List<EventType> eventTypes) {
            this.eventTypes = eventTypes;
        }
    }

    public static class EventType {
        private String id;
        private String label;

        public String getId() {
            return id;
        }

        public void setId(String id) {
            this.id = id;
        }

        public String getLabel() {
            return label;
        }

        public void setLabel(String label) {
            this.label = label;
        }
    }

    public Map<String, List<EventType>> toEventTypesByCategoryId() {
        Map<String, List<EventType>> out = new LinkedHashMap<>();
        if (categories == null) return out;
        for (Category c : categories) {
            out.put(c.getId(), c.getEventTypes() == null ? List.of() : c.getEventTypes());
        }
        return out;
    }
}
