package com.ones.api.application.events;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

@Service
public class DeleteEventUseCase {

    private static final Logger log = LoggerFactory.getLogger(DeleteEventUseCase.class);

    private final EventsRepository eventsRepository;
    private final PhotosRepository photosRepository;
    private final EventPurger eventPurger;

    public DeleteEventUseCase(
            EventsRepository eventsRepository,
            PhotosRepository photosRepository,
            EventPurger eventPurger
    ) {
        this.eventsRepository = eventsRepository;
        this.photosRepository = photosRepository;
        this.eventPurger = eventPurger;
    }

    public void execute(String requesterUserId, String eventId) {
        if (requesterUserId == null || requesterUserId.isBlank()) {
            throw new IllegalArgumentException("Missing requesterUserId");
        }
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("Missing eventId");
        }

        Event event = eventsRepository.findById(eventId.trim())
                .orElseThrow(() -> new EventNotFoundException(eventId));

        if (!requesterUserId.trim().equals(event.getOwnerId())) {
            throw new EventForbiddenException(eventId);
        }

        String nextToken = null;
        do {
            PhotosRepository.PageResult<Photo> page =
                    photosRepository.listByEventId(event.getEventId(), 50, nextToken);
            for (Photo photo : page.items()) {
                if (!event.getOwnerId().equals(photo.getGuestId())) {
                    throw new EventHasGuestPhotosException(eventId);
                }
            }
            nextToken = page.nextToken();
        } while (nextToken != null && !nextToken.isBlank());

        int deleted = eventPurger.purge(event);

        log.info("[DeleteEventUseCase] deleted eventId={} ownerId={} photos={}", eventId, requesterUserId, deleted);
    }
}
