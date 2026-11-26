package com.ones.api.application.collections;

public class CollectionForbiddenException extends RuntimeException {
    public CollectionForbiddenException(String id) {
        super("Forbidden collection access: " + id);
    }
}
