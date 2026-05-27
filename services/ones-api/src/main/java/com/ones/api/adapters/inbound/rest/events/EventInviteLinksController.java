package com.ones.api.adapters.inbound.rest.events;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.adapters.inbound.rest.AuthClaims;
import com.ones.api.application.events.EventForbiddenException;
import com.ones.api.application.events.GetEventUseCase;
import com.ones.api.application.events.invitelink.AcceptEventInviteLinkUseCase;
import com.ones.api.application.events.invitelink.EventInviteLinkTokenService;
import com.ones.api.application.events.invitelink.PreviewEventInviteLinkUseCase;
import com.ones.api.application.events.invitelink.SetEventInviteLinkEnabledUseCase;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.users.User;

@RestController
@RequestMapping("/v1/events")
public class EventInviteLinksController {

    private final GetEventUseCase getEventUseCase;
    private final PreviewEventInviteLinkUseCase previewUseCase;
    private final AcceptEventInviteLinkUseCase acceptUseCase;
    private final SetEventInviteLinkEnabledUseCase setEnabledUseCase;
    private final EventInviteLinkTokenService tokenService;
    private final UsersRepository usersRepository;

    private final String appBaseUrl;

    private final Counter previewOk;
    private final Counter previewInvalid;
    private final Counter acceptOk;
    private final Counter acceptInvalid;

    public EventInviteLinksController(
            GetEventUseCase getEventUseCase,
            PreviewEventInviteLinkUseCase previewUseCase,
            AcceptEventInviteLinkUseCase acceptUseCase,
            SetEventInviteLinkEnabledUseCase setEnabledUseCase,
            EventInviteLinkTokenService tokenService,
            UsersRepository usersRepository,
            MeterRegistry meterRegistry,
            @Value("${ones.app.base-url:}") String appBaseUrl
    ) {
        this.getEventUseCase = getEventUseCase;
        this.previewUseCase = previewUseCase;
        this.acceptUseCase = acceptUseCase;
        this.setEnabledUseCase = setEnabledUseCase;
        this.tokenService = tokenService;
        this.usersRepository = usersRepository;
        this.appBaseUrl = appBaseUrl;

        this.previewOk = Counter.builder("ones.invite_link.preview").tag("result", "ok").register(meterRegistry);
        this.previewInvalid = Counter.builder("ones.invite_link.preview").tag("result", "invalid").register(meterRegistry);
        this.acceptOk = Counter.builder("ones.invite_link.accept").tag("result", "ok").register(meterRegistry);
        this.acceptInvalid = Counter.builder("ones.invite_link.accept").tag("result", "invalid").register(meterRegistry);
    }

    @GetMapping("/{id}/invite-link")
    public InviteLinkResponse getInviteLink(Authentication authentication, @PathVariable("id") String eventId) {
        String requesterUserId = authentication.getName();
        String email = resolveEmail(authentication);

        Event event = getEventUseCase.execute(requesterUserId, email, eventId);

        boolean isOwner = requesterUserId != null && requesterUserId.trim().equals(event.getOwnerId());
        if (!isOwner && !event.isAllowGuestInvites()) {
            throw new EventForbiddenException(eventId);
        }

        String sig = tokenService.signatureForEventId(event.getEventId());
        String url = buildInviteUrl(event.getEventId(), sig);
        return new InviteLinkResponse(url, event.isInviteLinkEnabled());
    }

    @PutMapping("/{id}/invite-link")
    public InviteLinkResponse setInviteLinkEnabled(
            Authentication authentication,
            @PathVariable("id") String eventId,
            @RequestBody InviteLinkEnabledRequest request
    ) {
        if (request == null) {
            throw new IllegalArgumentException("Missing request");
        }
        if (request.enabled() == null) {
            throw new IllegalArgumentException("Missing enabled");
        }

        String requesterUserId = authentication.getName();
        Event updated = setEnabledUseCase.execute(requesterUserId, eventId, request.enabled());

        String sig = tokenService.signatureForEventId(updated.getEventId());
        String url = buildInviteUrl(updated.getEventId(), sig);
        return new InviteLinkResponse(url, updated.isInviteLinkEnabled());
    }

    @GetMapping("/{id}/invite-link/preview")
    public EventInviteLinkPreviewResponse preview(
            Authentication authentication,
            @PathVariable("id") String eventId,
            @RequestParam("sig") String sig
    ) {
        try {
            tokenService.validate(eventId, sig);
            Event event = previewUseCase.execute(eventId);
            previewOk.increment();
            return new EventInviteLinkPreviewResponse(
                    event.getEventId(),
                    event.getTitle(),
                    event.getObjective(),
                    event.getLocation(),
                    event.getStartAt(),
                    event.getEndAt(),
                    event.getCoverKey()
            );
        } catch (RuntimeException e) {
            previewInvalid.increment();
            throw e;
        }
    }

    @PostMapping("/{id}/invite-link/accept")
    public ResponseEntity<InviteLinkAcceptResponse> accept(
            Authentication authentication,
            @PathVariable("id") String eventId,
            @RequestParam("sig") String sig
    ) {
        try {
            tokenService.validate(eventId, sig);
            Event event = previewUseCase.execute(eventId);

            String requesterUserId = authentication.getName();
            String email = resolveEmail(authentication);

            Invitation updated = acceptUseCase.execute(requesterUserId, email, event);
            acceptOk.increment();
            return ResponseEntity.ok(new InviteLinkAcceptResponse(updated.getEventId(), updated.getStatus().name()));
        } catch (RuntimeException e) {
            acceptInvalid.increment();
            throw e;
        }
    }

    private String buildInviteUrl(String eventId, String sig) {
        String base = appBaseUrl != null ? appBaseUrl.trim() : "";
        while (base.endsWith("/")) {
            base = base.substring(0, base.length() - 1);
        }
        if (base.isBlank()) {
            throw new IllegalStateException("Missing config: ones.app.base-url");
        }

        return base
                + "/event-invite?eventId=" + urlEncodeQuery(eventId)
                + "&sig=" + urlEncodeQuery(sig);
    }

    private static String urlEncodeQuery(String s) {
        return URLEncoder.encode(s, StandardCharsets.UTF_8)
                .replace("+", "%20");
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
            User u = usersRepository.findById(userId).orElse(null);
            if (u != null && u.getEmail() != null && !u.getEmail().isBlank() && u.getEmail().contains("@")) {
                return u.getEmail().trim().toLowerCase();
            }
        }

        if (claimEmail != null && !claimEmail.isBlank()) {
            return claimEmail.trim().toLowerCase();
        }

        throw new IllegalStateException("Missing email");
    }

    public record InviteLinkResponse(String url, boolean enabled) {
    }

    public record InviteLinkEnabledRequest(Boolean enabled) {
    }

    public record EventInviteLinkPreviewResponse(
            String id,
            String title,
            String objective,
            String location,
            java.time.Instant startAt,
            java.time.Instant endAt,
            String coverKey
    ) {
    }

    public record InviteLinkAcceptResponse(String eventId, String status) {
    }
}
