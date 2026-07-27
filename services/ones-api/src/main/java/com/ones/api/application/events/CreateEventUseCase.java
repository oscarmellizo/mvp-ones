package com.ones.api.application.events;

import java.time.Clock;
import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.invitations.email.InvitationEmailService;
import com.ones.api.application.subscriptions.CheckPlanLimitUseCase;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.users.User;

public class CreateEventUseCase {

    private static final Logger log = LoggerFactory.getLogger(CreateEventUseCase.class);

    private final EventsRepository repository;
    private final InvitationsRepository invitationsRepository;
    private final UsersRepository usersRepository;
    private final Clock clock;
    private final EventCoversService coversService;
    private final InvitationEmailService invitationEmailService;
    private final CheckPlanLimitUseCase checkPlanLimitUseCase;
    private final EventQrService eventQrService;

    public CreateEventUseCase(
            EventsRepository repository,
            InvitationsRepository invitationsRepository,
            UsersRepository usersRepository,
            Clock clock,
            EventCoversService coversService,
            InvitationEmailService invitationEmailService,
            CheckPlanLimitUseCase checkPlanLimitUseCase,
            EventQrService eventQrService
    ) {
        this.repository = repository;
        this.invitationsRepository = invitationsRepository;
        this.usersRepository = usersRepository;
        this.clock = clock;
        this.coversService = coversService;
        this.invitationEmailService = invitationEmailService;
        this.checkPlanLimitUseCase = checkPlanLimitUseCase;
        this.eventQrService = eventQrService;
    }

    public Event execute(
            String ownerId,
            String title,
            String objective,
            String location,
            Instant startAt,
            Instant endAt,
            String coverReservationId
            ,
            List<String> inviteeEmails,
            boolean allowGuestInvites,
            List<String> frameIds
    ) {
        long currentEvents = repository.countByOwnerId(ownerId);
        checkPlanLimitUseCase.execute(ownerId, "maxActiveEvents", currentEvents);

        String eventId = UUID.randomUUID().toString();
        Instant createdAt = Instant.now(clock);

        String coverKey = null;
        if (coverReservationId != null && !coverReservationId.isBlank()) {
            if (coversService == null) {
                throw new IllegalStateException("EventCoversService is not configured");
            }
            coverKey = coversService.consumeReservationAndCopyToEvent(ownerId, coverReservationId.trim(), eventId);
        }

        Event event = new Event(eventId, ownerId, createdAt, title, objective, location, startAt, endAt, coverKey, allowGuestInvites, true, frameIds);
        Event saved = repository.save(event);

        if (inviteeEmails != null && !inviteeEmails.isEmpty()) {
            for (String rawEmail : inviteeEmails) {
                if (rawEmail == null) continue;
                String email = rawEmail.trim().toLowerCase();
                if (email.isEmpty()) continue;

                log.info("Creating invitation eventId={}, ownerId={}, inviteeEmail={}", eventId, ownerId, email);

                ensureStubUser(email, createdAt);

                Invitation inv = new Invitation(
                        eventId,
                        email,
                        null,
                        ownerId,
                        Invitation.Status.invited,
                        createdAt,
                        createdAt,
                        title,
                        location,
                        startAt,
                        endAt
                );
                invitationsRepository.upsert(inv);
                if (invitationEmailService != null) {
                    invitationEmailService.sendInvitation(inv);
                }
            }
        }

        try {
            if (saved.isInviteLinkEnabled()) {
                eventQrService.generateAndUpload(eventId);
            }
        } catch (Exception e) {
            log.warn("QR generation failed for eventId={}", eventId, e);
        }

        return saved;
    }

    private void ensureStubUser(String email, Instant now) {
        if (usersRepository == null) return;
        if (usersRepository.findByEmail(email).isPresent()) {
            return;
        }
        String userId = UUID.randomUUID().toString();
        User stub = new User(
                userId,
                email,
                null,
                null,
                null,
                null,
                null,
                "stub",
                null, // languagePreference
                false, // termsAccepted
                now,
                now
        );
        usersRepository.upsert(stub);
    }
}
