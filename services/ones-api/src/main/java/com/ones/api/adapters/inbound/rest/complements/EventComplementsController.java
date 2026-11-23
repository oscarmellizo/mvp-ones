package com.ones.api.adapters.inbound.rest.complements;

import java.util.List;

import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.complements.EventComplementView;
import com.ones.api.application.complements.EventComplementsService;
import com.ones.api.application.events.EventForbiddenException;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.domain.events.Event;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotNull;

@RestController
@RequestMapping("/v1/events/{eventId}/complements")
public class EventComplementsController {

    private final EventComplementsService complementsService;
    private final GetEventUseCase getEventUseCase;

    public EventComplementsController(
            EventComplementsService complementsService,
            GetEventUseCase getEventUseCase
    ) {
        this.complementsService = complementsService;
        this.getEventUseCase = getEventUseCase;
    }

    @GetMapping
    public List<EventComplementView> list(Authentication authentication, @PathVariable String eventId) {
        Event event = requireEventAccess(authentication, eventId);
        return complementsService.list(event.getEventId());
    }

    @PutMapping("/{complementId}")
    public EventComplementView setEnabled(
            Authentication authentication,
            @PathVariable String eventId,
            @PathVariable String complementId,
            @Valid @RequestBody SetComplementRequest request
    ) {
        Event event = requireEventAccess(authentication, eventId);
        if (!event.getOwnerId().equals(authentication.getName())) {
            throw new EventForbiddenException(eventId);
        }
        return complementsService.setEnabled(
                eventId,
                event.getOwnerId(),
                complementId,
                request.enabled());
    }

    private Event requireEventAccess(Authentication authentication, String eventId) {
        String email = null;
        try {
            email = AuthClaims.requireEmail(authentication);
        } catch (RuntimeException ignored) {
            // Owners with legacy tokens can still access their event by user id.
        }
        return getEventUseCase.execute(authentication.getName(), email, eventId);
    }

    public record SetComplementRequest(@NotNull Boolean enabled) {
    }
}
