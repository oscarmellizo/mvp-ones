package com.ones.api.adapters.inbound.rest.invitations;

import java.util.List;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.invitations.InvitationsService;
import com.ones.api.domain.invitations.Invitation;

@RestController
@RequestMapping("/v1/invitations")
public class InvitationsController {

    private final InvitationsService service;

    public InvitationsController(InvitationsService service) {
        this.service = service;
    }

    @GetMapping
    public List<InvitationResponse> list(Authentication authentication) {
        String email = AuthClaims.requireEmail(authentication);
        List<Invitation> items = service.listByInviteeEmail(email, 100);
        return items
                .stream()
                .map(InvitationsController::toResponse)
                .toList();
    }

    @PostMapping("/{eventId}/accept")
    public ResponseEntity<InvitationResponse> accept(Authentication authentication, @PathVariable("eventId") String eventId) {
        String email = AuthClaims.requireEmail(authentication);
        String userId = authentication.getName();
        Invitation updated = service.accept(email, userId, eventId);
        return ResponseEntity.ok(toResponse(updated));
    }

    @PostMapping("/{eventId}/reject")
    public ResponseEntity<InvitationResponse> reject(Authentication authentication, @PathVariable("eventId") String eventId) {
        String email = AuthClaims.requireEmail(authentication);
        String userId = authentication.getName();
        Invitation updated = service.reject(email, userId, eventId);
        return ResponseEntity.ok(toResponse(updated));
    }

    private static InvitationResponse toResponse(Invitation inv) {
        return new InvitationResponse(
                inv.getEventId(),
                inv.getInviteeEmail(),
                inv.getInviteeUserId(),
                inv.getEventOwnerId(),
                inv.getStatus().name(),
                inv.getCreatedAt(),
                inv.getUpdatedAt(),
                inv.getEventTitle(),
                inv.getEventLocation(),
                inv.getEventStartAt(),
                inv.getEventEndAt()
        );
    }
}
