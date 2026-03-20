package com.ones.api.application.events;

import java.time.Clock;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.HashSet;
import java.util.Set;

import com.ones.api.application.events.ports.EventsRepository;
import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;

public class ListEventsUseCase {

    private final EventsRepository repository;
    private final InvitationsRepository invitationsRepository;
    private final Clock clock;

    public ListEventsUseCase(EventsRepository repository, InvitationsRepository invitationsRepository, Clock clock) {
        this.repository = repository;
        this.invitationsRepository = invitationsRepository;
        this.clock = clock;
    }

    public List<Event> execute(String ownerId, String email, int limit) {
        List<Event> owned = repository.listByOwnerId(ownerId, limit);
        Set<String> seen = new HashSet<>(owned.stream().map(Event::getEventId).toList());
        List<Event> combined = new ArrayList<>(owned);

        if (email != null && !email.isBlank()) {
            List<Invitation> accepted = invitationsRepository.listAcceptedByInviteeEmail(email.trim().toLowerCase(), 100);
            List<String> inviteEventIds = accepted.stream()
                    .map(Invitation::getEventId)
                    .filter(id -> id != null && !id.isBlank())
                    .map(String::trim)
                    .filter(id -> !seen.contains(id))
                    .distinct()
                    .toList();

            if (!inviteEventIds.isEmpty()) {
                for (Event e : repository.findByIds(inviteEventIds)) {
                    if (e == null) continue;
                    if (e.getEventId() == null || e.getEventId().isBlank()) continue;
                    if (seen.add(e.getEventId())) {
                        combined.add(e);
                    }
                }
            }
        }

        Collections.sort(combined, (a, b) -> b.getStartAt().compareTo(a.getStartAt()));
        return combined;
    }
}
