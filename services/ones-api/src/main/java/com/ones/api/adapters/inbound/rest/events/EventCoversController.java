package com.ones.api.adapters.inbound.rest.events;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.events.EventCoversService;

import jakarta.validation.Valid;

@RestController
@RequestMapping("/v1/events")
public class EventCoversController {

    private final EventCoversService coversService;

    public EventCoversController(EventCoversService coversService) {
        this.coversService = coversService;
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
                request.categoryLabel(),
                request.eventTypeLabel(),
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
        String ownerId = authentication.getName();
        String coverKey = coversService
                .getCoverKeyForEvent(ownerId, eventId);
        return coversService.getFinalCoverUrl(coverKey);
    }
}
