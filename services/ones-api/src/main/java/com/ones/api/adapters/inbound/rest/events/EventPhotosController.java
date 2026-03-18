package com.ones.api.adapters.inbound.rest.events;

import java.time.Instant;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.photos.PhotosService;
import com.ones.api.domain.photos.Photo;

@RestController
@RequestMapping("/v1/events")
public class EventPhotosController {

    private final PhotosService photosService;

    public EventPhotosController(PhotosService photosService) {
        this.photosService = photosService;
    }

    @PostMapping("/{eventId}/photos/presign")
    public PhotosService.PresignPutResult presign(
            Authentication authentication,
            @PathVariable("eventId") String eventId,
            @Valid @RequestBody PresignPhotoRequest request
    ) {
        String userId = authentication.getName();
        String email = AuthClaims.requireEmail(authentication);

        return photosService.presignPut(
                userId,
                email,
                eventId,
                request.photoId(),
                request.contentType()
        );
    }

    @PostMapping("/{eventId}/photos/complete")
    public Photo complete(
            Authentication authentication,
            @PathVariable("eventId") String eventId,
            @Valid @RequestBody CompletePhotoRequest request
    ) {
        String userId = authentication.getName();
        String email = AuthClaims.requireEmail(authentication);

        Instant createdAt = null;
        if (request.createdAt() != null && !request.createdAt().isBlank()) {
            createdAt = Instant.parse(request.createdAt().trim());
        }

        return photosService.complete(
                userId,
                email,
                eventId,
                request.photoId(),
                createdAt,
                request.s3KeyOriginal()
        );
    }

    @GetMapping("/{eventId}/photos")
    public PhotosService.ListPage list(
            Authentication authentication,
            @PathVariable("eventId") String eventId,
            @RequestParam(value = "limit", required = false, defaultValue = "10") int limit,
            @RequestParam(value = "nextToken", required = false) String nextToken,
            @RequestParam(value = "scope", required = false) String scope,
            @RequestParam(value = "filter", required = false) String filter,
            @RequestParam(value = "guestIds", required = false) List<String> guestIds
    ) {
        String userId = authentication.getName();
        String email = AuthClaims.requireEmail(authentication);

        return photosService.list(userId, email, eventId, limit, nextToken, scope, filter, guestIds);
    }

    @PostMapping("/{eventId}/photos/{photoId}/ready")
    public Photo ready(
            Authentication authentication,
            @PathVariable("eventId") String eventId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody MarkReadyRequest request
    ) {
        String userId = authentication.getName();
        String email = AuthClaims.requireEmail(authentication);

        return photosService.markReady(userId, email, eventId, photoId, request.s3KeyMedium(), request.s3KeySmall());
    }

    @PostMapping("/{eventId}/photos/share")
    public List<Photo> share(
            Authentication authentication,
            @PathVariable("eventId") String eventId,
            @Valid @RequestBody SharePhotosRequest request
    ) {
        String userId = authentication.getName();
        String email = AuthClaims.requireEmail(authentication);
        return photosService.sharePhotos(userId, email, eventId, request.photoIds());
    }
}

record PresignPhotoRequest(
        @NotBlank String photoId,
        String contentType
) {
}

record CompletePhotoRequest(
        @NotBlank String photoId,
        @NotBlank String s3KeyOriginal,
        String createdAt
) {
}

record MarkReadyRequest(
        String s3KeyMedium,
        String s3KeySmall
) {
}

record SharePhotosRequest(
        List<String> photoIds
) {
}
