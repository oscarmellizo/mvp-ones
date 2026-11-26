package com.ones.api.application.collections;

public class CollectionJoinRateLimitException extends RuntimeException {
    public CollectionJoinRateLimitException() {
        super("Too many QR join attempts");
    }
}
