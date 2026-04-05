package com.ones.api.domain.eventtemplates;

import java.time.Instant;
import java.util.List;
import java.util.Objects;

public final class EventTemplate {
    private final String eventTemplateId;
    private final String name;
    private final Status status;
    private final Integer sortOrder;
    private final List<String> frameIds;
    private final Instant createdAt;
    private final Instant updatedAt;
    private final String createdBy;
    private final String updatedBy;

    public EventTemplate(
            String eventTemplateId,
            String name,
            Status status,
            Integer sortOrder,
            List<String> frameIds,
            Instant createdAt,
            Instant updatedAt,
            String createdBy,
            String updatedBy
    ) {
        this.eventTemplateId = eventTemplateId;
        this.name = name;
        this.status = status;
        this.sortOrder = sortOrder;
        this.frameIds = frameIds == null ? List.of() : List.copyOf(frameIds);
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.createdBy = createdBy;
        this.updatedBy = updatedBy;
    }

    public String getEventTemplateId() {
        return eventTemplateId;
    }

    public String getName() {
        return name;
    }

    public Status getStatus() {
        return status;
    }

    public Integer getSortOrder() {
        return sortOrder;
    }

    public List<String> getFrameIds() {
        return frameIds;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public String getCreatedBy() {
        return createdBy;
    }

    public String getUpdatedBy() {
        return updatedBy;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof EventTemplate)) return false;
        EventTemplate that = (EventTemplate) o;
        return Objects.equals(eventTemplateId, that.eventTemplateId)
                && Objects.equals(name, that.name)
                && status == that.status
                && Objects.equals(sortOrder, that.sortOrder)
                && Objects.equals(frameIds, that.frameIds)
                && Objects.equals(createdAt, that.createdAt)
                && Objects.equals(updatedAt, that.updatedAt)
                && Objects.equals(createdBy, that.createdBy)
                && Objects.equals(updatedBy, that.updatedBy);
    }

    @Override
    public int hashCode() {
        return Objects.hash(eventTemplateId, name, status, sortOrder, frameIds, createdAt, updatedAt, createdBy, updatedBy);
    }

    @Override
    public String toString() {
        return "EventTemplate{" +
                "eventTemplateId='" + eventTemplateId + '\'' +
                ", name='" + name + '\'' +
                ", status=" + status +
                ", sortOrder=" + sortOrder +
                ", frameIds=" + frameIds +
                ", createdAt=" + createdAt +
                ", updatedAt=" + updatedAt +
                ", createdBy='" + createdBy + '\'' +
                ", updatedBy='" + updatedBy + '\'' +
                '}';
    }

    public enum Status {
        active,
        inactive
    }
}
