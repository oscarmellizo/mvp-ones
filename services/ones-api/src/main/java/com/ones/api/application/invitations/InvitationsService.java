package com.ones.api.application.invitations;

import java.time.Clock;
import java.time.Instant;
import java.util.List;

import com.ones.api.application.invitations.email.InvitationActionTokenService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.domain.invitations.Invitation;

public class InvitationsService {

    private static final Logger log = LoggerFactory.getLogger(InvitationsService.class);

    private final InvitationsRepository repository;
    private final Clock clock;
    private final InvitationActionTokenService tokenService;
    private final com.ones.api.application.events.bus.DomainEventPublisher eventPublisher;

    public InvitationsService(InvitationsRepository repository, Clock clock, InvitationActionTokenService tokenService) {
        this(repository, clock, tokenService, null);
    }

    public InvitationsService(InvitationsRepository repository, Clock clock, InvitationActionTokenService tokenService, com.ones.api.application.events.bus.DomainEventPublisher eventPublisher) {
        this.repository = repository;
        this.clock = clock;
        this.tokenService = tokenService;
        this.eventPublisher = eventPublisher;
    }

    public List<Invitation> listByInviteeEmail(String inviteeEmail, int limit) {
        Instant now = Instant.now(clock);
        List<Invitation> out = repository.listByInviteeEmail(inviteeEmail, limit).stream()
                .filter(i -> i != null)
                .filter(i -> i.getStatus() == Invitation.Status.invited)
                .filter(i -> i.getEventEndAt() != null && now.isBefore(i.getEventEndAt()))
                .toList();
        log.info("List actionable invitations for email={}, count={}", inviteeEmail, out.size());
        return out;
    }

    public Invitation accept(String inviteeEmail, String inviteeUserId, String eventId) {
        return respond(inviteeEmail, inviteeUserId, eventId, Invitation.Status.accepted);
    }

    public Invitation reject(String inviteeEmail, String inviteeUserId, String eventId) {
        return respond(inviteeEmail, inviteeUserId, eventId, Invitation.Status.rejected);
    }

    public Invitation resolveFromEmailLink(String authenticatedEmail, String token) {
        if (authenticatedEmail == null || authenticatedEmail.isBlank()) {
            throw new IllegalArgumentException("Missing authenticatedEmail");
        }

        InvitationActionTokenService.Decoded decoded = tokenService.decodeAndValidate(token);
        if (!authenticatedEmail.trim().equalsIgnoreCase(decoded.inviteeEmail())) {
            throw new IllegalArgumentException("Token does not belong to authenticated user");
        }

        Invitation inv = repository.findByInviteeEmailAndEventId(decoded.inviteeEmail(), decoded.eventId())
                .orElseThrow(() -> new IllegalArgumentException("Invitation not found"));

        Instant now = Instant.now(clock);
        if (inv.getStatus() != Invitation.Status.invited) {
            throw new IllegalArgumentException("Invitation is not actionable");
        }
        if (inv.getEventEndAt() == null || !now.isBefore(inv.getEventEndAt())) {
            throw new IllegalArgumentException("Invitation has expired");
        }
        return inv;
    }

    public Invitation acceptFromEmail(String inviteeEmail, String eventId) {
        return respond(inviteeEmail, null, eventId, Invitation.Status.accepted);
    }

    public Invitation rejectFromEmail(String inviteeEmail, String eventId) {
        return respond(inviteeEmail, null, eventId, Invitation.Status.rejected);
    }

    private Invitation respond(String inviteeEmail, String inviteeUserId, String eventId, Invitation.Status status) {
        Invitation existing = repository.findByInviteeEmailAndEventId(inviteeEmail, eventId)
                .orElseThrow(() -> new InvitationNotFoundException(eventId));

        Instant now = Instant.now(clock);
        if (now.isAfter(existing.getEventEndAt())) {
            throw new InvitationClosedException(eventId);
        }

        if (existing.getStatus() == status) {
            return existing;
        }

        Invitation updated = new Invitation(
                existing.getEventId(),
                existing.getInviteeEmail(),
                inviteeUserId != null && !inviteeUserId.isBlank() ? inviteeUserId : existing.getInviteeUserId(),
                existing.getEventOwnerId(),
                status,
                existing.getCreatedAt(),
                now,
                existing.getEventTitle(),
                existing.getEventLocation(),
                existing.getEventStartAt(),
                existing.getEventEndAt()
        );

        Invitation saved = repository.upsert(updated);
        try {
            if (eventPublisher != null) {
                eventPublisher.publishInvitationResponded(saved);
            }
        } catch (Exception ignored) {}
        return saved;
    }
}
