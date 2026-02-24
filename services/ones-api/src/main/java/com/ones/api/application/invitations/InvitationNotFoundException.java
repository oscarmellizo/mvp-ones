package com.ones.api.application.invitations;

public class InvitationNotFoundException extends RuntimeException {
    public InvitationNotFoundException(String eventId) {
        super("Invitation not found for eventId=" + eventId);
    }
}
