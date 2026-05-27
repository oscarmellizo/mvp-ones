package com.ones.api.application.events.invitelink;

import com.ones.api.application.events.EventForbiddenException;
import com.ones.api.application.events.EventNotFoundException;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

public class SetEventInviteLinkEnabledUseCase {

    private final EventsRepository repository;

    public SetEventInviteLinkEnabledUseCase(EventsRepository repository) {
        this.repository = repository;
    }

    public Event execute(String requesterUserId, String eventId, boolean enabled) {
        if (requesterUserId == null || requesterUserId.isBlank()) {
            throw new IllegalArgumentException("Missing requesterUserId");
        }
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("Missing eventId");
        }

        Event existing = repository.findById(eventId.trim())
                .orElseThrow(() -> new EventNotFoundException(eventId));

        if (!requesterUserId.trim().equals(existing.getOwnerId())) {
            throw new EventForbiddenException(eventId);
        }

        Event updated = new Event(
                existing.getEventId(),
                existing.getOwnerId(),
                existing.getCreatedAt(),
                existing.getTitle(),
                existing.getObjective(),
                existing.getLocation(),
                existing.getStartAt(),
                existing.getEndAt(),
                existing.getCoverKey(),
                existing.isAllowGuestInvites(),
                enabled,
                existing.getFrameIds()
        );

        return repository.save(updated);
    }
}
