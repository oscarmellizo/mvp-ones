package com.ones.api.application.collections;

public class CollectionNotFoundException extends RuntimeException {
    public CollectionNotFoundException(String id) {
        super("Collection not found: " + id);
    }
}
