package com.ones.api.application.events.invitelink;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;

import com.ones.api.application.events.ports.SecretsProvider;

class EventInviteLinkTokenServiceTest {

    @Test
    void signatureIsDeterministicForSameEventId() {
        SecretsProvider secrets = name -> "test-secret";
        EventInviteLinkTokenService service = new EventInviteLinkTokenService(secrets, "secret-name");

        String sig1 = service.signatureForEventId("event-123");
        String sig2 = service.signatureForEventId("event-123");

        assertNotNull(sig1);
        assertEquals(sig1, sig2);
    }

    @Test
    void validateAcceptsCorrectSignature() {
        SecretsProvider secrets = name -> "test-secret";
        EventInviteLinkTokenService service = new EventInviteLinkTokenService(secrets, "secret-name");

        String sig = service.signatureForEventId("event-123");
        service.validate("event-123", sig);
    }

    @Test
    void validateRejectsInvalidSignature() {
        SecretsProvider secrets = name -> "test-secret";
        EventInviteLinkTokenService service = new EventInviteLinkTokenService(secrets, "secret-name");

        assertThrows(IllegalArgumentException.class, () -> service.validate("event-123", "bad"));
    }
}
