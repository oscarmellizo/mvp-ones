package com.ones.api.adapters.inbound.rest.events;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.events.EventQrService;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.adapters.inbound.rest.AuthClaims;

@RestController
@RequestMapping("/v1/events")
public class EventQrController {

    private final GetEventUseCase getEventUseCase;
    private final EventQrService eventQrService;
    private final UsersRepository usersRepository;

    public EventQrController(GetEventUseCase getEventUseCase, EventQrService eventQrService, UsersRepository usersRepository) {
        this.getEventUseCase = getEventUseCase;
        this.eventQrService = eventQrService;
        this.usersRepository = usersRepository;
    }

    @PostMapping("/{id}/qr")
    public ResponseEntity<QrResponse> ensure(Authentication authentication, @PathVariable("id") String eventId) {
        String userId = authentication.getName();
        String email = resolveEmail(authentication);
        Event event = getEventUseCase.execute(userId, email, eventId);
        if (!event.getOwnerId().equals(userId)) {
            throw new com.ones.api.application.events.EventForbiddenException(eventId);
        }
        EventQrService.QrResult r = eventQrService.generateAndUpload(eventId);
        return ResponseEntity.ok(new QrResponse(r.urlLarge(), r.urlSmall(), r.urlLatest(), r.hash()));
    }

    @GetMapping("/{id}/qr")
    public ResponseEntity<QrResponse> latest(Authentication authentication, @PathVariable("id") String eventId) {
        String userId = authentication.getName();
        String email = resolveEmail(authentication);
        Event event = getEventUseCase.execute(userId, email, eventId);
        String url = eventQrService.latestPublicUrl(eventId);
        return ResponseEntity.ok(new QrResponse(url, null, url, null));
    }

    private String resolveEmail(Authentication authentication) {
        String userId = authentication != null ? authentication.getName() : null;

        String claimEmail = null;
        try {
            claimEmail = AuthClaims.requireEmail(authentication);
        } catch (Exception ignored) {
            claimEmail = null;
        }

        if (claimEmail != null && !claimEmail.isBlank() && claimEmail.contains("@")) {
            return claimEmail.trim().toLowerCase();
        }

        if (userId != null && !userId.isBlank() && usersRepository != null) {
            com.ones.api.domain.users.User u = usersRepository.findById(userId).orElse(null);
            if (u != null && u.getEmail() != null && !u.getEmail().isBlank() && u.getEmail().contains("@")) {
                return u.getEmail().trim().toLowerCase();
            }
        }

        if (claimEmail != null && !claimEmail.isBlank()) {
            return claimEmail.trim().toLowerCase();
        }

        throw new IllegalStateException("Missing email");
    }

    public record QrResponse(String urlLarge, String urlSmall, String urlLatest, String hash) {}
}
