package com.ones.api.application.photos;

import java.time.Clock;
import java.time.Instant;

import org.springframework.stereotype.Service;

import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.photos.ports.PhotoLikesRepository;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

@Service
public class PhotoLikesService {

    private final GetEventUseCase getEventUseCase;
    private final PhotosRepository photosRepository;
    private final PhotoLikesRepository likesRepository;
    private final Clock clock;

    public PhotoLikesService(
            GetEventUseCase getEventUseCase,
            PhotosRepository photosRepository,
            PhotoLikesRepository likesRepository,
            Clock clock
    ) {
        this.getEventUseCase = getEventUseCase;
        this.photosRepository = photosRepository;
        this.likesRepository = likesRepository;
        this.clock = clock;
    }

    public boolean like(String requesterUserId, String requesterEmail, String eventId, String photoId) {
        Event event = getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        Photo p = photosRepository.findById(photoId)
                .orElse(null);
        if (p == null || p.getEventId() == null || !p.getEventId().equals(event.getEventId())) {
            return false;
        }

        likesRepository.like(event.getEventId(), photoId, requesterUserId, Instant.now(clock));
        return true;
    }

    public boolean unlike(String requesterUserId, String requesterEmail, String eventId, String photoId) {
        Event event = getEventUseCase.execute(requesterUserId, requesterEmail, eventId);

        Photo p = photosRepository.findById(photoId)
                .orElse(null);
        if (p == null || p.getEventId() == null || !p.getEventId().equals(event.getEventId())) {
            return false;
        }

        likesRepository.unlike(photoId, requesterUserId);
        return true;
    }
}
