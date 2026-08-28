package com.ones.api.application.events.bus;

import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.events.Event;

public interface DomainEventPublisher {
    void publishInvitationCreated(Invitation invitation);
    void publishInvitationResponded(Invitation invitation);
    void publishEventUpdated(Event previous, Event updated);
}
