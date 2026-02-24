package com.ones.api.application.events;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;

public class GetEventUseCase {

    private final EventsRepository repository;
    private final InvitationsRepository invitationsRepository;

    public GetEventUseCase(EventsRepository repository, InvitationsRepository invitationsRepository) {
        this.repository = repository;
        this.invitationsRepository = invitationsRepository;
    }

    public Event execute(String ownerId, String inviteeEmail, String eventId) {
        Event event = repository.findById(eventId).orElseThrow(() -> new EventNotFoundException(eventId));

        if (event.getOwnerId().equals(ownerId)) {
            return event;
        }

        Invitation inv = invitationsRepository.findByInviteeEmailAndEventId(inviteeEmail, eventId)
                .filter(i -> i.getStatus() == Invitation.Status.accepted)
                .orElseThrow(() -> new EventNotFoundException(eventId));

        return event;
    }
}
