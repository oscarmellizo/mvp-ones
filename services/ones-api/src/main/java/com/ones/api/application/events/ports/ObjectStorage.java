package com.ones.api.application.events.ports;

public interface ObjectStorage {

    void putPng(String bucket, String key, byte[] png);

    void copy(String sourceBucket, String sourceKey, String destinationBucket, String destinationKey);

    void delete(String bucket, String key);
}
