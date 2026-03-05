package com.ones.api.application.invitations;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.domain.invitations.Invitation;

public class InvitationsService {

    private static final Logger log = LoggerFactory.getLogger(InvitationsService.class);

    private final InvitationsRepository repository;
    private final Clock clock;

    public InvitationsService(InvitationsRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    public List<Invitation> listByInviteeEmail(String inviteeEmail, int limit) {
        List<Invitation> out = repository.listByInviteeEmail(inviteeEmail, limit);
        log.info("List invitations for email={}, count={}", inviteeEmail, out.size());
        return out;
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
