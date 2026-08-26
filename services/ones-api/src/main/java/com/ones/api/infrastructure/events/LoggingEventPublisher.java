package com.ones.api.infrastructure.events;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Component;

import com.ones.api.application.events.bus.DomainEventPublisher;
import com.ones.api.domain.invitations.Invitation;

@Component
public class LoggingEventPublisher implements DomainEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(LoggingEventPublisher.class);

    @Override
    public void publishInvitationCreated(Invitation invitation) {
        if (invitation == null) return;
        log.info("[DomainEvent] InvitationCreated eventId={} inviteeEmail={} ownerId={}",
                invitation.getEventId(), invitation.getInviteeEmail(), invitation.getEventOwnerId());
    }
}
