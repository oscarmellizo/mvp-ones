package com.ones.api.application.events.ports;

import java.io.InputStream;
import java.io.OutputStream;

public interface ObjectStorage {

    void putPng(String bucket, String key, byte[] png);

    void copy(String sourceBucket, String sourceKey, String destinationBucket, String destinationKey);

    /**
     * Abre el objeto para lectura. El llamador debe cerrar el stream.
     * @throws ObjectNotFoundException si el objeto no existe; cualquier otro error se propaga tal cual.
     */
    InputStream open(String bucket, String key);

    /**
     * Abre una subida en streaming (sin límite práctico de tamaño). {@code close()} la completa y deja el objeto;
     * {@code abort()} la descarta sin dejar objeto. Si una escritura falla, la subida se aborta sola.
     */
    Upload openUpload(String bucket, String key, String contentType);

    void delete(String bucket, String key);

    abstract class Upload extends OutputStream {
        /** Descarta la subida: no queda ningún objeto. Idempotente; tras abortar, close() no hace nada. */
        public abstract void abort();
    }
}
