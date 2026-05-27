package com.ones.api.application.events.invitelink;

import java.time.Clock;
import java.time.Instant;

import com.ones.api.application.events.EventNotFoundException;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

public class PreviewEventInviteLinkUseCase {

    private final EventsRepository eventsRepository;
    private final Clock clock;

    public PreviewEventInviteLinkUseCase(EventsRepository eventsRepository, Clock clock) {
        this.eventsRepository = eventsRepository;
        this.clock = clock;
    }

    public Event execute(String eventId) {
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("Missing eventId");
        }

        Event event = eventsRepository.findById(eventId.trim())
                .orElseThrow(() -> new EventNotFoundException(eventId));

        if (!event.isInviteLinkEnabled()) {
            throw new EventInviteLinkClosedException("Invite link disabled");
        }

        Instant now = Instant.now(clock);
        if (event.getEndAt() == null || !now.isBefore(event.getEndAt())) {
            throw new EventInviteLinkClosedException("Invite link expired");
        }

        return event;
    }
}
