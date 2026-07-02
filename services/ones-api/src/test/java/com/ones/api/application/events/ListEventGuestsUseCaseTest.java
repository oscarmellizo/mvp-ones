package com.ones.api.application.events;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.time.Instant;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import com.ones.api.application.invitations.ports.InvitationsRepository;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.events.Event;
import com.ones.api.domain.invitations.Invitation;
import com.ones.api.domain.users.User;

class ListEventGuestsUseCaseTest {

    @Test
    void execute_returnsOwnerFirstThenInvitees() {
        InMemoryInvitationsRepo invitations = new InMemoryInvitationsRepo();
        InMemoryUsersRepo users = new InMemoryUsersRepo();

        Instant now = Instant.parse("2026-01-01T00:00:00Z");

        Event event = new Event(
                "event-1",
                "owner-1",
                now,
                "title",
                "obj",
                "loc",
                now,
                now.plusSeconds(3600),
                null,
                true,
                true,
                java.util.List.<String>of()
        );

        users.upsert(new User(
                "owner-1",
                "owner@example.com",
                "Owner Name",
                null,
                null,
                null,
                "Owner",
                "google",
                null, // languagePreference
                now,
                now
        ));

        invitations.items.add(new Invitation(
                "event-1",
                "guest@example.com",
                "guest-1",
                "owner-1",
                Invitation.Status.accepted,
                now,
                now,
                "title",
                "loc",
                now,
                now.plusSeconds(3600)
        ));

        users.upsert(new User(
                "guest-1",
                "guest@example.com",
                "Guest Name",
                null,
                null,
                null,
                "Guest",
                "google",
                null, // languagePreference
                now,
                now
        ));

        ListEventGuestsUseCase useCase = new ListEventGuestsUseCase(invitations, users);
        List<ListEventGuestsUseCase.Guest> out = useCase.execute(event, 200);

        assertEquals(2, out.size());
        assertEquals("owner", out.get(0).role());
        assertEquals("owner@example.com", out.get(0).email());
        assertEquals("Owner", out.get(0).displayName());

        assertEquals("guest", out.get(1).role());
        assertEquals("guest@example.com", out.get(1).email());
        assertEquals("Guest", out.get(1).displayName());
        assertEquals("accepted", out.get(1).status());
    }

    private static class InMemoryInvitationsRepo implements InvitationsRepository {
        private final java.util.List<Invitation> items = new java.util.ArrayList<>();

        @Override
        public Optional<Invitation> findByInviteeEmailAndEventId(String inviteeEmail, String eventId) {
            return items.stream().filter(i -> i.getInviteeEmail().equals(inviteeEmail) && i.getEventId().equals(eventId)).findFirst();
        }

        @Override
        public Invitation upsert(Invitation invitation) {
            items.add(invitation);
            return invitation;
        }

        @Override
        public List<Invitation> listByInviteeEmail(String inviteeEmail, int limit) {
            return items.stream().filter(i -> i.getInviteeEmail().equals(inviteeEmail)).limit(limit).toList();
        }

        @Override
        public List<Invitation> listByEventId(String eventId, int limit) {
            return items.stream().filter(i -> i.getEventId().equals(eventId)).limit(limit).toList();
        }

        @Override
        public void deleteAllByEventId(String eventId) {
            items.removeIf(i -> i.getEventId().equals(eventId));
        }

        @Override
        public List<Invitation> listAcceptedByInviteeEmail(String inviteeEmail, int limit) {
            return items.stream()
                    .filter(i -> i.getInviteeEmail().equals(inviteeEmail) && i.getStatus() == Invitation.Status.accepted)
                    .limit(limit)
                    .toList();
        }
    }

    private static class InMemoryUsersRepo implements UsersRepository {
        private final Map<String, User> byId = new HashMap<>();
        private final Map<String, User> byEmail = new HashMap<>();

        @Override
        public Optional<User> findById(String userId) {
            return Optional.ofNullable(byId.get(userId));
        }

        @Override
        public Optional<User> findByEmail(String email) {
            return Optional.ofNullable(byEmail.get(email));
        }

        @Override
        public User upsert(User user) {
            byId.put(user.getUserId(), user);
            if (user.getEmail() != null) {
                byEmail.put(user.getEmail(), user);
            }
            return user;
        }

        @Override
        public void deleteById(String userId) {
            byId.remove(userId);
        }
    }
}
