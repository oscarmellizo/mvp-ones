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

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.events.CreateEventUseCase;
import com.ones.api.application.events.EventForbiddenException;
import com.ones.api.application.events.EventsMetadataService;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.InviteEventGuestsUseCase;
import com.ones.api.application.events.ListEventsUseCase;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.users.User;

@RestController
@RequestMapping("/v1/events")
public class EventsController {

    private final CreateEventUseCase createEventUseCase;
    private final ListEventsUseCase listEventsUseCase;
    private final GetEventUseCase getEventUseCase;
    private final EventsMetadataService eventsMetadataService;
    private final InvitationsRepository invitationsRepository;
    private final UsersRepository usersRepository;
    private final InviteEventGuestsUseCase inviteEventGuestsUseCase;

    public EventsController(
            CreateEventUseCase createEventUseCase,
            ListEventsUseCase listEventsUseCase,
            GetEventUseCase getEventUseCase,
            EventsMetadataService eventsMetadataService,
            InvitationsRepository invitationsRepository,
            UsersRepository usersRepository,
            InviteEventGuestsUseCase inviteEventGuestsUseCase
    ) {
        this.createEventUseCase = createEventUseCase;
        this.listEventsUseCase = listEventsUseCase;
        this.getEventUseCase = getEventUseCase;
        this.eventsMetadataService = eventsMetadataService;
        this.invitationsRepository = invitationsRepository;
        this.usersRepository = usersRepository;
        this.inviteEventGuestsUseCase = inviteEventGuestsUseCase;
    }

    @GetMapping
    public List<EventResponse> list(Authentication authentication) {
        String ownerId = authentication.getName();
        String email = AuthClaims.requireEmail(authentication);
        return listEventsUseCase.execute(ownerId, email, 50).stream().map(EventsController::toResponse).toList();
    }

    @GetMapping("/metadata")
    public EventsMetadataService.EventsMetadataResponse metadata() {
        return eventsMetadataService.getMetadata();
    }

    @PostMapping
    public ResponseEntity<EventResponse> create(Authentication authentication, @Valid @RequestBody CreateEventRequest request) {
        String ownerId = authentication.getName();
        boolean allowGuestInvites = request.allowGuestInvites() == null ? true : request.allowGuestInvites();
        Event created = createEventUseCase.execute(
                ownerId,
                request.title(),
                request.objective(),
                request.location(),
                request.startAt(),
                request.endAt(),
                request.coverReservationId(),
                request.inviteeEmails(),
                allowGuestInvites
        );
        return ResponseEntity.created(URI.create("/v1/events/" + created.getEventId())).body(toResponse(created));
    }

    @GetMapping("/{id}")
    public EventResponse getById(Authentication authentication, @PathVariable("id") String id) {
        String ownerId = authentication.getName();
        String email = AuthClaims.requireEmail(authentication);
        Event event = getEventUseCase.execute(ownerId, email, id);
        return toResponse(event);
    }

    @GetMapping("/{id}/guests")
    public List<GuestResponse> guests(Authentication authentication, @PathVariable("id") String id) {
        String ownerId = authentication.getName();
        String email = AuthClaims.requireEmail(authentication);
        Event event = getEventUseCase.execute(ownerId, email, id);

        User owner = usersRepository.findById(event.getOwnerId()).orElse(null);
        String ownerEmail = owner != null ? owner.getEmail() : null;
        String ownerName = owner != null && owner.getPreferredName() != null && !owner.getPreferredName().isBlank()
                ? owner.getPreferredName()
                : (owner != null && owner.getName() != null && !owner.getName().isBlank() ? owner.getName() : ownerEmail);

        List<GuestResponse> invitees = invitationsRepository.listByEventId(id, 200)
                .stream()
                .map(inv -> {
                    User invitee = null;
                    if (inv.getInviteeUserId() != null && !inv.getInviteeUserId().isBlank()) {
                        invitee = usersRepository.findById(inv.getInviteeUserId()).orElse(null);
                    }
                    if (invitee == null) {
                        invitee = usersRepository.findByEmail(inv.getInviteeEmail()).orElse(null);
                    }
                    String displayName = resolveDisplayName(invitee, inv.getInviteeEmail());
                    return new GuestResponse(
                            inv.getInviteeEmail(),
                            displayName,
                            "guest",
                            inv.getStatus().name()
                    );
                })
                .toList();

        GuestResponse ownerResp = new GuestResponse(
                ownerEmail,
                ownerName,
                "owner",
                "owner"
        );

        return java.util.stream.Stream.concat(java.util.stream.Stream.of(ownerResp), invitees.stream()).toList();
    }

    private static String resolveDisplayName(User user, String email) {
        if (user == null) {
            return null;
        }
        if (user.getPreferredName() != null && !user.getPreferredName().isBlank()) {
            return user.getPreferredName();
        }
        if (user.getName() != null && !user.getName().isBlank()) {
            return user.getName();
        }
        if (email != null && !email.isBlank()) {
            return email;
        }
        return null;
    }

    @PostMapping("/{id}/invitees")
    public List<GuestResponse> invitees(
            Authentication authentication,
            @PathVariable("id") String id,
            @Valid @RequestBody InviteEventGuestsRequest request
    ) {
        String ownerId = authentication.getName();
        String email = AuthClaims.requireEmail(authentication);
        Event event = getEventUseCase.execute(ownerId, email, id);

        boolean isOwner = ownerId != null && ownerId.trim().equals(event.getOwnerId());
        if (!isOwner && !event.isAllowGuestInvites()) {
            throw new EventForbiddenException(id);
        }

        inviteEventGuestsUseCase.execute(event.getOwnerId(), id, request.inviteeEmails());
        return guests(authentication, id);
    }

    public record InviteEventGuestsRequest(List<String> inviteeEmails) {
    }

    public record GuestResponse(String email, String displayName, String role, String status) {
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
                e.getCoverKey(),
                e.isAllowGuestInvites()
        );
    }
}
