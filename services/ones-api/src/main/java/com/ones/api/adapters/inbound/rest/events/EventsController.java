package com.ones.api.adapters.inbound.rest.events;

import java.net.URI;
import java.util.List;

import jakarta.validation.Valid;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.events.CreateEventUseCase;
import com.ones.api.application.events.EventsMetadataService;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.ListEventsUseCase;
import com.ones.api.domain.events.Event;

@RestController
@RequestMapping("/v1/events")
public class EventsController {

    private final CreateEventUseCase createEventUseCase;
    private final ListEventsUseCase listEventsUseCase;
    private final GetEventUseCase getEventUseCase;
    private final EventsMetadataService eventsMetadataService;

    public EventsController(
            CreateEventUseCase createEventUseCase,
            ListEventsUseCase listEventsUseCase,
            GetEventUseCase getEventUseCase,
            EventsMetadataService eventsMetadataService
    ) {
        this.createEventUseCase = createEventUseCase;
        this.listEventsUseCase = listEventsUseCase;
        this.getEventUseCase = getEventUseCase;
        this.eventsMetadataService = eventsMetadataService;
    }

    @GetMapping
    public List<EventResponse> list(Authentication authentication) {
        String ownerId = authentication.getName();
        return listEventsUseCase.execute(ownerId, 50).stream().map(EventsController::toResponse).toList();
    }

    @GetMapping("/metadata")
    public EventsMetadataService.EventsMetadataResponse metadata() {
        return eventsMetadataService.getMetadata();
    }

    @PostMapping
    public ResponseEntity<EventResponse> create(Authentication authentication, @Valid @RequestBody CreateEventRequest request) {
        String ownerId = authentication.getName();
        Event created = createEventUseCase.execute(
                ownerId,
                request.title(),
                request.objective(),
                request.location(),
                request.startAt(),
                request.endAt(),
                request.coverReservationId()
        );
        return ResponseEntity.created(URI.create("/v1/events/" + created.getEventId())).body(toResponse(created));
    }

    @GetMapping("/{id}")
    public EventResponse getById(Authentication authentication, @PathVariable("id") String id) {
        String ownerId = authentication.getName();
        Event event = getEventUseCase.execute(ownerId, id);
        return toResponse(event);
    }

    private static EventResponse toResponse(Event e) {
        return new EventResponse(
                e.getEventId(),
                e.getOwnerId(),
                e.getCreatedAt(),
                e.getTitle(),
                e.getObjective(),
                e.getLocation(),
                e.getStartAt(),
                e.getEndAt(),
                e.getCoverKey()
        );
    }
}
