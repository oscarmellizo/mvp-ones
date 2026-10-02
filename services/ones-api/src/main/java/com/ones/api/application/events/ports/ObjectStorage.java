package com.ones.api.application.events.ports;

import java.io.InputStream;
import java.nio.file.Path;

public interface ObjectStorage {

    void putPng(String bucket, String key, byte[] png);

    void copy(String sourceBucket, String sourceKey, String destinationBucket, String destinationKey);

    /** Abre el objeto para lectura; lanza si no existe. El llamador debe cerrar el stream. */
    InputStream open(String bucket, String key);

    void putFile(String bucket, String key, Path file, String contentType);

    void delete(String bucket, String key);
}
