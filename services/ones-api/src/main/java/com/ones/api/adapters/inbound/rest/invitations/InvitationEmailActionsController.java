package com.ones.api.adapters.inbound.rest.invitations;

import java.net.URI;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.ones.api.application.invitations.InvitationsService;
import com.ones.api.application.invitations.email.InvitationActionTokenService;
import com.ones.api.domain.invitations.Invitation;

@RestController
@RequestMapping("/i")
public class InvitationEmailActionsController {

    private static final Logger log = LoggerFactory.getLogger(InvitationEmailActionsController.class);

    private final InvitationActionTokenService tokenService;
    private final InvitationsService invitationsService;
    private final String appBaseUrl;

    private final Counter acceptCounter;
    private final Counter rejectCounter;
    private final Counter invalidCounter;

    public InvitationEmailActionsController(
            InvitationActionTokenService tokenService,
            InvitationsService invitationsService,
            MeterRegistry meterRegistry,
            @Value("${ones.app.base-url:}") String appBaseUrl
    ) {
        this.tokenService = tokenService;
        this.invitationsService = invitationsService;
        this.appBaseUrl = appBaseUrl;

        this.acceptCounter = Counter.builder("ones.invitation.email_action")
                .tag("action", "accept")
                .register(meterRegistry);
        this.rejectCounter = Counter.builder("ones.invitation.email_action")
                .tag("action", "reject")
                .register(meterRegistry);
        this.invalidCounter = Counter.builder("ones.invitation.email_action")
                .tag("action", "invalid")
                .register(meterRegistry);
    }

    @GetMapping("/{token}/accept")
    public ResponseEntity<Void> accept(@PathVariable("token") String token) {
        return handle(token, InvitationActionTokenService.Action.accept);
    }

    @GetMapping("/{token}/reject")
    public ResponseEntity<Void> reject(@PathVariable("token") String token) {
        return handle(token, InvitationActionTokenService.Action.reject);
    }

    private ResponseEntity<Void> handle(String token, InvitationActionTokenService.Action expected) {
        try {
            InvitationActionTokenService.Decoded decoded = tokenService.decodeAndValidate(token);
            if (decoded.action() != expected) {
                invalidCounter.increment();
                return ResponseEntity.badRequest().build();
            }

            Invitation updated;
            if (expected == InvitationActionTokenService.Action.accept) {
                acceptCounter.increment();
                updated = invitationsService.acceptFromEmail(decoded.inviteeEmail(), decoded.eventId());
            } else {
                rejectCounter.increment();
                updated = invitationsService.rejectFromEmail(decoded.inviteeEmail(), decoded.eventId());
            }

            return redirect(updated.getEventId(), updated.getStatus().name());
        } catch (Exception e) {
            invalidCounter.increment();
            log.info("Invalid invitation email action token", e);
            return ResponseEntity.status(HttpStatus.GONE).build();
        }
    }

    private ResponseEntity<Void> redirect(String eventId, String status) {
        if (appBaseUrl == null || appBaseUrl.isBlank()) {
            return ResponseEntity.noContent().build();
        }

        String base = appBaseUrl.trim();
        while (base.endsWith("/")) {
            base = base.substring(0, base.length() - 1);
        }

        String location = base + "/events/detail?eventId=" + eventId + "&invitationStatus=" + status;
        HttpHeaders headers = new HttpHeaders();
        headers.setLocation(URI.create(location));
        return new ResponseEntity<>(headers, HttpStatus.FOUND);
    }
}
