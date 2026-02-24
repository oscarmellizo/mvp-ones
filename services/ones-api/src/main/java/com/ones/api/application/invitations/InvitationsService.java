package com.ones.api.application.invitations;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.domain.invitations.Invitation;

public class InvitationsService {

    private final InvitationsRepository repository;
    private final Clock clock;

    public InvitationsService(InvitationsRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    public List<Invitation> listByInviteeEmail(String inviteeEmail, int limit) {
        Instant now = Instant.now(clock);
        return repository.listByInviteeEmail(inviteeEmail, limit).stream()
                .filter(inv -> !now.isAfter(inv.getEventEndAt()))
                .toList();
    }

    public Invitation accept(String inviteeEmail, String inviteeUserId, String eventId) {
        return respond(inviteeEmail, inviteeUserId, eventId, Invitation.Status.accepted);
    }

    public Invitation reject(String inviteeEmail, String inviteeUserId, String eventId) {
        return respond(inviteeEmail, inviteeUserId, eventId, Invitation.Status.rejected);
    }

    private Invitation respond(String inviteeEmail, String inviteeUserId, String eventId, Invitation.Status status) {
        Invitation existing = repository.findByInviteeEmailAndEventId(inviteeEmail, eventId)
                .orElseThrow(() -> new InvitationNotFoundException(eventId));

        Instant now = Instant.now(clock);
        if (now.isAfter(existing.getEventEndAt())) {
            throw new InvitationClosedException(eventId);
        }

        Invitation updated = new Invitation(
                existing.getEventId(),
                existing.getInviteeEmail(),
                inviteeUserId,
                existing.getEventOwnerId(),
                status,
                existing.getCreatedAt(),
                now,
                existing.getEventTitle(),
                existing.getEventLocation(),
                existing.getEventStartAt(),
                existing.getEventEndAt()
        );

        return repository.upsert(updated);
    }
}
