package com.ones.api.application.collections.ports;

public interface CollectionDeletionQueue {
    void enqueue(String collectionId);
}
