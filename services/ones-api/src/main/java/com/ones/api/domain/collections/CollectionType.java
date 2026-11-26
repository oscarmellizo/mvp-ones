package com.ones.api.domain.collections;

public enum CollectionType {
    PRIVATE,
    COUPLE,
    FAMILY,
    FRIENDS,
    PROJECTS,
    OTHER;

    public static CollectionType from(String value) {
        if (value == null || value.isBlank()) {
            throw new IllegalArgumentException("Collection type is required");
        }
        try {
            return valueOf(value.trim().toUpperCase());
        } catch (IllegalArgumentException e) {
            throw new IllegalArgumentException("Unsupported collection type");
        }
    }
}
