package com.ones.api.application.photos;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.*;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.Test;
import com.ones.api.application.events.CreateEventUseCase;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

class FreeAccessTest {
    private final Clock clock = Clock.systemUTC();
    @Test
    void createsEventWithoutSubscriptionOrPlan() {
        var events = mock(EventsRepository.class);
        when(events.save(any())).thenAnswer(call -> call.getArgument(0));
        var service = new CreateEventUseCase(events, null, null, clock, null, null, null);
        Event event = service.execute("owner", "Free event", "birthday", "Bogota", Instant.now(),
                Instant.now().plusSeconds(3600), null, List.of(), true, List.of());
        assertEquals("owner", event.getOwnerId());
        verify(events, never()).countByOwnerId(any());
    }

    @Test
    void completesPhotoWithoutSubscriptionOrPlan() {
        var photos = mock(PhotosRepository.class);
        var access = mock(GetEventUseCase.class);
        var event = mock(Event.class);
        when(event.getEventId()).thenReturn("event");
        when(access.execute("guest", "guest@example.com", "event")).thenReturn(event);
        when(photos.upsert(any())).thenAnswer(call -> call.getArgument(0));
        var service = new PhotosService(photos, null, access, null, null, null,
                mock(com.ones.api.application.users.ports.PreferredNamesCacheRepository.class),
                null, null, null, null, clock, "photos", 15, false);
        Photo photo = service.complete("guest", "guest@example.com", "event", "photo",
                Instant.now(), "events/event/guests/guest/photo.jpg");
        assertEquals("photo", photo.getPhotoId());
        verify(photos, never()).countByEventId(any());
    }
}
