package com.ones.api.application.events;

import java.time.Instant;
import java.util.List;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.domain.events.Event;

public class UpdateEventUseCase {

    private static final Logger log = LoggerFactory.getLogger(UpdateEventUseCase.class);

    private final EventsRepository repository;
    private final EventCoversService coversService;

    public UpdateEventUseCase(EventsRepository repository, EventCoversService coversService) {
        this.repository = repository;
        this.coversService = coversService;
    }

    public Event execute(
            String requesterUserId,
            String eventId,
            String title,
            String objective,
            String location,
            Instant startAt,
            Instant endAt,
            String coverReservationId,
            Boolean allowGuestInvites,
            List<String> frameIds
    ) {
        if (requesterUserId == null || requesterUserId.isBlank()) {
            throw new IllegalArgumentException("Missing requesterUserId");
        }
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("Missing eventId");
        }

        Event existing = repository.findById(eventId.trim()).orElseThrow(() -> new EventNotFoundException(eventId));

        if (!requesterUserId.trim().equals(existing.getOwnerId())) {
            throw new EventForbiddenException(eventId);
        }

        String nextCoverKey = existing.getCoverKey();
        boolean coverChanged = false;
        if (coverReservationId != null && !coverReservationId.isBlank()) {
            if (coversService == null) {
                throw new IllegalStateException("EventCoversService is not configured");
            }
            nextCoverKey = coversService.consumeReservationAndCopyToEvent(existing.getOwnerId(), coverReservationId.trim(), existing.getEventId());
            coverChanged = true;
        }

        boolean nextAllowGuestInvites = allowGuestInvites == null ? existing.isAllowGuestInvites() : allowGuestInvites;
        List<String> nextFrameIds = frameIds == null ? existing.getFrameIds() : frameIds;

        Event updated = new Event(
                existing.getEventId(),
                existing.getOwnerId(),
                existing.getCreatedAt(),
                title,
                objective,
                location,
                startAt,
                endAt,
                nextCoverKey,
                nextAllowGuestInvites,
                existing.isInviteLinkEnabled(),
                nextFrameIds
        );

        log.info("Updating event eventId={}, ownerId={}, coverChanged={}, frameCount={}",
                existing.getEventId(),
                existing.getOwnerId(),
                coverChanged,
                nextFrameIds == null ? 0 : nextFrameIds.size());

        return repository.save(updated);
    }
}
