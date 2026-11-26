package com.ones.api.application.collections;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import org.junit.jupiter.api.Test;

class CollectionJoinTokenServiceTest {
    private final CollectionJoinTokenService service = new CollectionJoinTokenService();

    @Test
    void generatedBearerTokenIsValidatedByItsStoredHash() {
        String token = service.create();
        String hash = service.hash(token);

        assertTrue(service.matches(hash, token));
        assertFalse(service.matches(hash, token + "x"));
        assertFalse(service.matches(null, token));
    }
}
