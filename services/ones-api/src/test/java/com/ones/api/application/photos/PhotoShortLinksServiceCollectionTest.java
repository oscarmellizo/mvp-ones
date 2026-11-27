package com.ones.api.application.photos;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.events.ports.ObjectStoragePresigner;
import com.ones.api.application.photos.ports.PhotoShortLinksRepository;
import com.ones.api.application.photos.ports.PhotosRepository;
import com.ones.api.domain.photos.Photo;
import com.ones.api.domain.photos.PhotoOwner;

class PhotoShortLinksServiceCollectionTest {
    private static final Instant NOW = Instant.parse("2026-11-28T12:00:00Z");

    @Test
    void resolvesCollectionShortLinksAndKeepsOwnerValidation() throws Exception {
        String code = "short-code-1";
        String photoId = "photo-1";
        String collectionId = "collection-1";
        PhotoShortLinksRepository links = mock(PhotoShortLinksRepository.class);
        PhotosRepository photos = mock(PhotosRepository.class);
        ObjectStoragePresigner presigner = mock(ObjectStoragePresigner.class);
        CloudFrontSignedUrlService cdn = mock(CloudFrontSignedUrlService.class);
        PhotoShortLinksService service = new PhotoShortLinksService(
                links,
                photos,
                presigner,
                cdn,
                Clock.fixed(NOW, ZoneOffset.UTC),
                "photos",
                7
        );
        PhotoShortLinksRepository.PhotoShortLink link =
                new PhotoShortLinksRepository.PhotoShortLink(
                        code,
                        "COLLECTION#collection-1",
                        photoId,
                        "medium",
                        NOW,
                        NOW.plusSeconds(3600)
                );
        Photo photo = new Photo(
                photoId,
                PhotoOwner.collection(collectionId),
                "member-1",
                NOW,
                NOW,
                "ready",
                "colecciones/collection-1/shared/photo-1.jpg",
                "colecciones/collection-1/shared/photo-1_m.jpg",
                "colecciones/collection-1/shared/photo-1_s.jpg",
                "Member",
                null,
                null,
                true,
                0,
                null,
                null,
                null
        );
        when(links.findByCode(code)).thenReturn(Optional.of(link));
        when(photos.findById(photoId)).thenReturn(Optional.of(photo));
        when(cdn.signForSocialShare(photo.getS3KeyMedium()))
                .thenReturn(new CloudFrontSignedUrlService.SignedUrlResult(
                        "https://cdn.example/collection-photo.jpg",
                        NOW.plusSeconds(1200)
                ));

        var resolved = service.resolve(code);

        assertTrue(resolved.isPresent());
        assertEquals("https://cdn.example/collection-photo.jpg",
                resolved.orElseThrow().imageUrl());
        verify(photos).findById(photoId);
    }

    @Test
    void doesNotResolveCollectionLinkAgainstAnotherCollection() {
        String code = "short-code-2";
        String photoId = "photo-2";
        PhotoShortLinksRepository links = mock(PhotoShortLinksRepository.class);
        PhotosRepository photos = mock(PhotosRepository.class);
        CloudFrontSignedUrlService cdn = mock(CloudFrontSignedUrlService.class);
        PhotoShortLinksService service = new PhotoShortLinksService(
                links,
                photos,
                mock(ObjectStoragePresigner.class),
                cdn,
                Clock.fixed(NOW, ZoneOffset.UTC),
                "photos",
                7
        );
        when(links.findByCode(code)).thenReturn(Optional.of(
                new PhotoShortLinksRepository.PhotoShortLink(
                        code,
                        "COLLECTION#collection-1",
                        photoId,
                        "medium",
                        NOW,
                        NOW.plusSeconds(3600)
                )
        ));
        when(photos.findById(photoId)).thenReturn(Optional.of(new Photo(
                photoId,
                PhotoOwner.collection("collection-2"),
                "member-1",
                NOW,
                NOW,
                "ready",
                "colecciones/collection-2/shared/photo-2.jpg",
                "colecciones/collection-2/shared/photo-2_m.jpg",
                "colecciones/collection-2/shared/photo-2_s.jpg",
                "Member",
                null,
                null,
                true,
                0,
                null,
                null,
                null
        )));

        assertTrue(service.resolve(code).isEmpty());
    }

    @Test
    void continuesToResolveExistingEventShortLinks() {
        String code = "event-code-1";
        String photoId = "event-photo-1";
        PhotoShortLinksRepository links = mock(PhotoShortLinksRepository.class);
        PhotosRepository photos = mock(PhotosRepository.class);
        CloudFrontSignedUrlService cdn = mock(CloudFrontSignedUrlService.class);
        PhotoShortLinksService service = new PhotoShortLinksService(
                links,
                photos,
                mock(ObjectStoragePresigner.class),
                cdn,
                Clock.fixed(NOW, ZoneOffset.UTC),
                "photos",
                7
        );
        PhotoShortLinksRepository.PhotoShortLink link =
                new PhotoShortLinksRepository.PhotoShortLink(
                        code,
                        "event-1",
                        photoId,
                        "medium",
                        NOW,
                        NOW.plusSeconds(3600)
                );
        Photo photo = new Photo(
                photoId,
                "event-1",
                "guest-1",
                NOW,
                NOW,
                "ready",
                "eventos/event-1/shared/event-photo-1.jpg",
                "eventos/event-1/shared/event-photo-1_m.jpg",
                "eventos/event-1/shared/event-photo-1_s.jpg"
        );
        when(links.findByCode(code)).thenReturn(Optional.of(link));
        when(photos.findById(photoId)).thenReturn(Optional.of(photo));
        when(cdn.signForSocialShare(photo.getS3KeyMedium()))
                .thenReturn(new CloudFrontSignedUrlService.SignedUrlResult(
                        "https://cdn.example/event-photo.jpg",
                        NOW.plusSeconds(1200)
                ));

        var resolved = service.resolve(code);

        assertTrue(resolved.isPresent());
        assertEquals("https://cdn.example/event-photo.jpg",
                resolved.orElseThrow().imageUrl());
    }
}
