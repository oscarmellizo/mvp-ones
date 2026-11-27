package com.ones.api.adapters.inbound.rest.collections;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;
import java.util.Set;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;

import com.ones.api.application.collections.CollectionJoinRateLimiter;
import com.ones.api.application.collections.CollectionService;
import com.ones.api.application.collections.ports.CollectionMembersRepository;
import com.ones.api.application.invitations.email.InvitationActionTokenService;
import com.ones.api.application.users.ports.UsersRepository;
import com.ones.api.domain.collections.CollectionMember;
import com.ones.api.domain.users.User;

class CollectionsControllerMemberProfilesTest {
    private static final Instant NOW = Instant.parse("2026-11-28T10:00:00Z");

    @Test
    void membersResponseIncludesOwnerAndAcceptedMemberProfiles() {
        CollectionService service = mock(CollectionService.class);
        UsersRepository users = mock(UsersRepository.class);
        CollectionsController controller = new CollectionsController(
                service,
                users,
                mock(InvitationActionTokenService.class),
                mock(CollectionJoinRateLimiter.class),
                "https://appdev.ones.events"
        );
        var authentication = new JwtAuthenticationToken(Jwt.withTokenValue("token")
                .header("alg", "none")
                .subject("owner-1")
                .claim("email", "owner@example.com")
                .build());
        var member = new CollectionMember(
                "collection-1",
                "USER#member-1",
                "member-1",
                "member@example.com",
                CollectionMember.Status.ACCEPTED,
                "owner-1",
                NOW,
                NOW
        );
        when(service.listMemberDirectoryPage("owner-1", "collection-1", 50, null))
                .thenReturn(new CollectionService.CollectionMembersDirectoryPage(
                        "owner-1",
                        new CollectionMembersRepository.PageResult<>(List.of(member), null)
                ));
        User ownerProfile = user(
                "owner-1", "owner@example.com", "Owner Preferred");
        User memberProfile = user(
                "member-1", "member@example.com", "Member Preferred");
        when(users.findByIds(Set.of("owner-1", "member-1")))
                .thenReturn(List.of(ownerProfile, memberProfile));

        var response = controller.members(authentication, "collection-1", 50, null);

        assertEquals("Owner Preferred", response.owner().preferredName());
        assertEquals("owner@example.com", response.owner().email());
        assertEquals("Member Preferred", response.items().get(0).preferredName());
        assertEquals("member@example.com", response.items().get(0).email());
        verify(users).findByIds(Set.of("owner-1", "member-1"));
    }

    private static User user(String id, String email, String preferredName) {
        return new User(
                id, email, null, null, null, null, preferredName,
                "google", null, true, NOW, NOW
        );
    }
}
