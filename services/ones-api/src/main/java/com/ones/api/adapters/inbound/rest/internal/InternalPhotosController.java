package com.ones.api.adapters.inbound.rest.internal;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Min;
import jakarta.validation.constraints.NotBlank;

import java.time.Instant;
import java.util.Optional;

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
        return photosService.markReadyInternal(
                eventId,
                photoId,
                request.s3KeyOriginal(),
                request.s3KeyMedium(),
                request.s3KeySmall()
        );
    }

    @PostMapping("/{eventId}/photos/{photoId}/processing")
    public ProcessingClaimResponse processing(
            @PathVariable("eventId") String eventId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody MarkProcessingRequest request
    ) {
        var claim = photosService.claimProcessingInternal(
                eventId,
                photoId,
                request.s3KeyOriginal(),
                request.manualRetry()
        );
        return new ProcessingClaimResponse(
                claim.status().name().toLowerCase(),
                claim.photo() != null ? claim.photo().getProcessingAttempts() : 0,
                claim.photo() != null ? claim.photo().getProcessingLeaseUntilEpoch() : null
        );
    }

    @PostMapping("/{eventId}/photos/{photoId}/processing-retrying")
    public ProcessingStateResponse processingRetrying(
            @PathVariable("eventId") String eventId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody MarkProcessingRetryingRequest request
    ) {
        Optional<Photo> updated = photosService.markProcessingRetryingInternal(
                eventId,
                photoId,
                request.s3KeyOriginal(),
                request.errorCode(),
                request.retryAtEpoch() != null
                        ? Instant.ofEpochMilli(request.retryAtEpoch())
                        : null
        );
        return new ProcessingStateResponse(updated.isPresent(), updated.map(Photo::getStatus).orElse(null));
    }

    @PostMapping("/{eventId}/photos/{photoId}/processing-failed")
    public ProcessingStateResponse processingFailed(
            @PathVariable("eventId") String eventId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody MarkProcessingFailedRequest request
    ) {
        Optional<Photo> updated = photosService.markProcessingFailedInternal(
                eventId,
                photoId,
                request.s3KeyOriginal(),
                request.errorCode()
        );
        return new ProcessingStateResponse(updated.isPresent(), updated.map(Photo::getStatus).orElse(null));
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

record MarkReadyRequest(
        @NotBlank String s3KeyOriginal,
        @NotBlank String s3KeyMedium,
        @NotBlank String s3KeySmall
) {
}

record MarkProcessingRequest(@NotBlank String s3KeyOriginal, boolean manualRetry) {
}

record MarkProcessingRetryingRequest(
        @NotBlank String s3KeyOriginal,
        @NotBlank String errorCode,
        Long retryAtEpoch
) {
}

record MarkProcessingFailedRequest(@NotBlank String s3KeyOriginal, @NotBlank String errorCode) {
}

record ProcessingClaimResponse(String status, int attempts, Long leaseUntilEpoch) {
}

record ProcessingStateResponse(boolean updated, String status) {
}

record PhotoUploadedRequest(
        @NotBlank String uploaderName,
        @Min(1) int photoCount,
        @NotBlank String eventTitle
) {
}
