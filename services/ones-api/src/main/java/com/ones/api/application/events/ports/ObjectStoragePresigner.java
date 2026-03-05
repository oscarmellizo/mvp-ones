package com.ones.api.application.events.ports;

import java.net.URL;
import java.time.Duration;

public interface ObjectStoragePresigner {

    URL presignGet(String bucket, String key, Duration ttl);

    URL presignPut(String bucket, String key, Duration ttl, String contentType);
}
