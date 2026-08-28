package com.ones.api.application.events.invitelink;

import java.time.Clock;
import java.time.Instant;

import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;

public class AcceptEventInviteLinkUseCase {

    private final InvitationsRepository invitationsRepository;
    private final Clock clock;
    private final com.ones.api.application.events.bus.DomainEventPublisher eventPublisher;

    public AcceptEventInviteLinkUseCase(
            InvitationsRepository invitationsRepository,
            Clock clock
    ) {
        this(invitationsRepository, clock, null);
    }

    public AcceptEventInviteLinkUseCase(
            InvitationsRepository invitationsRepository,
            Clock clock,
            com.ones.api.application.events.bus.DomainEventPublisher eventPublisher
    ) {
        this.invitationsRepository = invitationsRepository;
        this.clock = clock;
        this.eventPublisher = eventPublisher;
    }

    public Invitation execute(String requesterUserId, String requesterEmail, Event event) {
        if (requesterUserId == null || requesterUserId.isBlank()) {
            throw new IllegalArgumentException("Missing requesterUserId");
        }
        if (requesterEmail == null || requesterEmail.isBlank()) {
            throw new IllegalArgumentException("Missing requesterEmail");
        }
        if (event == null) {
            throw new IllegalArgumentException("Missing event");
        }

        String email = requesterEmail.trim().toLowerCase();
        Instant now = Instant.now(clock);

        Invitation existing = invitationsRepository.findByInviteeEmailAndEventId(email, event.getEventId()).orElse(null);
        Instant createdAt = existing != null ? existing.getCreatedAt() : now;

        Invitation inv = new Invitation(
                event.getEventId(),
                email,
                requesterUserId.trim(),
                event.getOwnerId(),
                Invitation.Status.accepted,
                createdAt,
                now,
                event.getTitle(),
                event.getLocation(),
                event.getStartAt(),
                event.getEndAt()
        );

        Invitation saved = invitationsRepository.upsert(inv);
        try {
            if (eventPublisher != null) {
                eventPublisher.publishInvitationResponded(saved);
            }
        } catch (Exception ignored) {}
        return saved;
    }
}
