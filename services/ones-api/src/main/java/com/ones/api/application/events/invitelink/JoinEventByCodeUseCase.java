package com.ones.api.application.events.invitelink;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;

import com.ones.api.application.events.EventNotFoundException;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

/**
 * Join an event by its short numeric code.
 *
 * Uses the same semantics as accepting an invite link:
 * - Event must have invite links enabled.
 * - Join is allowed until 7 days after the event's endAt.
 */
public class JoinEventByCodeUseCase {

    private final EventsRepository eventsRepository;
    private final AcceptEventInviteLinkUseCase acceptUseCase;
    private final Clock clock;

    public JoinEventByCodeUseCase(
            EventsRepository eventsRepository,
            AcceptEventInviteLinkUseCase acceptUseCase,
            Clock clock
    ) {
        this.eventsRepository = eventsRepository;
        this.acceptUseCase = acceptUseCase;
        this.clock = clock;
    }

    public Event execute(String requesterUserId, String requesterEmail, String code) {
        if (requesterUserId == null || requesterUserId.isBlank()) {
            throw new IllegalArgumentException("Missing requesterUserId");
        }
        if (requesterEmail == null || requesterEmail.isBlank()) {
            throw new IllegalArgumentException("Missing requesterEmail");
        }
        if (code == null || code.isBlank()) {
            throw new IllegalArgumentException("Missing code");
        }

        String normalizedCode = code.trim();
        Event event = eventsRepository.findByEventCode(normalizedCode)
                .orElseThrow(() -> new EventNotFoundException("Event not found for code"));

        if (!event.isInviteLinkEnabled()) {
            throw new EventInviteLinkClosedException("Invite link disabled");
        }

        Instant now = Instant.now(clock);
        Instant endAt = event.getEndAt();
        if (endAt != null) {
            Instant expiry = endAt.plus(Duration.ofDays(7));
            if (now.isAfter(expiry)) {
                throw new EventInviteLinkClosedException("Invite code expired");
            }
        }

        acceptUseCase.execute(requesterUserId, requesterEmail.trim().toLowerCase(), event);
        return event;
    }
}
