package com.ones.api.application.events.bus;

import com.ones.api.domain.invitations.Invitation;

public interface DomainEventPublisher {
    void publishInvitationCreated(Invitation invitation);
}
