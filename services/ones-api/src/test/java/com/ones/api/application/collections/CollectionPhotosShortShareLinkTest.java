package com.ones.api.application.collections;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.events.ports.ObjectStorage;
import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.photos.CloudFrontSignedUrlService;
import com.ones.api.application.photos.ShortPhotoShareLinkService;
import com.ones.api.application.photos.ports.PhotoLikesRepository;
import com.ones.api.application.photos.ports.PhotoProcessingQueue;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.photos.Photo;
import com.ones.api.domain.photos.PhotoOwner;

class CollectionPhotosShortShareLinkTest {
    private static final Instant NOW = Instant.parse("2026-11-28T12:00:00Z");

    @Test
    void createsShortLinkWithCollectionOwnerReference() {
        String collectionId = "collection-1";
        String photoId = "photo-1";
        String userId = "member-1";
        CollectionService collections = mock(CollectionService.class);
        PhotosRepository photos = mock(PhotosRepository.class);
        ShortPhotoShareLinkService shortLinks = mock(ShortPhotoShareLinkService.class);
        when(photos.findById(photoId)).thenReturn(Optional.of(new Photo(
                photoId,
                PhotoOwner.collection(collectionId),
                userId,
                NOW,
                NOW,
                "ready",
                "colecciones/collection-1/private/photo-1.jpg",
                "colecciones/collection-1/private/photo-1_m.jpg",
                "colecciones/collection-1/private/photo-1_s.jpg",
                "Member",
                null,
                null,
                false,
                0,
                null,
                null,
                null
        )));
        Instant expiresAt = NOW.plusSeconds(86400);
        when(shortLinks.create("COLLECTION#collection-1", photoId, "medium"))
                .thenReturn(new ShortPhotoShareLinkService.SocialShareLink(
                        "https://appdev.ones.events/p/short-code", expiresAt));

        CollectionPhotosService service = new CollectionPhotosService(
                collections,
                photos,
                mock(PhotoLikesRepository.class),
                mock(PhotoProcessingQueue.class),
                mock(ObjectStoragePresigner.class),
                mock(ObjectStorage.class),
                mock(CloudFrontSignedUrlService.class),
                shortLinks,
                Clock.fixed(NOW, ZoneOffset.UTC),
                "photos",
                15
        );

        var result = service.createSocialShareLink(
                userId, collectionId, photoId, "medium");

        assertEquals("https://appdev.ones.events/p/short-code", result.url());
        assertEquals(expiresAt, result.expiresAt());
        verify(collections).get(userId, collectionId);
        verify(shortLinks).create("COLLECTION#collection-1", photoId, "medium");
    }
}
