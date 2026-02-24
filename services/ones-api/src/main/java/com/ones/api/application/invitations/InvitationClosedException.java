package com.ones.api.application.invitations;

public class InvitationClosedException extends RuntimeException {
    public InvitationClosedException(String eventId) {
        super("Invitation can no longer be updated because the event has ended (eventId=" + eventId + ")");
    }
}
