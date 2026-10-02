package com.ones.api.application.events.ports;

/** El objeto pedido no existe en el almacenamiento (S3 NoSuchKey / 404). */
public class ObjectNotFoundException extends RuntimeException {

    public ObjectNotFoundException(String bucket, String key) {
        super("No existe el objeto " + bucket + "/" + key);
    }

    public ObjectNotFoundException(String bucket, String key, Throwable cause) {
        super("No existe el objeto " + bucket + "/" + key, cause);
    }
}
