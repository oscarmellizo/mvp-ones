package com.ones.api.adapters.inbound.rest.collections;

import java.time.Instant;
import java.util.List;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.collections.CollectionPhotosService;
import com.ones.api.application.photos.PhotosService;
import com.ones.api.domain.photos.Photo;

@RestController
@RequestMapping("/v1/collections/{collectionId}/photos")
public class CollectionPhotosController {
    private final CollectionPhotosService photos;

    public CollectionPhotosController(CollectionPhotosService photos) {
        this.photos = photos;
    }

    @PostMapping("/presign")
    public PhotosService.PresignPutResult presign(
            Authentication authentication,
            @PathVariable("collectionId") String collectionId,
            @Valid @RequestBody CollectionPresignPhotoRequest request
    ) {
        return photos.presignPut(
                authentication.getName(), collectionId, request.photoId(), request.contentType()
        );
    }

    @PostMapping("/complete")
    public Photo complete(
            Authentication authentication,
            @PathVariable("collectionId") String collectionId,
            @Valid @RequestBody CollectionCompletePhotoRequest request
    ) {
        Instant createdAt = request.createdAt() == null || request.createdAt().isBlank()
                ? null : Instant.parse(request.createdAt().trim());
        return photos.complete(
                authentication.getName(),
                AuthClaims.requireEmail(authentication),
                AuthClaims.preferredName(authentication),
                collectionId,
                request.photoId(),
                createdAt,
                request.s3KeyOriginal()
        );
    }

    @GetMapping
    public PhotosService.ListPage list(
            Authentication authentication,
            @PathVariable("collectionId") String collectionId,
            @RequestParam(value = "limit", defaultValue = "9") int limit,
            @RequestParam(value = "nextToken", required = false) String nextToken,
            @RequestParam(value = "filter", required = false) String filter,
            @RequestParam(value = "guestIds", required = false) List<String> guestIds
    ) {
        return photos.list(
                authentication.getName(), collectionId, limit, nextToken, filter, guestIds
        );
    }

    @PostMapping("/{photoId}/processing-retry")
    public ResponseEntity<PhotosService.RetryProcessingResult> retry(
            Authentication authentication,
            @PathVariable("collectionId") String collectionId,
            @PathVariable("photoId") String photoId
    ) {
        return ResponseEntity.accepted().body(
                photos.retry(authentication.getName(), collectionId, photoId)
        );
    }

    @PutMapping("/{photoId}/like")
    public CollectionLikeResponse like(
            Authentication authentication,
            @PathVariable("collectionId") String collectionId,
            @PathVariable("photoId") String photoId
    ) {
        return new CollectionLikeResponse(
                photos.like(authentication.getName(), collectionId, photoId)
        );
    }

    @DeleteMapping("/{photoId}/like")
    public CollectionLikeResponse unlike(
            Authentication authentication,
            @PathVariable("collectionId") String collectionId,
            @PathVariable("photoId") String photoId
    ) {
        return new CollectionLikeResponse(
                photos.unlike(authentication.getName(), collectionId, photoId)
        );
    }

    @PostMapping("/{photoId}/social-share")
    public PhotosService.SocialShareLink socialShare(
            Authentication authentication,
            @PathVariable("collectionId") String collectionId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody CollectionSocialShareRequest request
    ) {
        return photos.createSocialShareLink(
                authentication.getName(), collectionId, photoId, request.variant()
        );
    }

    @PostMapping("/share")
    public List<Photo> share(
            Authentication authentication,
            @PathVariable("collectionId") String collectionId,
            @Valid @RequestBody CollectionSharePhotosRequest request
    ) {
        return photos.share(authentication.getName(), collectionId, request.photoIds());
    }

    @PostMapping("/unshare")
    public List<Photo> unshare(
            Authentication authentication,
            @PathVariable("collectionId") String collectionId,
            @Valid @RequestBody CollectionSharePhotosRequest request
    ) {
        return photos.unshare(authentication.getName(), collectionId, request.photoIds());
    }

    @DeleteMapping
    public ResponseEntity<Void> delete(
            Authentication authentication,
            @PathVariable("collectionId") String collectionId,
            @Valid @RequestBody CollectionDeletePhotosRequest request
    ) {
        photos.delete(authentication.getName(), collectionId, request.photoIds());
        return ResponseEntity.noContent().build();
    }
}

record CollectionPresignPhotoRequest(@NotBlank String photoId, String contentType) {}
record CollectionCompletePhotoRequest(
        @NotBlank String photoId,
        @NotBlank String s3KeyOriginal,
        String createdAt
) {}
record CollectionSocialShareRequest(String variant) {}
record CollectionSharePhotosRequest(@NotEmpty List<String> photoIds) {}
record CollectionDeletePhotosRequest(@NotEmpty List<String> photoIds) {}
record CollectionLikeResponse(boolean liked) {}
