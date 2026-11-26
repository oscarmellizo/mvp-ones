package com.ones.api.adapters.inbound.rest.internal;

import java.time.Instant;
import java.util.Optional;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.collections.CollectionPhotosService;
import com.ones.api.application.collections.CollectionService;
import com.ones.api.application.photos.PhotosService;
import com.ones.api.domain.photos.Photo;
import com.ones.api.domain.photos.PhotoOwner;

@RestController
@RequestMapping("/internal/collections/{collectionId}/photos")
public class InternalCollectionPhotosController {
    private final PhotosService photosService;
    private final CollectionPhotosService collectionPhotos;
    private final CollectionService collections;

    public InternalCollectionPhotosController(
            PhotosService photosService,
            CollectionPhotosService collectionPhotos,
            CollectionService collections
    ) {
        this.photosService = photosService;
        this.collectionPhotos = collectionPhotos;
        this.collections = collections;
    }

    @PostMapping("/{photoId}/ready")
    public Photo ready(
            @PathVariable("collectionId") String collectionId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody InternalCollectionReadyRequest request
    ) {
        collections.ensureActiveForInternalWork(collectionId);
        return photosService.markReadyInternal(
                ownerPartition(collectionId, photoId), photoId, request.s3KeyOriginal(),
                request.s3KeyMedium(), request.s3KeySmall()
        );
    }

    @PostMapping("/{photoId}/processing")
    public InternalCollectionProcessingClaim processing(
            @PathVariable("collectionId") String collectionId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody InternalCollectionProcessingRequest request
    ) {
        collections.ensureActiveForInternalWork(collectionId);
        var result = photosService.claimProcessingInternal(
                ownerPartition(collectionId, photoId), photoId, request.s3KeyOriginal(), request.manualRetry()
        );
        return new InternalCollectionProcessingClaim(
                result.status().name().toLowerCase(),
                result.photo() == null ? 0 : result.photo().getProcessingAttempts(),
                result.photo() == null ? null : result.photo().getProcessingLeaseUntilEpoch()
        );
    }

    @PostMapping("/{photoId}/processing-retrying")
    public InternalCollectionProcessingState processingRetrying(
            @PathVariable("collectionId") String collectionId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody InternalCollectionRetryRequest request
    ) {
        Optional<Photo> result = photosService.markProcessingRetryingInternal(
                ownerPartition(collectionId, photoId), photoId, request.s3KeyOriginal(),
                request.errorCode(), request.retryAtEpoch() == null
                        ? null : Instant.ofEpochMilli(request.retryAtEpoch())
        );
        return new InternalCollectionProcessingState(
                result.isPresent(), result.map(Photo::getStatus).orElse(null)
        );
    }

    @PostMapping("/{photoId}/processing-failed")
    public InternalCollectionProcessingState processingFailed(
            @PathVariable("collectionId") String collectionId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody InternalCollectionFailedRequest request
    ) {
        Optional<Photo> result = photosService.markProcessingFailedInternal(
                ownerPartition(collectionId, photoId), photoId, request.s3KeyOriginal(), request.errorCode()
        );
        return new InternalCollectionProcessingState(
                result.isPresent(), result.map(Photo::getStatus).orElse(null)
        );
    }

    @PostMapping("/{photoId}/recover")
    public InternalCollectionRecovery recover(
            @PathVariable("collectionId") String collectionId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody InternalCollectionRecoverRequest request
    ) {
        PhotosService.PhotoRecoveryResult result = collectionPhotos.recoverInternal(
                collectionId, photoId, request.s3KeyOriginal(), request.createdAt()
        );
        return new InternalCollectionRecovery(
                result.photo().getPhotoId(), result.photo().getStatus(), result.processingQueued()
        );
    }

    private static String ownerPartition(String collectionId, String photoId) {
        return PhotoOwner.collection(collectionId).storagePartitionId(photoId);
    }
}

record InternalCollectionReadyRequest(
        @NotBlank String s3KeyOriginal,
        @NotBlank String s3KeyMedium,
        @NotBlank String s3KeySmall
) {}
record InternalCollectionProcessingRequest(@NotBlank String s3KeyOriginal, boolean manualRetry) {}
record InternalCollectionRetryRequest(
        @NotBlank String s3KeyOriginal,
        @NotBlank String errorCode,
        Long retryAtEpoch
) {}
record InternalCollectionFailedRequest(@NotBlank String s3KeyOriginal, @NotBlank String errorCode) {}
record InternalCollectionRecoverRequest(@NotBlank String s3KeyOriginal, @NotNull Instant createdAt) {}
record InternalCollectionProcessingClaim(String status, int attempts, Long leaseUntilEpoch) {}
record InternalCollectionProcessingState(boolean updated, String status) {}
record InternalCollectionRecovery(String photoId, String status, boolean processingQueued) {}
