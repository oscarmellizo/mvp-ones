package com.ones.api.adapters.inbound.rest.internal;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.photos.PhotosService;
import com.ones.api.application.photos.PhotosWsPublisher;
import com.ones.api.domain.photos.Photo;

@RestController
@RequestMapping("/internal/events")
public class InternalPhotosController {

    private final PhotosService photosService;
    private final PhotosWsPublisher photosWsPublisher;

    public InternalPhotosController(PhotosService photosService, PhotosWsPublisher photosWsPublisher) {
        this.photosService = photosService;
        this.photosWsPublisher = photosWsPublisher;
    }

    @PostMapping("/{eventId}/photos/{photoId}/ready")
    public Photo ready(
            @PathVariable("eventId") String eventId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody MarkReadyRequest request
    ) {
        return photosService.markReadyInternal(eventId, photoId, request.s3KeyMedium(), request.s3KeySmall());
    }

    @PostMapping("/{eventId}/photos/uploaded")
    public ResponseEntity<Void> notifyUploaded(
            @PathVariable("eventId") String eventId,
            @Valid @RequestBody PhotoUploadedRequest request
    ) {
        photosWsPublisher.publishPhotoUploaded(
                eventId,
                request.uploaderName(),
                request.photoCount(),
                request.eventTitle()
        );
        return ResponseEntity.ok().build();
    }
}

record MarkReadyRequest(String s3KeyMedium, String s3KeySmall) {
}

record PhotoUploadedRequest(
        @NotBlank String uploaderName,
        @Min(1) int photoCount,
        @NotBlank String eventTitle
) {
}
