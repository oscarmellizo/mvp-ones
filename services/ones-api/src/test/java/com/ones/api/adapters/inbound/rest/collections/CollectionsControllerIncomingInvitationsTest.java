package com.ones.api.adapters.inbound.rest.collections;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationToken;
import org.springframework.web.bind.annotation.GetMapping;

import com.ones.api.application.collections.CollectionJoinRateLimiter;
import com.ones.api.application.collections.CollectionService;
import com.ones.api.application.collections.ports.CollectionMembersRepository;
import com.ones.api.application.invitations.email.InvitationActionTokenService;
import com.ones.api.domain.collections.CollectionInvitation;

class CollectionsControllerIncomingInvitationsTest {
    @Test
    void exposesAuthenticatedInviteeEmailQueryForBellNotifications() throws Exception {
        CollectionService service = mock(CollectionService.class);
        CollectionsController controller = new CollectionsController(
                service,
                mock(InvitationActionTokenService.class),
                mock(CollectionJoinRateLimiter.class),
                "https://appdev.ones.events"
        );
        var authentication = new JwtAuthenticationToken(Jwt.withTokenValue("token")
                .header("alg", "none")
                .subject("invitee-1")
                .claim("email", " Invitee@Example.com ")
                .build());
        Instant createdAt = Instant.parse("2026-11-28T10:00:00Z");
        when(service.listIncomingInvitations("invitee@example.com", 50, "cursor"))
                .thenReturn(new CollectionMembersRepository.PageResult<>(
                        List.of(new CollectionInvitation(
                                "collection-1", "Familia", "owner-1", createdAt)),
                        "next"));

        var response = controller.incomingInvitations(authentication, 50, "cursor");

        assertEquals("/invitations", CollectionsController.class
                .getMethod("incomingInvitations",
                        org.springframework.security.core.Authentication.class,
                        int.class,
                        String.class)
                .getAnnotation(GetMapping.class).value()[0]);
        assertEquals("collection-1", response.items().get(0).collectionId());
        assertEquals("Familia", response.items().get(0).collectionName());
        assertEquals("next", response.nextToken());
        verify(service).listIncomingInvitations(
                "invitee@example.com", 50, "cursor");
    }
}
