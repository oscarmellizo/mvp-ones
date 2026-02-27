package com.ones.api.application.events;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.users.User;

public class ListEventGuestsUseCase {

    private final InvitationsRepository invitationsRepository;
    private final UsersRepository usersRepository;

    public ListEventGuestsUseCase(InvitationsRepository invitationsRepository, UsersRepository usersRepository) {
        this.invitationsRepository = invitationsRepository;
        this.usersRepository = usersRepository;
    }

    public List<Guest> execute(Event event, int limit) {
        if (event == null) {
            throw new IllegalArgumentException("Missing event");
        }

        User owner = usersRepository.findById(event.getOwnerId()).orElse(null);
        String ownerEmail = owner != null ? owner.getEmail() : null;
        String ownerName = owner != null && owner.getPreferredName() != null && !owner.getPreferredName().isBlank()
                ? owner.getPreferredName()
                : (owner != null && owner.getName() != null && !owner.getName().isBlank() ? owner.getName() : ownerEmail);

        Guest ownerGuest = new Guest(ownerEmail, ownerName, "owner", "owner");

        List<Invitation> invitations = invitationsRepository.listByEventId(event.getEventId(), limit);

        Map<String, User> usersById = new HashMap<>();
        Map<String, User> usersByEmail = new HashMap<>();

        List<Guest> invitees = new ArrayList<>(invitations.size());
        for (Invitation inv : invitations) {
            User invitee = null;

            String inviteeUserId = inv.getInviteeUserId();
            if (inviteeUserId != null && !inviteeUserId.isBlank()) {
                invitee = usersById.computeIfAbsent(inviteeUserId, id -> usersRepository.findById(id).orElse(null));
            }
            if (invitee == null) {
                String email = inv.getInviteeEmail();
                if (email != null && !email.isBlank()) {
                    String normalized = email.trim().toLowerCase();
                    invitee = usersByEmail.computeIfAbsent(normalized, e -> usersRepository.findByEmail(e).orElse(null));
                }
            }

            String displayName = resolveDisplayName(invitee, inv.getInviteeEmail());
            invitees.add(new Guest(inv.getInviteeEmail(), displayName, "guest", inv.getStatus().name()));
        }

        List<Guest> out = new ArrayList<>(1 + invitees.size());
        out.add(ownerGuest);
        out.addAll(invitees);
        return out;
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

    public record Guest(String email, String displayName, String role, String status) {
    }
}
