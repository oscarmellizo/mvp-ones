package com.ones.api.application.events;

import java.time.Clock;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.UUID;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.users.User;

public class InviteEventGuestsUseCase {

    private final EventsRepository eventsRepository;
    private final InvitationsRepository invitationsRepository;
    private final UsersRepository usersRepository;
    private final Clock clock;

    public InviteEventGuestsUseCase(
            EventsRepository eventsRepository,
            InvitationsRepository invitationsRepository,
            UsersRepository usersRepository,
            Clock clock
    ) {
        this.eventsRepository = eventsRepository;
        this.invitationsRepository = invitationsRepository;
        this.usersRepository = usersRepository;
        this.clock = clock;
    }

    public void execute(String ownerId, String eventId, List<String> inviteeEmails) {
        if (ownerId == null || ownerId.isBlank()) {
            throw new IllegalArgumentException("Missing ownerId");
        }
        if (eventId == null || eventId.isBlank()) {
            throw new IllegalArgumentException("Missing eventId");
        }

        Event event = eventsRepository.findById(eventId.trim()).orElseThrow(() -> new EventNotFoundException(eventId));
        if (!ownerId.trim().equals(event.getOwnerId())) {
            throw new EventForbiddenException(eventId);
        }

        if (inviteeEmails == null || inviteeEmails.isEmpty()) {
            return;
        }

        Set<String> normalized = new LinkedHashSet<>();
        for (String raw : inviteeEmails) {
            if (raw == null) continue;
            String email = raw.trim().toLowerCase();
            if (email.isEmpty()) continue;
            normalized.add(email);
        }

        Instant now = Instant.now(clock);
        for (String email : normalized) {
            if (invitationsRepository.findByInviteeEmailAndEventId(email, event.getEventId()).isPresent()) {
                continue;
            }

            ensureStubUser(email, now);

            Invitation inv = new Invitation(
                    event.getEventId(),
                    email,
                    null,
                    event.getOwnerId(),
                    Invitation.Status.invited,
                    now,
                    now,
                    event.getTitle(),
                    event.getLocation(),
                    event.getStartAt(),
                    event.getEndAt()
            );
            invitationsRepository.upsert(inv);
        }
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
                now,
                now
        );
        usersRepository.upsert(stub);
    }
}
