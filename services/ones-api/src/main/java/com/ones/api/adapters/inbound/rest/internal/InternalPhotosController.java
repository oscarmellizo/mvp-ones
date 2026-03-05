package com.ones.api.adapters.inbound.rest.internal;

import jakarta.validation.Valid;

import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.photos.PhotosService;
import com.ones.api.domain.photos.Photo;

@RestController
@RequestMapping("/internal/events")
public class InternalPhotosController {

    private final PhotosService photosService;

    public InternalPhotosController(PhotosService photosService) {
        this.photosService = photosService;
    }

    @PostMapping("/{eventId}/photos/{photoId}/ready")
    public Photo ready(
            @PathVariable("eventId") String eventId,
            @PathVariable("photoId") String photoId,
            @Valid @RequestBody MarkReadyRequest request
    ) {
        return photosService.markReadyInternal(eventId, photoId, request.s3KeyMedium(), request.s3KeySmall());
    }
}

record MarkReadyRequest(String s3KeyMedium, String s3KeySmall) {
}
