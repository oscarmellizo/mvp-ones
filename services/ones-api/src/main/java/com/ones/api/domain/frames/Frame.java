package com.ones.api.domain.frames;

import java.time.Instant;

public class Frame {

    public enum Status {
        active,
        inactive
    }

    private final String frameId;
    private final String name;
    private final Status status;
    private final Integer sortOrder;
    private final String verticalAssetKey;
    private final String horizontalAssetKey;
    private final Instant createdAt;
    private final Instant updatedAt;
    private final String createdBy;
    private final String updatedBy;

    public Frame(
            String frameId,
            String name,
            Status status,
            Integer sortOrder,
            String verticalAssetKey,
            String horizontalAssetKey,
            Instant createdAt,
            Instant updatedAt,
            String createdBy,
            String updatedBy
    ) {
        this.frameId = frameId;
        this.name = name;
        this.status = status;
        this.sortOrder = sortOrder;
        this.verticalAssetKey = verticalAssetKey;
        this.horizontalAssetKey = horizontalAssetKey;
        this.createdAt = createdAt;
        this.updatedAt = updatedAt;
        this.createdBy = createdBy;
        this.updatedBy = updatedBy;
    }

    public String getFrameId() {
        return frameId;
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

    public String getVerticalAssetKey() {
        return verticalAssetKey;
    }

    public String getHorizontalAssetKey() {
        return horizontalAssetKey;
    }

    public String getAssetKey() {
        return verticalAssetKey;
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
}
