package com.ones.api.adapters.inbound.rest.events;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.events.EventCoversService;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.events.EventCoverNotFoundException;
import com.ones.api.domain.events.Event;
import com.ones.api.application.events.EventCoversService.PresignUploadResult;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/v1/events")
public class EventCoversController {

    private final EventCoversService coversService;
    private final GetEventUseCase getEventUseCase;

    public EventCoversController(EventCoversService coversService, GetEventUseCase getEventUseCase) {
        this.coversService = coversService;
        this.getEventUseCase = getEventUseCase;
    }

    @PostMapping("/covers/generate")
    public EventCoversService.GenerateCoverResult generate(
            Authentication authentication,
            @Valid @RequestBody GenerateEventCoverRequest request
    ) {
        String ownerId = authentication.getName();
        return coversService.generatePreview(
                ownerId,
                request.eventName(),
                request.objective(),
                request.location(),
                request.size()
        );
    }

    @PostMapping("/covers/{coverId}/accept")
    public EventCoversService.AcceptCoverResult accept(Authentication authentication, @PathVariable("coverId") String coverId) {
        String ownerId = authentication.getName();
        return coversService.accept(ownerId, coverId);
    }

    @PostMapping("/covers/{coverId}/cancel")
    public ResponseEntity<Void> cancel(Authentication authentication, @PathVariable("coverId") String coverId) {
        String ownerId = authentication.getName();
        coversService.cancel(ownerId, coverId);
        return ResponseEntity.noContent().build();
    }

    @GetMapping("/{id}/cover-url")
    public EventCoversService.PresignedUrlResult coverUrl(
            Authentication authentication,
            @PathVariable("id") String eventId
    ) {
        String requesterUserId = authentication.getName();
        String email;
        try {
            email = AuthClaims.requireEmail(authentication);
        } catch (Exception ignored) {
            email = null;
        }

        // Validate access (owner or accepted guest) and obtain event
        Event event = getEventUseCase.execute(requesterUserId, email, eventId);

        String coverKey = event.getCoverKey();
        if (coverKey == null || coverKey.isBlank()) {
            throw new EventCoverNotFoundException(eventId);
        }
        return coversService.getFinalCoverUrl(coverKey);
    }

    @PostMapping("/{id}/cover/uploads:presign")
    public PresignUploadResult presignCoverUpload(
            Authentication authentication,
            @PathVariable("id") String eventId,
            @Valid @RequestBody PresignEventCoverUploadRequest request
    ) {
        String requesterUserId = authentication.getName();
        String email;
        try {
            email = AuthClaims.requireEmail(authentication);
        } catch (Exception ignored) {
            email = null;
        }
        // Validate access
        getEventUseCase.execute(requesterUserId, email, eventId);
        return coversService.presignUpload(eventId, request.contentType());
    }

    @PutMapping("/{id}/cover")
    public EventCoversService.PresignedUrlResult setCover(
            Authentication authentication,
            @PathVariable("id") String eventId,
            @Valid @RequestBody SetEventCoverRequest request
    ) {
        String requesterUserId = authentication.getName();
        String email;
        try {
            email = AuthClaims.requireEmail(authentication);
        } catch (Exception ignored) {
            email = null;
        }

        Event event = getEventUseCase.execute(requesterUserId, email, eventId);

        String source = request.source() != null ? request.source().trim().toLowerCase() : "";
        String destKey;
        switch (source) {
            case "upload" -> destKey = coversService.setCoverFromUpload(event, request.uploadKey());
            case "photo" -> destKey = coversService.setCoverFromPhoto(event, request.photoId());
            default -> throw new IllegalArgumentException("Unsupported source: " + request.source());
        }
        return coversService.getFinalCoverUrl(destKey);
    }
}
