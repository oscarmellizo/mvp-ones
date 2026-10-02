package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.photos.ports.PhotoLikesRepository;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.photos.Photo;

class EventPurgerTest {

    private static final Instant NOW = Instant.parse("2026-01-01T00:00:00Z");

    private EventsRepository events;
    private PhotosRepository photos;
    private PhotoLikesRepository likes;
    private InvitationsRepository invitations;
    private ObjectStorage storage;
    private EventPurger purger;

    @BeforeEach
    void setUp() {
        events = mock(EventsRepository.class);
        photos = mock(PhotosRepository.class);
        likes = mock(PhotoLikesRepository.class);
        invitations = mock(InvitationsRepository.class);
        storage = mock(ObjectStorage.class);
        purger = new EventPurger(events, photos, likes, invitations, storage, "photos", "covers");
    }

    private static Event event(String id, String owner, String coverKey) {
        return new Event(id, owner, NOW, "t", "o", "l", NOW, NOW.plusSeconds(60), coverKey, true, true, List.of());
    }

    private static Photo photo(String id, String eventId, String guest) {
        String base = "eventos/" + eventId + "/guests/" + guest + "/private/" + id;
        return new Photo(id, eventId, guest, NOW, NOW, "uploaded", base + ".jpg", base + "_m.jpg", base + "_s.jpg");
    }

    private void listing(String eventId, Photo... items) {
        when(photos.listByEventId(eq(eventId), anyInt(), any()))
                .thenReturn(new PhotosRepository.PageResult<>(List.of(items), null));
    }

    @Test
    void purge_deletesGuestPhotosToo() {
        Event event = event("e1", "owner", "covers/e1.png");
        listing("e1", photo("p1", "e1", "owner"), photo("p2", "e1", "guest"));

        int deleted = purger.purge(event);

        assertEquals(2, deleted);
        verify(storage).delete("photos", "eventos/e1/guests/guest/private/p2.jpg");
        verify(storage).delete("photos", "eventos/e1/guests/guest/private/p2_m.jpg");
        verify(storage).delete("photos", "eventos/e1/guests/guest/private/p2_s.jpg");
        verify(storage).delete("covers", "covers/e1.png");
        verify(likes).deleteAllByPhotoId("p2");
        verify(photos).deleteById("p1");
        verify(photos).deleteById("p2");
        verify(invitations).deleteAllByEventId("e1");
        verify(events).deleteById("e1");
    }

    @Test
    void purge_whenOnePhotoFails_purgesTheOthersKeepsFailingRecordAndEvent() {
        Event event = event("e1", "owner", "covers/e1.png");
        listing("e1", photo("p1", "e1", "owner"), photo("p2", "e1", "guest"));
        doThrow(new RuntimeException("s3 down"))
                .when(storage).delete(eq("photos"), eq("eventos/e1/guests/owner/private/p1_m.jpg"));

        assertThrows(IllegalStateException.class, () -> purger.purge(event));

        verify(photos).deleteById("p2");
        verify(photos, never()).deleteById("p1");
        verify(likes, never()).deleteAllByPhotoId("p1");
        verify(storage, never()).delete(eq("covers"), anyString());
        verify(invitations, never()).deleteAllByEventId(anyString());
        verify(events, never()).deleteById(anyString());
    }

    @Test
    void purge_whenCoverDeleteFails_throwsAndKeepsEvent() {
        Event event = event("e1", "owner", "covers/e1.png");
        listing("e1");
        doThrow(new RuntimeException("s3 down")).when(storage).delete("covers", "covers/e1.png");

        assertThrows(RuntimeException.class, () -> purger.purge(event));

        verify(invitations, never()).deleteAllByEventId(anyString());
        verify(events, never()).deleteById(anyString());
    }

    @Test
    void purgePhoto_whenLikesDeleteFails_keepsPhotoRecord() {
        doThrow(new RuntimeException("ddb")).when(likes).deleteAllByPhotoId("p1");

        assertThrows(RuntimeException.class, () -> purger.purgePhoto(photo("p1", "e1", "owner")));

        verify(photos, never()).deleteById(anyString());
    }
}
